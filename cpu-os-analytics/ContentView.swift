//
//  ContentView.swift
//  cpu-os-analytics
//
//  Created by Chris Ho on 12/25/25.
//
// array of items of type ProcessInfo struct as defined above
import SwiftUI
import Charts

// MARK: - Models
struct ProcessInfo: Identifiable {
  let id = UUID()
  let processID: Int
  let name: String
  let cpu: Double
  let cpuTime: String
  let threads: Int
  let ports: Int
  let energy: String
  let appNap: String
  let memory: Double
}

struct CPUCategory: Identifiable {
  let id = UUID()
  let name: String
  let percentage: Double
  let color: Color
}

// MARK: - Main Content View
struct ContentView: View {
  @State private var processes: [ProcessInfo] = [
	ProcessInfo(processID: 1234, name: "Chrome", cpu: 45.2, cpuTime: "02:15:34", threads: 24, ports: 156, energy: "High", appNap: "No", memory: 2048),
	ProcessInfo(processID: 2156, name: "Safari", cpu: 23.1, cpuTime: "01:45:12", threads: 18, ports: 89, energy: "Medium", appNap: "No", memory: 1024),
	ProcessInfo(processID: 3421, name: "Xcode", cpu: 67.8, cpuTime: "04:32:18", threads: 45, ports: 234, energy: "Very High", appNap: "No", memory: 4096),
	ProcessInfo(processID: 4567, name: "Mail", cpu: 5.3, cpuTime: "00:23:45", threads: 8, ports: 45, energy: "Low", appNap: "Yes", memory: 512),
	ProcessInfo(processID: 5678, name: "Spotify", cpu: 12.4, cpuTime: "01:12:33", threads: 12, ports: 67, energy: "Medium", appNap: "No", memory: 768),
	ProcessInfo(processID: 6789, name: "Terminal", cpu: 8.9, cpuTime: "00:45:21", threads: 6, ports: 34, energy: "Low", appNap: "No", memory: 256),
	ProcessInfo(processID: 7890, name: "Slack", cpu: 15.6, cpuTime: "01:34:56", threads: 16, ports: 78, energy: "Medium", appNap: "No", memory: 896),
  ]
  
  @State private var totalCPUUsage: Double = 73.5
  
  @State private var categories: [CPUCategory] = [
	CPUCategory(name: "System", percentage: 35, color: .blue),
	CPUCategory(name: "Applications", percentage: 45, color: .green),
	CPUCategory(name: "Background", percentage: 15, color: .orange),
	CPUCategory(name: "Idle", percentage: 5, color: .gray)
  ]
  
  @State private var searchText = ""
  @State private var sortOrder: SortOrder = .cpuDescending
  @State private var aiPrompt = ""
  @State private var aiResponses: [AIMessage] = []
  
  enum SortOrder {
	case nameAscending, nameDescending
	case cpuAscending, cpuDescending
	case memoryAscending, memoryDescending
  }
  
  var body: some View {
	GeometryReader { geometry in
	  HStack(spacing: 16) {
		// Left Column
		VStack(spacing: 16) {
		  // Ring Graph (30%)
		  RingGraphView(categories: categories)
			.frame(height: geometry.size.height * 0.3 - 32)
		  
		  // Biggest Category Stats (35%)
		  BiggestCategoryView(categories: categories)
			.frame(height: geometry.size.height * 0.35 - 24)
		  
		  // Tip Box (35%)
		  TipView()
			.frame(height: geometry.size.height * 0.35 - 24)
		}
		.frame(width: geometry.size.width * 0.25)
		
		// Middle Column - Process List
		ProcessListView(
		  processes: processes,
		  searchText: $searchText,
		  sortOrder: $sortOrder
		)
		.frame(width: geometry.size.width * 0.45)
		
		// Right Column - AI Assistant
		AIAssistantView(
		  prompt: $aiPrompt,
		  responses: $aiResponses
		)
		.frame(width: geometry.size.width * 0.25)
	  }
	  .padding()
	}
  }
}

