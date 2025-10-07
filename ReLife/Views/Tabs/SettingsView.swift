// Einstellungen für Darstellung, Einheiten und Daten
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var showConfirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                // Farbmodus für die Oberfläche
                Section("Darstellung") {
                    Picker("Modus", selection: $app.colorSchemeOption) {
                        ForEach(ColorSchemeOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                }
                // Temperatureinheit wechseln
                Section("Einheiten") {
                    Picker("Temperatur", selection: $app.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                }
                // Demo-Daten manuell aktualisieren oder leeren
                Section("Daten") {
                    Button("Demo-Daten neu laden") { app.reloadDemoData() }
                        .disabled(!app.isConnected)
                    Button("Alle Daten löschen", role: .destructive) { showConfirmClear = true }
                }
                // Transparenter Hinweis zur Offline-Nutzung
                Section("Datenschutz") {
                    Text("Offline-Demo, keine echten Verbindungen.")
                }
                // Basisinformationen zur App
                Section("Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    }
                    Text("ReLife: live, track & repeat")
                }
                // Status der (Demo-)Verbindung
                Section("Verbindung") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(app.isConnected ? "Verbunden" : "Nicht verbunden")
                            .foregroundColor(app.isConnected ? .green : .secondary)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .confirmationDialog("Alle Daten wirklich löschen?", isPresented: $showConfirmClear, titleVisibility: .visible) {
                // Sicherheitsabfrage, bevor alles zurückgesetzt wird
                Button("Löschen", role: .destructive) { app.clearAllData() }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }
}

