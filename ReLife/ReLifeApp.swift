//
//  ReLifeApp.swift
//  ReLife
//
//  Erstellt von Dimitar Chalakov am 14.09.25.
//

import SwiftUI

@main
struct ReLifeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var bleManager = BLEManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if bleManager.isConnected {
                    MainDashboardView()
                } else {
                    ConnectionView()
                }
            }
            .environmentObject(appState)
            .environmentObject(bleManager)
            .preferredColorScheme(appState.colorSchemeOption.systemScheme)
        }
    }
}

/// Hosts the main application dashboard once the BLE flow has finished.
struct MainDashboardView: View {
    var body: some View {
        ContentView()
    }
}