// MARK: - Ring Graph View
struct RingGraphView: View {
  let categories: [CPUCategory]
  @State private var hoveredCategory: CPUCategory?
  
  var body: some View {
	VStack(spacing: 12) {
	  Text("CPU Usage Distribution")
		.font(.headline)
		.frame(maxWidth: .infinity, alignment: .leading)
	  
	  ZStack {
		Chart(categories) { category in
		  SectorMark(
			angle: .value("Percentage", category.percentage),
			innerRadius: .ratio(0.6),
			angularInset: 2
		  )
		  .foregroundStyle(category.color)
		  .opacity(hoveredCategory?.id == category.id ? 1.0 : 0.7)
		}
		.chartLegend(position: .bottom, spacing: 8)
		
		VStack {
		  if let hovered = hoveredCategory {
			Text("\(hovered.percentage, specifier: "%.0f")%")
			  .font(.title.bold())
			Text(hovered.name)
			  .font(.caption)
			  .foregroundColor(.secondary)
		  } else {
			Text("100%")
			  .font(.title.bold())
			Text("Total")
			  .font(.caption)
			  .foregroundColor(.secondary)
		  }
		}
	  }
	  .onContinuousHover { phase in
		switch phase {
		  case .active(_):
			// Chart hover detection is simplified here
			break
		  case .ended:
			hoveredCategory = nil
		}
	  }
	}
	.padding()
	.background(Color(.windowBackgroundColor))
	.cornerRadius(12)
  }
}

// MARK: - Biggest Category View
struct BiggestCategoryView: View {
  let categories: [CPUCategory]
  
  var biggestCategory: CPUCategory {
	categories.max(by: { $0.percentage < $1.percentage }) ?? categories[0]
  }
  
  var body: some View {
	VStack(alignment: .leading, spacing: 8) {
	  Text("Highest Usage")
		.font(.headline)
	  
	  HStack {
		Circle()
		  .fill(biggestCategory.color)
		  .frame(width: 40, height: 40)
		
		VStack(alignment: .leading, spacing: 4) {
		  Text(biggestCategory.name)
			.font(.title2.bold())
		  Text("\(biggestCategory.percentage, specifier: "%.0f")% of total CPU")
			.font(.caption)
			.foregroundColor(.secondary)
		}
	  }
	  
	  Divider()
	  
	  HStack {
		VStack(alignment: .leading) {
		  Text("Processes")
			.font(.caption)
			.foregroundColor(.secondary)
		  Text("24")
			.font(.title3.bold())
		}
		Spacer()
		VStack(alignment: .leading) {
		  Text("Threads")
			.font(.caption)
			.foregroundColor(.secondary)
		  Text("156")
			.font(.title3.bold())
		}
	  }
	}
	.padding()
	.background(Color(.windowBackgroundColor))
	.cornerRadius(12)
  }
}

// MARK: - Tip View
struct TipView: View {
  var body: some View {
	VStack(alignment: .leading, spacing: 8) {
	  HStack {
		Image(systemName: "lightbulb.fill")
		  .foregroundColor(.yellow)
		Text("Tip")
		  .font(.headline)
	  }
	  
	  Text("High CPU usage from Applications? Try closing unused browser tabs or background apps to improve performance.")
		.font(.subheadline)
		.foregroundColor(.secondary)
		.fixedSize(horizontal: false, vertical: true)
	}
	.padding()
	.background(Color(.windowBackgroundColor))
	.cornerRadius(12)
  }
}

// MARK: - Process List View
struct ProcessListView: View {
  let processes: [ProcessInfo]
  @Binding var searchText: String
  @Binding var sortOrder: ContentView.SortOrder
  
  var filteredAndSortedProcesses: [ProcessInfo] {
	let filtered = searchText.isEmpty ? processes : processes.filter {
	  $0.name.localizedCaseInsensitiveContains(searchText)
	}
	
	switch sortOrder {
	  case .nameAscending:
		return filtered.sorted { $0.name < $1.name }
	  case .nameDescending:
		return filtered.sorted { $0.name > $1.name }
	  case .cpuAscending:
		return filtered.sorted { $0.cpu < $1.cpu }
	  case .cpuDescending:
		return filtered.sorted { $0.cpu > $1.cpu }
	  case .memoryAscending:
		return filtered.sorted { $0.memory < $1.memory }
	  case .memoryDescending:
		return filtered.sorted { $0.memory > $1.memory }
	}
  }
  
