//
//  ReLifeApp.swift
//  ReLife
//
//  Erstellt von Dimitar Chalakov am 14.09.25.
//

import SwiftUI

@main
struct ReLifeApp: App {
    // AppState einmalig erzeugen und halten
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Gemeinsamen Zustand in die View-Hierarchie geben
                .environmentObject(appState)
                // Farbmodus an Benutzerauswahl koppeln
                .preferredColorScheme(appState.colorSchemeOption.systemScheme)
        }
    }
}
