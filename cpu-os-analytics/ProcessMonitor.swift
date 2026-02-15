//
//  Item.swift
//  cpu-os-analytics
//
//  Created by Chris Ho on 1/23/26
//

import Foundation
import Combine

// Updated model to include sampling data
struct ProcessInfo: Identifiable {
  let id = UUID()
  let processID: Int32
  let name: String
  var cpuUsage: Double
  var totalCPUTime: Double
  let threads: Int
  let memory: Double
  var lastSampleTime: Date
  var lastCPUTime: Double

  var cpuTimeString: String {
	let hours = Int(totalCPUTime) / 3600
	let minutes = (Int(totalCPUTime) % 3600) / 60
	let seconds = Int(totalCPUTime) % 60
	return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
  }
}

class ProcessMonitor: ObservableObject {
  @Published var processes: [ProcessInfo] = []
  private var timer: AnyCancellable?
  private var previousData: [Int32: (cpuTime: Double, sampleTime: Double)] = [:]
  private let refreshQueue = DispatchQueue(label: "com.cpuosanalytics.refresh", qos: .userInitiated)

  init() {
	startMonitoring()
  }

  func startMonitoring() {
	// Do an initial refresh to populate previousData, then start timer
	refresh()

	// Refresh every 5 seconds
	timer = Timer.publish(every: 5.0, on: .main, in: .common)
	  .autoconnect()
	  .sink { [weak self] _ in
		self?.refresh()
	  }
  }

  func refresh() {
	// Run heavy work on serial queue to prevent concurrent access to previousData
	refreshQueue.async { [weak self] in
	  guard let self = self else { return }

	  let maxEntries = 2048
	  let entriesPtr = UnsafeMutablePointer<process_entry_t>.allocate(capacity: maxEntries)
	  defer { entriesPtr.deallocate() }
	  var outCount: Int32 = 0
	  var sampleTime: Double = 0

	  let result = process_monitor_snapshot(entriesPtr, Int32(maxEntries), &outCount, &sampleTime)

	  guard result == 0 else { return }

	  let count = Int(outCount)
	  var updatedList: [ProcessInfo] = []

	  for i in 0..<count {
		var entry = entriesPtr[i]
		let name = withUnsafePointer(to: &entry.name) { ptr in
		  String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
		}
		let e = entry

		// CPU % from delta using C-reported sample time (high-resolution, consistent)
		var calculatedCPU = 0.0
		if let previous = self.previousData[e.pid] {
		  let timeDelta = sampleTime - previous.sampleTime
		  if timeDelta >= 0.1 && timeDelta <= 10.0 {
			let cpuDelta = e.cpu_time_sec - previous.cpuTime
			if cpuDelta >= 0 {
			  // 100% = one full core; can exceed 100% for multi-core
			  calculatedCPU = (cpuDelta / timeDelta) * 100.0
			  calculatedCPU = min(calculatedCPU, 10000.0)

			  // #region agent log
			  /* DEBUG: Log delta calc for high-CPU processes (Hypothesis 1,2,3) */
			  if calculatedCPU > 0.5 {
				let logPath = "/Users/chrisho/Desktop/cpu-os-analytics/.cursor/debug.log"
				let logLine = "{\"hypothesisId\":\"H1_H2_H3\",\"location\":\"ProcessMonitor.swift:delta_calc\",\"message\":\"cpu_delta_calc\",\"data\":{\"pid\":\(e.pid),\"name\":\"\(name)\",\"timeDelta\":\(timeDelta),\"cpuDelta\":\(cpuDelta),\"prevCpuTime\":\(previous.cpuTime),\"currCpuTime\":\(e.cpu_time_sec),\"calculatedCPU\":\(calculatedCPU)},\"timestamp\":\(sampleTime*1000.0)}\n"
				if let data = logLine.data(using: .utf8) {
				  if !FileManager.default.fileExists(atPath: logPath) {
					FileManager.default.createFile(atPath: logPath, contents: nil)
				  }
				  let fh = FileHandle(forWritingAtPath: logPath)
				  if let fh = fh {
					fh.seekToEndOfFile()
					fh.write(data)
					fh.closeFile()
				  }
				}
			  }
			  // #endregion
			}
		  }
		}
		self.previousData[e.pid] = (e.cpu_time_sec, sampleTime)

		updatedList.append(ProcessInfo(
		  processID: e.pid,
		  name: name,
		  cpuUsage: calculatedCPU,
		  totalCPUTime: e.cpu_time_sec,
		  threads: Int(e.threads),
		  memory: e.memory_mb,
		  lastSampleTime: Date(timeIntervalSince1970: sampleTime),
		  lastCPUTime: e.cpu_time_sec
		))
	  }

	  // Clean up previousData for processes that no longer exist
	  let currentPids = Set(updatedList.map { $0.processID })
	  self.previousData = self.previousData.filter { currentPids.contains($0.key) }

	  DispatchQueue.main.async {
		self.processes = updatedList.sorted { $0.cpuUsage > $1.cpuUsage }
	  }
	}
  }

  func killProcess(pid: Int32) {
	kill(pid, SIGKILL)
	refresh()
  }
}