  var body: some View {
	VStack(spacing: 12) {
	  Text("Active Processes")
		.font(.headline)
		.frame(maxWidth: .infinity, alignment: .leading)
	  
	  // Search and Filter
	  HStack {
		Image(systemName: "magnifyingglass")
		  .foregroundColor(.secondary)
		TextField("Search processes...", text: $searchText)
		  .textFieldStyle(.plain)
	  }
	  .padding(8)
	  .background(Color(.controlBackgroundColor))
	  .cornerRadius(8)
	  
	  // Sort Options
	  HStack(spacing: 8) {
		Menu {
		  Button("Name ↑") { sortOrder = .nameAscending }
		  Button("Name ↓") { sortOrder = .nameDescending }
		  Button("CPU ↑") { sortOrder = .cpuAscending }
		  Button("CPU ↓") { sortOrder = .cpuDescending }
		  Button("Memory ↑") { sortOrder = .memoryAscending }
		  Button("Memory ↓") { sortOrder = .memoryDescending }
		} label: {
		  Label("Sort", systemImage: "arrow.up.arrow.down")
			.font(.caption)
		}
		.menuStyle(.borderlessButton)
		.fixedSize()
		
		Spacer()
	  }
	  
	  // Process List
	  ScrollView {
		VStack(spacing: 4) {
		  // Header Row
		  HStack(spacing: 12) {
			Text("PID")
			  .font(.caption2.bold())
			  .frame(width: 50, alignment: .leading)
			  .foregroundColor(.secondary)
			
			Text("Process")
			  .font(.caption2.bold())
			  .frame(width: 100, alignment: .leading)
			  .foregroundColor(.secondary)
			
			Text("CPU%")
			  .font(.caption2.bold())
			  .frame(width: 50, alignment: .trailing)
			  .foregroundColor(.secondary)
			
			Text("CPU Time")
			  .font(.caption2.bold())
			  .frame(width: 70, alignment: .trailing)
			  .foregroundColor(.secondary)
			
			Text("Threads")
			  .font(.caption2.bold())
			  .frame(width: 40, alignment: .trailing)
			  .foregroundColor(.secondary)
			
			Text("Ports")
			  .font(.caption2.bold())
			  .frame(width: 40, alignment: .trailing)
			  .foregroundColor(.secondary)
			
			Text("Energy")
			  .font(.caption2.bold())
			  .frame(width: 60, alignment: .trailing)
			  .foregroundColor(.secondary)
			
			Text("Nap")
			  .font(.caption2.bold())
			  .frame(width: 40, alignment: .trailing)
			  .foregroundColor(.secondary)
			
			Text("Memory")
			  .font(.caption2.bold())
			  .frame(width: 70, alignment: .trailing)
			  .foregroundColor(.secondary)
		  }
		  .padding(.horizontal, 12)
		  .padding(.vertical, 8)
		  .background(Color(.controlBackgroundColor).opacity(0.5))
		  .cornerRadius(6)
		  
		  ForEach(filteredAndSortedProcesses) { process in
			ProcessRow(process: process)
		  }
		}
	  }
	}
	.padding()
	.background(Color(.windowBackgroundColor))
	.cornerRadius(12)
  }
}

// MARK: - Process Row
struct ProcessRow: View {
  let process: ProcessInfo
  
