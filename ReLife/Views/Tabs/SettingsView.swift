// Einstellungen für Darstellung, Einheiten und Daten
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var bleManager: BLEManager
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
                Section("Letzte Datei vom Board") {
                    SettingsRow(title: "Erstellt am", value: formatted(bleManager.lastFileCreatedAt))
                    SettingsRow(title: "Übertragen am", value: formatted(bleManager.lastSyncAt))
                    if bleManager.syncInProgress {
                        ProgressView("Synchronisierung läuft…",
                                     value: bleManager.syncProgress ?? 0,
                                     total: 1.0)
                    }
                    Button("Alle Daten löschen", role: .destructive) { showConfirmClear = true }
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
                    SettingsRow(title: "Status",
                                value: app.isConnected ? "Verbunden" : "Nicht verbunden",
                                valueColor: app.isConnected ? .green : .secondary)
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

private extension SettingsView {
    func formatted(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .numeric, time: .shortened)
    }
}

private struct SettingsRow: View {
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
        }
    }
}
