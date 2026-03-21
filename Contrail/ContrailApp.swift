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
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 640)
    }
}
