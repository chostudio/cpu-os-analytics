import SwiftUI

struct ContentView: View {
  @StateObject private var monitor = ProcessMonitor()
  @StateObject private var advisor = AIAdvisor()
  @State private var searchText = ""
  @State private var sortOrder: [KeyPathComparator<ProcessInfo>] = []

  var filteredProcesses: [ProcessInfo] {
    let base: [ProcessInfo]
    if searchText.isEmpty {
      base = monitor.processes
    } else {
      base = monitor.processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    // Apply current sort order from table headers
    return sortOrder.isEmpty ? base : base.sorted(using: sortOrder)
  }

  var body: some View {
	TabView {
	  NavigationSplitView {
	  // Sidebar for Stats
	  VStack(alignment: .leading, spacing: 16) {
		Text("System Health").font(.headline)
		
		CPURingChartWithLegend(processes: monitor.processes)

		GroupBox("Total Processes") {
		  Text("\(monitor.processes.count)").font(.title)
		}
		
		Text("Tips").font(.headline)
		Text("CPU % shows usage per core (100% = one full core). Values can exceed 100% for multi-core usage.").font(.caption).foregroundColor(.secondary)
		
		// AI Advice Section
		if advisor.isGenerating || !advisor.adviceText.isEmpty {
		  Divider()
		  
		  HStack {
			Image(sysutemName: "sparkles")
			  .foregroundStyle(.purple)
			Text("AI Advice").font(.headline)
		  }
		  
		  if advisor.isGenerating && advisor.adviceText.isEmpty {
			HStack(spacing: 8) {
			  ProgressView()
				.controlSize(.small)
			  Text("Analyzing processes...")
				.font(.caption)
				.foregroundColor(.secondary)
			}
			.padding(.vertical, 4)
		  }
		  
		  if !advisor.adviceText.isEmpty {
			ScrollView {
			  Text(advisor.adviceText)
				.font(.callout)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		  }
		}
		
		Spacer()
		
		// AI Advice Button
		Button {
		  advisor.generateAdvice(processes: monitor.processes)
		} label: {
		  HStack(spacing: 6) {
			Image(systemName: "sparkles")
			Text(advisor.adviceText.isEmpty ? "Get AI Advice" : "Refresh Advice")
		  }
		  .frame(maxWidth: .infinity)
		}
		.buttonStyle(.borderedProminent)
		.tint(.purple)
		.disabled(advisor.isGenerating)
	  }
	  .padding()
	  .frame(minWidth: 280)
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
		  Table(filteredProcesses, sortOrder: $sortOrder) {
			TableColumn("PID", value: \.processID) { process in
			  Text("\(process.processID)")
				.foregroundColor(.secondary)
			}
			TableColumn("Name", value: \.name) { process in
			  Text(process.name)
				.bold()
			}
			TableColumn("CPU %", value: \.cpuUsage) { process in
			  Text(String(format: "%.1f%%", process.cpuUsage))
				.foregroundColor(process.cpuUsage > 50 ? .red : .orange)
			}
			TableColumn("Memory", value: \.memory) { process in
			  Text(String(format: "%.0f MB", process.memory))
			}
			TableColumn("Threads", value: \.threads) { process in
			  Text("\(process.threads)")
			}
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
	.tabItem {
	  Label("Processes", systemImage: "list.bullet.rectangle")
	}

	  PowerThermalView()
		.tabItem {
		  Label("Power & Thermal", systemImage: "thermometer.medium")
		}
	}
	.frame(minWidth: 900, minHeight: 600)
  }
}
