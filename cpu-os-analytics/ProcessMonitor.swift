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

  init() {
	startMonitoring()
  }

  func startMonitoring() {
	// Do an initial refresh to populate previousData, then start timer
	refresh()

	// Refresh every 0.5 seconds for more accurate CPU readings (Activity Monitor samples frequently)
	timer = Timer.publish(every: 0.5, on: .main, in: .common)
	  .autoconnect()
	  .sink { [weak self] _ in
		self?.refresh()
	  }
  }

  func refresh() {
	// Run heavy work on background queue
	DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
