//
//  cpu_os_analyticsApp.swift
//  cpu-os-analytics
//
//  Created by Chris Ho on 12/25/25.
//

import SwiftUI
import SwiftData

@main // u can think of this as the entry point into the app, the main function like in C++
struct cpu_os_analyticsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
	  // in swift, for function parameters you must specify what arguments maps to which parameters using colon :, not positional by default
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
