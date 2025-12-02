// Einstellungen für Darstellung, Einheiten und Daten
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var showHelpSheet = false
    private let leafyArchive = LeafyArchiveService()
    @State private var leafyAlert = false

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
                Section("Dev Options") {
                    Button {
                        app.generateLast10Days()
                        app.refreshWellnessInsights()
                    } label: {
                        HStack {
                            Text("Create Demo Data")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    Button(role: .destructive) {
                        app.clearAllData()
                    } label: {
                        HStack {
                            Text("Delete All Data")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                }
                Section("Leafy") {
                    Button(role: .destructive) {
                        leafyAlert = true
                    } label: {
                        Text("Leafy-Chat von heute löschen")
                    }
                }
                // Transparenter Hinweis zur Offline-Nutzung
                Section("Datenschutz") {
                    Text("Offline-Demo, keine echten Verbindungen.")
                }
                Section {
                    Button {
                        showHelpSheet = true
                    } label: {
                        HelpLaunchButton()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
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
            .alert("Leafy-Chat löschen?", isPresented: $leafyAlert) {
                Button("Löschen", role: .destructive) {
                    let today = Calendar.current.startOfDay(for: Date())
                    leafyArchive.clearChat(for: today)
                    NotificationCenter.default.post(name: .leafyClearToday, object: nil)
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der Chatverlauf von heute wird endgültig gelöscht.")
            }
            .sheet(isPresented: $showHelpSheet) {
                HelpSheetView()
            }
        }
    }
}

private struct HelpLaunchButton: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hilfe & Guides")
                    .font(.headline.weight(.semibold))
                Text("Was ist ReLife? Score, Datenschutz, Tipps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

private enum HelpTab: String, CaseIterable, Identifiable {
    case intro = "Was ist ReLife?"
    case score = "ReLife Score"
    case privacy = "Datenschutz & Sensoren"
    case tips = "Tipps für bessere Werte"
    var id: String { rawValue }
}

private struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab: HelpTab = .intro

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Hilfe", selection: $tab) {
                    ForEach(HelpTab.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        helpContent
                    }
                    .padding(.vertical)
                }
            }
            .padding()
            .navigationTitle("Hilfe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var helpContent: some View {
        switch tab {
        case .intro:
            HelpInfoCard(title: "Was ist ReLife?", rows: [
                ("Mission", "ReLife trackt deine Vitalimpulse (Kreislauf, Sauerstoff, Temperatur, Bewegung) und fasst sie in einem Score für Energie & Erholung zusammen."),
                ("In Kürze", "Trage dein Wearable, verbinde ReLife und erhalte Live-Insights plus Micro-Coaching.")
            ])
        case .score:
            HelpInfoCard(title: "So entsteht der Score", rows: [
                ("Schritte – 40 %", "Fortschritt auf das 10.000 Ziel. Bonuspunkte über 100 % motivieren zum Dranbleiben."),
                ("SpO₂ – 25 %", "Stabile 96–100 % halten dich oben. Drops zeigen Stress oder Atmung an."),
                ("Pulsruhe – 20 %", "Vergleicht den 6h-Schnitt mit den letzten 24h, um Erholung zu erkennen."),
                ("Hauttemperatur – 15 %", "Abweichungen von ca. 33,5 °C machen Überbelastung oder Infekte sichtbar."),
                ("Balance-Level", "Mischt Ruhephasen und Aktivität, damit du weißt, ob du dich eher erholst oder überziehst.")
            ])
        case .privacy:
            HelpInfoCard(title: "Datenschutz & Sensoren", rows: [
                ("Offline-Demo", "Alle Daten in der Testversion bleiben nur auf deinem Gerät."),
                ("Sensorzugriff", "Nur Puls, Schritte, SpO₂ und Hauttemperatur werden verarbeitet."),
                ("Transparenz", "Du kannst jederzeit Daten löschen oder neue Demo-Tage laden.")
            ])
        case .tips:
            HelpInfoCard(title: "Tipps für bessere Werte", rows: [
                ("Mikro-Walks", "Alle 60–90 Minuten aufstehen, Puls & Schritte glätten."),
                ("Atem-Reset", "3 tiefe Atemzüge durch die Nase pushen SpO₂ und senken den Stress."),
                ("Warm bleiben", "Layer oder warme Getränke stabilisieren die Hauttemperatur."),
                ("Sleep Window", "8h Schlafzeit blocken, damit der Score wieder hochläuft.")
            ])
        }
    }
}

private struct HelpInfoCard: View {
    var title: String
    var rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.element.0)
                        .font(.subheadline.weight(.semibold))
                    Text(entry.element.1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
