import Foundation
import SwiftUI

// MARK: - Modelle
// Hält die Messwerte einer Zeile aus den Demo-Daten
struct Sample: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let hr: Int
    let spo2: Int
    let skinTempC: Double
    let edaMicroSiemens: Double
}

// Speichert eine Notiz, optional mit Tag
struct Note: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var tag: NoteTag?
    var text: String
}

// Vorgegebene Kategorien für Notizen
enum NoteTag: String, CaseIterable, Identifiable {
    case stress = "Stress"
    case sleep = "Schlaf"
    case sport = "Sport"
    case work = "Arbeit"
    var id: String { rawValue }
}

// Steuert welche Kennzahl in Diagrammen angezeigt wird
enum MetricType: String, CaseIterable, Identifiable {
    case all = "Alle"
    case hr = "Puls"
    case spo2 = "SpO₂"
    case skinTemp = "Hauttemp."
    case eda = "Hautleitw."
    var id: String { rawValue }
}

// Enthält Zeitfenster-Optionen für die Charts
enum TimeWindow: String, CaseIterable, Identifiable {
    case h6 = "6h"
    case h12 = "12h"
    case h24 = "24h"
    var hours: Double {
        switch self { case .h6: 6; case .h12: 12; case .h24: 24 }
    }
    var id: String { rawValue }
}

// Benutzer wählt hier zwischen Celsius und Fahrenheit
enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius = "°C"
    case fahrenheit = "°F"
    var id: String { rawValue }
}

// Hält die gewünschte Farbmodus-Einstellung
enum ColorSchemeOption: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Hell"
    case dark = "Dunkel"
    var id: String { rawValue }
    var systemScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Zustandsverwaltung
// Zentraler Zustand der App, wird als EnvironmentObject geteilt
final class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var samples: [Sample] = []
    @Published var notes: [Note] = []

    @Published var temperatureUnit: TemperatureUnit = .celsius
    @Published var colorSchemeOption: ColorSchemeOption = .system

    // MARK: - Aktionen
    // Verbindet die Demo und lädt die Daten einmalig
    func connectAndLoadDemo() {
        isConnected = true
        generateLast10Days()
    }

    // Erstellt Mock-Daten für die letzten zehn Tage
    func generateLast10Days() {
        let now = Date()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        var data: [Sample] = []

        let interval: TimeInterval = 60 * 10 // alle 10 Minuten
        var t = tenDaysAgo
        while t <= now {
            let comps = Calendar.current.dateComponents([.hour], from: t)
            let hour = comps.hour ?? 12

            // Einfache Tageskurve für den Puls
            let hrBase: Double
            if (0...5).contains(hour) { hrBase = 56 }
            else if (6...9).contains(hour) { hrBase = 72 }
            else if (10...17).contains(hour) { hrBase = 88 }
            else if (18...21).contains(hour) { hrBase = 82 }
            else { hrBase = 62 }
            let hrNoise = Double.random(in: -12...12)
            let hr = max(50, min(160, Int(hrBase + hrNoise)))

            // Sauerstoffsättigung leicht schwanken lassen
            let spo2 = max(92, min(100, Int(Double.random(in: 95...99) + Double.random(in: -2...2))))

            // Hauttemperatur mit Tagesverlauf variieren
            let skinBase: Double = 33.0 + sin((Double(hour)/24.0) * .pi * 2.0) * 1.2
            let skinTemp = max(30.0, min(36.0, skinBase + Double.random(in: -0.6...0.6)))

            // Hautleitwert tagsüber höher mit zufälligen Spitzen
            var eda = 1.0 + (Double(hour) > 7 && Double(hour) < 22 ? 2.0 : 0.3) + Double.random(in: 0...1.5)
            if Bool.random() && (10...18).contains(hour) { eda += Double.random(in: 1.0...6.0) }
            eda = max(0.2, min(20.0, eda))

            data.append(Sample(timestamp: t, hr: hr, spo2: spo2, skinTempC: skinTemp, edaMicroSiemens: eda))
            t = t.addingTimeInterval(interval)
        }
        samples = data
    }

    // Löscht aktuelle Messwerte und generiert neue
    func reloadDemoData() {
        samples.removeAll()
        generateLast10Days()
    }

    // Setzt App-Zustand zurück und leert alles
    func clearAllData() {
        samples.removeAll()
        notes.removeAll()
        isConnected = false
    }

    // MARK: - Notizen
    // Legt eine neue Notiz an und schiebt sie nach oben
    func addNote(tag: NoteTag?, text: String) {
        notes.insert(Note(date: Date(), tag: tag, text: text), at: 0)
    }

    // Komfortfunktion für Stress-Markierungen
    func addStressMarker() {
        addNote(tag: .stress, text: "Stress-Marke gesetzt")
    }
}

// MARK: - Hilfsfunktionen
extension Array where Element == Sample {
    // Filtert Messwerte auf einen Zeitraum zurück
    func inLast(hours: Double, from reference: Date = Date()) -> [Sample] {
        let start = Calendar.current.date(byAdding: .hour, value: -Int(hours), to: reference) ?? reference
        return self.filter { $0.timestamp >= start && $0.timestamp <= reference }
    }

    // Liefert nur Messwerte ab dem aktuellen Tagesbeginn
    func forToday() -> [Sample] {
        guard let start = Calendar.current.startOfDay(for: Date()) as Date? else { return [] }
        return self.filter { $0.timestamp >= start }
    }
}

// MARK: - Markenfarben
extension Color {
    // Einheitliche Farben aus dem Asset-Katalog
    static var rlPrimary: Color { Color("BrandPrimary") }
    static var rlSecondary: Color { Color("BrandSecondary") }
    static var rlCardBG: Color { Color("CardBG") }
}
