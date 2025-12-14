//
//  ReLifeApp.swift
//  ReLife
//
//  Erstellt von Dimitar Chalakov am 14.09.25.
//

import SwiftUI
import Combine
import UserNotifications

@main
struct ReLifeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var sampleStore = SampleStore()
    @StateObject private var bleManager = BluetoothManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .today

    private let notificationManager = ReLifeNotificationManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if bleManager.isConnected || bleManager.didSkipConnection {
                    MainDashboardView(selectedTab: $selectedTab)
                } else {
                    ConnectionView()
                }
            }
            .onAppear {
                appState.bind(to: sampleStore)
                bleManager.configure(sampleStore: sampleStore)
                notificationManager.configure()
            }
            .onChange(of: bleManager.isConnected, initial: false) { _, isConnected in
                appState.isConnected = isConnected
                if scenePhase == .active {
                    notificationManager.clearConnectionNotification()
                } else {
                    notificationManager.updateConnectionNotification(isConnected: isConnected)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    notificationManager.clearConnectionNotification()
                } else {
                    notificationManager.updateConnectionNotification(isConnected: bleManager.isConnected)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .relifeNotificationAction)) { note in
                guard let action = note.object as? ReLifeNotificationManager.Action else { return }
                switch action {
                case .openScanner:
                    bleManager.didSkipConnection = false
                    if !bleManager.isConnected {
                        bleManager.startScan()
                    }
                case .openToday:
                    selectedTab = .today
                    bleManager.didSkipConnection = true
                }
            }
            .environmentObject(appState)
            .environmentObject(sampleStore)
            .environmentObject(bleManager)
            .preferredColorScheme(appState.colorSchemeOption.systemScheme)
        }
    }
}

/// Hosts the main application dashboard once the BLE flow has finished.
struct MainDashboardView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        ContentView(selectedTab: $selectedTab)
    }
}
