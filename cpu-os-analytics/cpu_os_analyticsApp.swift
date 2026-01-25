//
//  cpu_os_analyticsApp.swift
//  cpu-os-analytics
//
//  Created by Chris Ho on 12/25/25.
//

import SwiftUI

@main // u can think of this as the entry point into the app, the main function like in C++
struct cpu_os_analyticsApp: App {
  // in swift, for function parameters you must specify what arguments maps to which parameters using colon :, not positional by default
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .defaultSize(width: 1000, height: 700)
  }
}
