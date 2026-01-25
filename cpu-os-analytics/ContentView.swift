import SwiftUI

struct ContentView: View {
  @StateObject private var monitor = ProcessMonitor()
  @State private var searchText = ""
  
  var filteredProcesses: [ProcessInfo] {
	if searchText.isEmpty { return monitor.processes }
	return monitor.processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
  }
  
  var body: some View {
	NavigationSplitView {
	  // Sidebar for Stats
	  VStack(alignment: .leading, spacing: 20) {
		Text("System Health").font(.headline)
		
		GroupBox("Total Processes") {
		  Text("\(monitor.processes.count)").font(.title)
		}
		
		Text("Tips").font(.headline)
		Text("If a process shows >100% CPU, it's using multiple cores.").font(.caption).foregroundColor(.secondary)
		
		Spacer()
	  }
	  .padding()
	  .frame(minWidth: 200)
	} detail: {
	  VStack(spacing: 0) {
		// Search Bar
		HStack {
		  Image(systemName: "magnifyingglass").foregroundColor(.secondary)
		  TextField("Search by name...", text: $searchText)
			.textFieldStyle(.roundedBorder)
		}
		.padding()
		
		// Process Table
		if filteredProcesses.isEmpty {
		  VStack {
			Spacer()
			Text("No processes found")
			  .foregroundColor(.secondary)
			Spacer()
		  }
		} else {
		  Table(filteredProcesses) {
			TableColumn("PID") { Text("\($0.processID)").foregroundColor(.secondary) }
			TableColumn("Name") { Text($0.name).bold() }
			TableColumn("CPU %") { process in
			  Text(String(format: "%.1f%%", process.cpuUsage))
				.foregroundColor(process.cpuUsage > 50 ? .red : .orange)
			}
			TableColumn("Memory") { Text(String(format: "%.0f MB", $0.memory)) }
			TableColumn("Threads") { Text("\($0.threads)") }
			TableColumn("Action") { process in
			  Button("End") {
				monitor.killProcess(pid: process.processID)
			  }
			  .buttonStyle(.bordered)
			  .tint(.red)
			}
		  }
		}
	  }
	}
	.frame(minWidth: 900, minHeight: 600)
  }
}
