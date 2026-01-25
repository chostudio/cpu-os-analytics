//
//  Item.swift
//  cpu-os-analytics
//
//  Created by Chris Ho on 1/23/26
//

import Foundation
//import libproc // handled by the C bridging header. what is that
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
  private var previousData: [Int32: (cpuTime: Double, time: Date)] = [:]
  
  init() {
	startMonitoring()
  }
  
  func startMonitoring() {
	// Refresh every 2 seconds to calculate the Delta
	timer = Timer.publish(every: 2.0, on: .main, in: .common)
	  .autoconnect()
	  .sink { [weak self] _ in
		self?.refresh()
	  }
  }
  
  func refresh() {
	// Run heavy work on background queue
	DispatchQueue.global(qos: .userInitiated).async { [weak self] in
	  guard let self = self else { return }
	  
	  let count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
	  var pids = [pid_t](repeating: 0, count: Int(count))
	  proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(MemoryLayout<pid_t>.size * pids.count))
	  
	  var updatedList: [ProcessInfo] = []
	  let currentTime = Date()
	  
	  for pid in pids where pid > 0 {
		var taskInfo = proc_taskinfo()
		let size = MemoryLayout<proc_taskinfo>.size
		let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
		
		if result == size {
		  // Get Process Name
		  let bufferSize = Int(MAXPATHLEN)
		  let nameBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
		  defer { nameBuffer.deallocate() }
		  let nameResult = proc_name(pid, nameBuffer, UInt32(bufferSize))
		  let name = nameResult > 0 ? String(cString: nameBuffer) : "Unknown"
		  
		  // CPU and Memory stats
		  let currentCPUTime = Double(taskInfo.pti_total_user + taskInfo.pti_total_system) / 1_000_000_000.0
		  let memMB = Double(taskInfo.pti_resident_size) / 1_024 / 1_024
		  
		  // Calculate CPU % based on Delta
		  var calculatedCPU = 0.0
		  if let previous = self.previousData[pid] {
			let timeDelta = currentTime.timeIntervalSince(previous.time)
			let cpuDelta = currentCPUTime - previous.cpuTime
			calculatedCPU = (cpuDelta / timeDelta) * 100.0
		  }
		  
		  // Update history for next tick
		  self.previousData[pid] = (currentCPUTime, currentTime)
		
		  updatedList.append(ProcessInfo(
			processID: pid,
			name: name,
			cpuUsage: calculatedCPU,
			totalCPUTime: currentCPUTime,
			threads: Int(taskInfo.pti_threadnum),
			memory: memMB,
			lastSampleTime: currentTime,
			lastCPUTime: currentCPUTime
		  ))
		}
	  }
	  
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
