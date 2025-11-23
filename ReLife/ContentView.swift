//
//  ContentView.swift
//  ReLife
//
//  Erstellt von Dimitar Chalakov am 14.09.25.
//

import SwiftUI

// Zeigt entweder die App-Tabs oder den Verbindungsbildschirm
struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem { Label("Heute", systemImage: "heart.text.square") }

            NavigationStack {
                TrendsView()
            }
            .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                LeafyView(appState: app)
            }
            .tabItem { Label("Leafy", systemImage: "leaf.fill") }

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        .tint(.rlPrimary)
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
