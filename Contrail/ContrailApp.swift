//
//  ContrailApp.swift
//  Contrail
//

import SwiftUI
import SwiftData

@main
struct ContrailApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Session.self)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
