//
//  CPURingChart.swift
//  cpu-os-analytics
//
//  Ring (donut) chart showing CPU % by process.
//

import SwiftUI

private let maxSegments = 10
private let segmentColors: [Color] = [
  .blue, .orange, .green, .purple, .pink,
  .cyan, .mint, .indigo, .yellow, .red
]

struct CPURingChart: View {
  let processes: [ProcessInfo]
  var size: CGFloat = 140
  var lineWidth: CGFloat = 24

  private struct Segment: Identifiable {
    let id = UUID()
    let name: String
    let cpuUsage: Double
    let startAngle: Double
    let endAngle: Double
    let color: Color
  }

  private var segments: [Segment] {
    let total = processes.reduce(0) { $0 + $1.cpuUsage }
    guard total > 0 else { return [] }

    let top = Array(processes.prefix(maxSegments))
    let otherSum = processes.dropFirst(maxSegments).reduce(0) { $0 + $1.cpuUsage }
    var items: [(name: String, cpu: Double)] = top.map { ($0.name, $0.cpuUsage) }
    if otherSum > 0 {
      items.append(("Other", otherSum))
    }

    var angle: Double = -90 // start at top (12 o'clock), in degrees
    let totalForAngles = items.reduce(0) { $0 + $1.cpu }
    guard totalForAngles > 0 else { return [] }

    return items.enumerated().map { index, item in
      let sweep = (item.cpu / totalForAngles) * 360
      let start = angle
      angle += sweep
      return Segment(
        name: item.name,
        cpuUsage: item.cpu,
        startAngle: start,
        endAngle: start + sweep,
        color: segmentColors[index % segmentColors.count]
      )
    }
  }

  var body: some View {
    let segs = segments
    Group {
      if segs.isEmpty {
        ZStack {
          Circle()
            .strokeBorder(Color.gray.opacity(0.3), lineWidth: lineWidth)
          Text("No data")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      } else {
        ZStack {
          ForEach(segs) { seg in
            RingSegment(
              startAngle: .degrees(seg.startAngle),
              endAngle: .degrees(seg.endAngle),
              lineWidth: lineWidth,
              color: seg.color
            )
          }
        }
      }
    }
    .frame(width: size, height: size)
  }
}

private struct RingSegment: View {
  let startAngle: Angle
  let endAngle: Angle
  let lineWidth: CGFloat
  let color: Color

  var body: some View {
    GeometryReader { geo in
      let r = min(geo.size.width, geo.size.height) / 2
      let inner = r - lineWidth / 2
      let outer = r + lineWidth / 2
      let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

      Path { path in
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
      }
      .fill(color)
    }
  }
}

struct CPURingChartWithLegend: View {
  let processes: [ProcessInfo]

  private var segments: [(name: String, cpu: Double, color: Color)] {
    let total = processes.reduce(0) { $0 + $1.cpuUsage }
    guard total > 0 else { return [] }

    let top = Array(processes.prefix(maxSegments))
    let otherSum = processes.dropFirst(maxSegments).reduce(0) { $0 + $1.cpuUsage }
    var items: [(name: String, cpu: Double)] = top.map { ($0.name, $0.cpuUsage) }
    if otherSum > 0 {
      items.append(("Other", otherSum))
    }

    return items.enumerated().map { index, item in
      (item.name, item.cpu, segmentColors[index % segmentColors.count])
    }
  }

  var body: some View {
    GroupBox("CPU by Process") {
      HStack(alignment: .center, spacing: 12) {
        CPURingChart(processes: processes, size: 120, lineWidth: 20)

        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(segments.enumerated()), id: \.offset) { _, item in
            HStack(spacing: 6) {
              RoundedRectangle(cornerRadius: 2)
                .fill(item.color)
                .frame(width: 8, height: 8)
              Text(truncateName(item.name))
                .lineLimit(1)
                .font(.caption)
              Spacer(minLength: 4)
              Text(String(format: "%.1f%%", item.cpu))
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .padding(4)
    }
  }

  private func truncateName(_ name: String) -> String {
    let maxLen = 14
    if name.count <= maxLen { return name }
    return String(name.prefix(maxLen - 2)) + "…"
  }
}

#Preview("CPURingChart") {
  CPURingChartWithLegend(processes: [
    ProcessInfo(processID: 1, name: "WindowServer", cpuUsage: 45, totalCPUTime: 100, threads: 8, memory: 200, lastSampleTime: Date(), lastCPUTime: 100),
    ProcessInfo(processID: 2, name: "kernel_task", cpuUsage: 22, totalCPUTime: 50, threads: 100, memory: 500, lastSampleTime: Date(), lastCPUTime: 50),
    ProcessInfo(processID: 3, name: "mds_stores", cpuUsage: 12, totalCPUTime: 30, threads: 4, memory: 80, lastSampleTime: Date(), lastCPUTime: 30),
    ProcessInfo(processID: 4, name: "Other processes", cpuUsage: 21, totalCPUTime: 40, threads: 1, memory: 10, lastSampleTime: Date(), lastCPUTime: 40),
  ])
  .frame(width: 280)
}
