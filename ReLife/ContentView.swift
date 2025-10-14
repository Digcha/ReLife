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
        Group {
            if app.isConnected {
                // Hauptnavigation mit Tabs
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
                        LogView()
                    }
                    .tabItem { Label("Protokoll", systemImage: "note.text") }

                    SettingsView()
                        .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                }
            } else {
                // Hinweis zum Koppeln anzeigen
                ConnectScreen()
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