  var body: some View {
	HStack(spacing: 12) {
	  Text("\(process.processID)")
		.font(.caption)
		.frame(width: 50, alignment: .leading)
		.foregroundColor(.secondary)
	  
	  Text(process.name)
		.font(.subheadline)
		.frame(width: 100, alignment: .leading)
	  
	  Text("\(process.cpu, specifier: "%.1f")%")
		.font(.caption)
		.frame(width: 50, alignment: .trailing)
	  
	  Text(process.cpuTime)
		.font(.caption)
		.frame(width: 70, alignment: .trailing)
	  
	  Text("\(process.threads)")
		.font(.caption)
		.frame(width: 40, alignment: .trailing)
	  
	  Text("\(process.ports)")
		.font(.caption)
		.frame(width: 40, alignment: .trailing)
	  
	  Text(process.energy)
		.font(.caption)
		.frame(width: 60, alignment: .trailing)
	  
	  Text(process.appNap)
		.font(.caption)
		.frame(width: 40, alignment: .trailing)
	  
	  Text("\(process.memory, specifier: "%.0f") MB")
		.font(.caption)
		.frame(width: 70, alignment: .trailing)
	}
	.padding(.vertical, 6)
	.padding(.horizontal, 12)
	.background(Color(.controlBackgroundColor))
	.cornerRadius(6)
  }
}

// MARK: - AI Assistant View
struct AIMessage: Identifiable {
  let id = UUID()
  let text: String
  let isUser: Bool
}

struct AIAssistantView: View {
  @Binding var prompt: String
  @Binding var responses: [AIMessage]
  
  var body: some View {
	VStack(spacing: 12) {
	  Text("AI Assistant")
		.font(.headline)
		.frame(maxWidth: .infinity, alignment: .leading)
	  
	  // Prompt Input
	  VStack(spacing: 8) {
		HStack(alignment: .top, spacing: 8) {
		  Image(systemName: "sparkles")
			.foregroundColor(.purple)
			.padding(.top, 8)
		  
		  TextField("Ask about CPU usage...", text: $prompt, axis: .vertical)
			.textFieldStyle(.plain)
			.lineLimit(3...6)
		  
		  Button(action: sendPrompt) {
			Image(systemName: "arrow.up.circle.fill")
			  .font(.title2)
			  .foregroundColor(prompt.isEmpty ? .gray : .purple)
		  }
		  .buttonStyle(.plain)
		  .disabled(prompt.isEmpty)
		}
		.padding(12)
		.background(Color(.controlBackgroundColor))
		.cornerRadius(10)
	  }
	  
	  // Responses
	  ScrollView {
		VStack(spacing: 12) {
		  if responses.isEmpty {
			VStack(spacing: 8) {
			  Image(systemName: "brain.head.profile")
				.font(.largeTitle)
				.foregroundColor(.secondary)
			  Text("Ask me anything about your CPU usage")
				.font(.caption)
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
			}
			.frame(maxWidth: .infinity)
			.padding(.top, 40)
		  } else {
			ForEach(responses) { message in
			  AIMessageBubble(message: message)
			}
		  }
		}
	  }
	}
	.padding()
	.background(Color(.windowBackgroundColor))
	.cornerRadius(12)
  }
  
  private func sendPrompt() {
	guard !prompt.isEmpty else { return }
	
	let userMessage = AIMessage(text: prompt, isUser: true)
	responses.append(userMessage)
	
	let tempPrompt = prompt
	prompt = ""
	
	// Simulate AI response
	DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
	  let aiResponse = AIMessage(
		text: "Based on your CPU usage, \(tempPrompt.lowercased()) shows that Applications are consuming the most resources at 45%. Consider closing unused applications to improve performance.",
		isUser: false
	  )
	  responses.append(aiResponse)
	}
  }
}

// MARK: - AI Message Bubble
struct AIMessageBubble: View {
  let message: AIMessage
  
  var body: some View {
	HStack(alignment: .top, spacing: 8) {
	  if message.isUser { Spacer(minLength: 20) }
	  
	  Text(message.text)
		.font(.subheadline)
		.padding(8)
		.background(message.isUser ? Color.purple.opacity(0.2) : Color(.controlBackgroundColor))
		.cornerRadius(10)
		.fixedSize(horizontal: false, vertical: true)
	  
	  if !message.isUser { Spacer(minLength: 20) }
	}
  }
}

// MARK: - Preview
#Preview {
  ContentView()
	.frame(width: 1200, height: 800)
}
