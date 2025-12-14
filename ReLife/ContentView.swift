//
//  ContentView.swift
//  ReLife
//
//  Erstellt von Dimitar Chalakov am 14.09.25.
//

import SwiftUI

enum AppTab: Hashable {
    case today
    case trends
    case leafy
    case settings
}

// Zeigt entweder die App-Tabs oder den Verbindungsbildschirm
struct ContentView: View {
    @EnvironmentObject var app: AppState
    @Binding var selectedTab: AppTab

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem { Label("Heute", systemImage: "heart.text.square") }
            .tag(AppTab.today)

            NavigationStack {
                TrendsView()
            }
            .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.trends)

            NavigationStack {
                LeafyView(appState: app)
            }
            .tabItem { Label("Leafy", systemImage: "leaf.fill") }
            .tag(AppTab.leafy)

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(.rlPrimary)
    }
}

#Preview {
    ContentView(selectedTab: .constant(.today))
        .environmentObject(AppState())
        .environmentObject(SampleStore())
        .environmentObject(BluetoothManager.shared)
}
