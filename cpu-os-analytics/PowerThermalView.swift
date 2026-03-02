//
//  PowerThermalView.swift
//  cpu-os-analytics
//
//  Power consumption & thermal pressure levels tab.
//

import SwiftUI
import Combine

// MARK: - Thermal state display
extension Foundation.ProcessInfo.ThermalState {
  var displayName: String {
    switch self {
    case .nominal: return "Nominal"
    case .fair: return "Fair"
    case .serious: return "Serious"
    case .critical: return "Critical"
    @unknown default: return "Unknown"
    }
  }

  var description: String {
    switch self {
    case .nominal: return "System is cool; no thermal throttling."
    case .fair: return "Slightly elevated temperature; minimal impact."
    case .serious: return "System is hot; performance may be reduced."
    case .critical: return "Critical temperature; significant throttling."
    @unknown default: return "Unknown thermal state."
    }
  }

  var color: Color {
    switch self {
    case .nominal: return .green
    case .fair: return .yellow
    case .serious: return .orange
    case .critical: return .red
    @unknown default: return .secondary
    }
  }

  var icon: String {
    switch self {
    case .nominal: return "thermometer.snowflake"
    case .fair: return "thermometer.medium"
    case .serious: return "thermometer.sun"
    case .critical: return "thermometer.sun.fill"
    @unknown default: return "thermometer"
    }
  }
}

// MARK: - Power & thermal data
struct PowerThermalSnapshot {
  var thermalState: Foundation.ProcessInfo.ThermalState
  var batteryLevel: Int?           // 0–100, nil if no battery
  var isCharging: Bool
  var powerSource: String          // "Battery" or "AC Power"
  var timeRemaining: String?       // "X min" or "Charging" etc.
}

// MARK: - Monitor
class PowerThermalMonitor: ObservableObject {
  @Published var snapshot: PowerThermalSnapshot
  private var timer: Timer?

  init() {
    self.snapshot = PowerThermalMonitor.readSnapshot()
    timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
      self?.refresh()
    }
    RunLoop.current.add(timer!, forMode: .common)
  }

  deinit {
    timer?.invalidate()
  }

  func refresh() {
    snapshot = PowerThermalMonitor.readSnapshot()
  }

  private static func readSnapshot() -> PowerThermalSnapshot {
    let thermal = Foundation.ProcessInfo.processInfo.thermalState
    var batteryLevel: Int?
    var isCharging = false
    var powerSource = "AC Power"
    var timeRemaining: String?

    // IOKit power source info (may be nil on desktop / no battery)
    guard let psInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() as CFTypeRef?,
          let psList = IOPSCopyPowerSourcesList(psInfo)?.takeRetainedValue() as? [CFTypeRef],
          let first = psList.first else {
      return PowerThermalSnapshot(
        thermalState: thermal,
        batteryLevel: nil,
        isCharging: false,
        powerSource: "AC Power",
        timeRemaining: nil
      )
    }

    if let desc = IOPSGetPowerSourceDescription(psInfo, first)?
      .takeUnretainedValue() as? [String: Any] {
      if let capacity = desc["Current Capacity"] as? Int {
        batteryLevel = capacity
      }
      if let state = desc["Power Source State"] as? String {
        powerSource = state
      }
      if let charging = desc["Is Charging"] as? Bool {
        isCharging = charging
      } else if let chargingNum = desc["Is Charging"] as? Int {
        isCharging = (chargingNum == 1)
      }
      if let time = desc["Time to Empty"] as? Int, time != -1 {
        timeRemaining = "\(time) min"
      } else if let timeFull = desc["Time to Full Charge"] as? Int, timeFull != -1 {
        timeRemaining = "Charging (\(timeFull) min)"
      }
    }

    return PowerThermalSnapshot(
      thermalState: thermal,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      powerSource: powerSource,
      timeRemaining: timeRemaining
    )
  }
}

// MARK: - View
struct PowerThermalView: View {
  @StateObject private var monitor = PowerThermalMonitor()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // Thermal pressure
        GroupBox("Thermal Pressure") {
          VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
              Image(systemName: monitor.snapshot.thermalState.icon)
                .font(.title)
                .foregroundStyle(monitor.snapshot.thermalState.color)
              VStack(alignment: .leading, spacing: 2) {
                Text(monitor.snapshot.thermalState.displayName)
                  .font(.title2)
                  .fontWeight(.semibold)
                  .foregroundStyle(monitor.snapshot.thermalState.color)
                Text(monitor.snapshot.thermalState.description)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
              Spacer()
            }
            .padding(.vertical, 4)
          }
        }

        // Power / battery
        GroupBox("Power") {
          VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
              Image(systemName: powerIcon)
                .font(.title)
                .foregroundStyle(powerColor)
              VStack(alignment: .leading, spacing: 2) {
                Text(powerTitle)
                  .font(.title2)
                  .fontWeight(.semibold)
                if let time = monitor.snapshot.timeRemaining {
                  Text(time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
              }
              Spacer()
              if let level = monitor.snapshot.batteryLevel {
                Text("\(level)%")
                  .font(.title2)
                  .fontWeight(.medium)
                  .foregroundStyle(powerColor)
              }
            }
            .padding(.vertical, 4)
            if monitor.snapshot.batteryLevel != nil {
              // Simple bar for battery level
              GeometryReader { geo in
                ZStack(alignment: .leading) {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                  RoundedRectangle(cornerRadius: 4)
                    .fill(powerColor)
                    .frame(width: geo.size.width * CGFloat(monitor.snapshot.batteryLevel ?? 0) / 100, height: 8)
                }
              }
              .frame(height: 8)
            }
          }
        }
      }
      .padding()
    }
    .frame(minWidth: 400, minHeight: 300)
  }

  private var powerIcon: String {
    if monitor.snapshot.batteryLevel != nil {
      return monitor.snapshot.isCharging ? "battery.100.bolt" : "battery.100"
    }
    return "powerplug"
  }

  private var powerColor: Color {
    guard let level = monitor.snapshot.batteryLevel else { return .accentColor }
    if monitor.snapshot.isCharging { return .green }
    if level <= 10 { return .red }
    if level <= 20 { return .orange }
    return .primary
  }

  private var powerTitle: String {
    if let level = monitor.snapshot.batteryLevel {
      return monitor.snapshot.isCharging ? "Charging" : "Battery"
    }
    return "AC Power"
  }
}

#Preview("Power & Thermal") {
  PowerThermalView()
    .frame(width: 500, height: 400)
}
