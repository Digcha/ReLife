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
    let steps: Int
}

// Verdichtete Kennzahlen für das Vitalitäts-Cockpit
struct VitalitySnapshot: Hashable {
    var relifeScore: Int
    var balanceScore: Int
    var recoveryPhase: String
    var summary: String
    var highlight: String
    var trendDescription: String

    static let empty = VitalitySnapshot(
        relifeScore: 0,
        balanceScore: 0,
        recoveryPhase: "Nicht verbunden",
        summary: "Verbinde ReLife, um deinen Vitalitätsstatus zu sehen.",
        highlight: "—",
        trendDescription: "Keine Daten verfügbar."
    )
}

// Steuert welche Kennzahl in Diagrammen angezeigt wird
enum MetricType: String, CaseIterable, Identifiable {
    case all = "Alle"
    case hr = "Puls"
    case spo2 = "SpO₂"
    case skinTemp = "Hauttemp."
    case steps = "Schritte"
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
    @Published var vitality: VitalitySnapshot = .empty

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
        let calendar = Calendar.current
        var data: [Sample] = []
        var stepsToday = 0

        let startOfFirstDay = calendar.startOfDay(for: tenDaysAgo)
        let totalDaySpan = calendar.dateComponents([.day], from: startOfFirstDay, to: calendar.startOfDay(for: now)).day ?? 0
        let dayCount = max(totalDaySpan + 1, 1)

        var dayProfiles = DemoDayProfile.pool(forDayCount: dayCount)
        if dayProfiles.isEmpty, let fallback = DemoDayProfile.catalog.first {
            dayProfiles = [fallback]
        }

        var currentDayAnchor = startOfFirstDay
        var currentDayIndex = 0
        var activeProfile = dayProfiles[currentDayIndex]
        var dayStepCap = Int.random(in: activeProfile.stepCapRange)
        var zigZagSeed = Double.random(in: 0...(Double.pi * 2))

        let interval: TimeInterval = 60 * 10 // alle 10 Minuten
        var t = tenDaysAgo
        while t <= now {
            let comps = calendar.dateComponents([.hour], from: t)
            let hour = comps.hour ?? 12

            let dayAnchor = calendar.startOfDay(for: t)
            if dayAnchor != currentDayAnchor {
                currentDayAnchor = dayAnchor
                stepsToday = 0
                if currentDayIndex + 1 < dayProfiles.count {
                    currentDayIndex += 1
                }
                activeProfile = dayProfiles[currentDayIndex]
                dayStepCap = Int.random(in: activeProfile.stepCapRange)
                zigZagSeed = Double.random(in: 0...(Double.pi * 2))
            }

            // Grundkurve für den Puls mit Profil-Offsets
            let hrBase: Double
            if (0...5).contains(hour) { hrBase = 56 }
            else if (6...9).contains(hour) { hrBase = 72 }
            else if (10...17).contains(hour) { hrBase = 88 }
            else if (18...21).contains(hour) { hrBase = 82 }
            else { hrBase = 62 }

            let hrNoise = Double.random(in: -10...12)
            let scenarioHr = Double.random(in: activeProfile.hrDeltaRange)
            let hrZigZag = sin((Double(hour) / 4.0) + zigZagSeed) * (activeProfile.zigZagAmplitude * 12)
            let hr = max(48, min(175, Int(hrBase + hrNoise + scenarioHr + hrZigZag)))

            // Sauerstoffsättigung mit realistischen Drops
            let spo2Base = Int.random(in: activeProfile.spo2Range)
            let spo2ZigZag = Int((sin((Double(hour) / 3.0) + zigZagSeed) * activeProfile.zigZagAmplitude * 3).rounded())
            let spo2 = max(90, min(100, spo2Base + Int.random(in: -1...1) + spo2ZigZag))

            // Hauttemperatur inkl. Temperatur-Spitzen
            let skinBase: Double = 33.0 + sin((Double(hour)/24.0) * .pi * 2.0) * 1.2
            let tempNoise = Double.random(in: -0.5...0.5)
            let scenarioTemp = Double.random(in: activeProfile.tempOffsetRange)
            let skinTemp = max(30.0, min(37.5, skinBase + tempNoise + scenarioTemp))

            // Schrittverteilung je nach Tageszeit + Profil
            var stepIncrement: Int
            switch hour {
            case 0...5:
                stepIncrement = Int.random(in: 0...6)
            case 6...9:
                stepIncrement = Int.random(in: 20...140)
            case 10...17:
                stepIncrement = Int.random(in: 60...260)
            case 18...21:
                stepIncrement = Int.random(in: 40...190)
            default:
                stepIncrement = Int.random(in: 10...80)
            }
            if Bool.random() && (11...18).contains(hour) {
                stepIncrement += Int.random(in: 80...260)
            }

            let zigZagSteps = Int((sin((Double(hour) / 2.5) + zigZagSeed) * activeProfile.zigZagAmplitude * 120).rounded())
            stepIncrement = max(0, stepIncrement + zigZagSteps)
            let multiplier = Double.random(in: activeProfile.stepMultiplierRange)
            stepIncrement = max(0, Int(Double(stepIncrement) * multiplier))

            if stepsToday + stepIncrement > dayStepCap {
                stepIncrement = max(dayStepCap - stepsToday, 0)
            }
            stepsToday = min(stepsToday + stepIncrement, dayStepCap)

            data.append(Sample(timestamp: t, hr: hr, spo2: spo2, skinTempC: skinTemp, steps: stepsToday))
            t = t.addingTimeInterval(interval)
        }
        samples = data
        refreshWellnessInsights()
    }

    // Löscht aktuelle Messwerte und generiert neue
    func reloadDemoData() {
        samples.removeAll()
        generateLast10Days()
    }

    // Setzt App-Zustand zurück und leert alles
    func clearAllData() {
        samples.removeAll()
        isConnected = false
        vitality = .empty
    }

    // MARK: - Vitalitäts-Analyse
    func refreshWellnessInsights(reference date: Date = Date()) {
        guard let snapshot = calculateVitalitySnapshot(reference: date) else {
            vitality = .empty
            return
        }

        vitality = snapshot
    }

    // Liefert eine Momentaufnahme, ohne den State zu verändern (z. B. für Analysen)
    func snapshot(for reference: Date = Date()) -> VitalitySnapshot {
        calculateVitalitySnapshot(reference: reference) ?? .empty
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
        let start = Calendar.current.startOfDay(for: Date())
        return self.filter { $0.timestamp >= start }
    }
}

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

// MARK: - Markenfarben
extension Color {
    // Einheitliche Farben aus dem Asset-Katalog
    static var rlPrimary: Color { Color("BrandPrimary") }
    static var rlSecondary: Color { Color("BrandSecondary") }
    static var rlCardBG: Color { Color("CardBG") }
}

// MARK: - Mathematik
private func normalize(_ value: Double, min: Double, max: Double) -> Double {
    guard max > min else { return 0 }
    return ((value - min) / (max - min)).clamp(to: 0...1)
}

private extension Double {
    func clamp(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension AppState {
    // Berechnet Vitalitätskennzahlen für einen Zeitpunkt
    func calculateVitalitySnapshot(reference date: Date) -> VitalitySnapshot? {
        let last6h = samples.inLast(hours: 6, from: date)
        let last24h = samples.inLast(hours: 24, from: date)

        guard !last6h.isEmpty, !last24h.isEmpty else {
            return nil
        }

        let avgHr6 = last6h.map { Double($0.hr) }.average()
        let avgHr24 = last24h.map { Double($0.hr) }.average()
        let avgSpo2 = last24h.map { Double($0.spo2) }.average()
        let avgTemp = last24h.map { $0.skinTempC }.average()
        let todaySamples = last24h.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
        let todaySteps = todaySamples.last?.steps ?? last24h.last?.steps ?? 0

        let stepGoal = 10_000.0
        let hrDelta = avgHr6 - avgHr24
        let normalizedSpo2 = normalize(avgSpo2, min: 92, max: 100)
        let normalizedTemp = (1.0 - abs(avgTemp - 33.5) / 3.0).clamp(to: 0...1)
        let hrStability = (1.0 - (abs(hrDelta) / 12.0)).clamp(to: 0...1)
        let stepProgress = min(Double(todaySteps) / stepGoal, 1.2).clamp(to: 0...1)

        let rawScore = (stepProgress * 40)
            + (normalizedSpo2 * 25)
            + (normalizedTemp * 15)
            + (hrStability * 20)

        let clampedRaw = rawScore.clamp(to: 20...100)
        let finalScore = Int(clampedRaw)

        let relaxedSamples = last24h.filter { $0.hr < 85 }
        let relaxedCount = relaxedSamples.count
        let totalCount = max(last24h.count, 1)
        let relaxedRatio = Double(relaxedCount) / Double(totalCount)
        let centered = (relaxedRatio * 2.0) - 1.0
        let balanceIndexUnclamped = 1.0 - abs(centered)
        let balanceIndex = balanceIndexUnclamped.clamp(to: 0...1)

        let weightedBalance = (balanceIndex * 0.6) + (stepProgress * 0.4)
        let scaledBalance = weightedBalance * 100.0
        let balanceScore = Int(scaledBalance.clamp(to: 30...95))

        let recoveryPhase: String
        if finalScore >= 80 {
            recoveryPhase = "Regenerative Phase"
        } else if finalScore >= 60 {
            recoveryPhase = "Kalibrieren"
        } else {
            recoveryPhase = "Reboot nötig"
        }

        let highlight: String
        if stepProgress < 0.3 {
            highlight = "Nur wenige Schritte heute – kurze Spaziergänge aktivieren deine Energie."
        } else if stepProgress > 0.95 {
            highlight = "Tagesziel erreicht – setze Bonusbewegungen für Extra-Reserven."
        } else if hrDelta <= -5 {
            highlight = "Dein Ruhepuls sinkt – Zeichen guter Regeneration."
        } else if avgSpo2 >= 98 {
            highlight = "Stabile Sauerstoffsättigung."
        } else if normalizedTemp < 0.55 {
            highlight = "Kühlere Hauttemperatur – halte dich warm und trinke genug."
        } else {
            highlight = "Achte auf ruhige Atemphasen."
        }

        let trend: String
        if hrDelta < -3 {
            trend = "Trend: Puls entspannt sich im Vergleich zu den letzten 24 Stunden."
        } else if hrDelta > 3 {
            trend = "Trend: Puls ist aktuell höher – plane Micro-Breaks ein."
        } else {
            trend = "Trend: Solide Stabilität, halte deinen Flow."
        }

        let summary = """
        Der ReLife-Score kombiniert Schrittfortschritt, Sauerstoffsättigung, Hauttemperatur und Pulsruhe zu einem täglichen Energieindex.
        """

        return VitalitySnapshot(
            relifeScore: finalScore,
            balanceScore: balanceScore,
            recoveryPhase: recoveryPhase,
            summary: summary,
            highlight: highlight,
            trendDescription: trend
        )
    }
}

// MARK: - Demo Profile Generator
private struct DemoDayProfile {
    enum Kind {
        case balanced
        case lowSteps
        case stress
        case lowSpo2
        case hotSkin
    }

    let kind: Kind
    let stepMultiplierRange: ClosedRange<Double>
    let stepCapRange: ClosedRange<Int>
    let hrDeltaRange: ClosedRange<Double>
    let spo2Range: ClosedRange<Int>
    let tempOffsetRange: ClosedRange<Double>
    let zigZagAmplitude: Double

    static var catalog: [DemoDayProfile] {
        [
            DemoDayProfile(
                kind: .balanced,
                stepMultiplierRange: 0.85...1.15,
                stepCapRange: 9000...14500,
                hrDeltaRange: -3...4,
                spo2Range: 96...99,
                tempOffsetRange: -0.2...0.2,
                zigZagAmplitude: 0.25
            ),
            DemoDayProfile(
                kind: .lowSteps,
                stepMultiplierRange: 0.18...0.35,
                stepCapRange: 1100...2600,
                hrDeltaRange: -2...5,
                spo2Range: 96...99,
                tempOffsetRange: -0.2...0.2,
                zigZagAmplitude: 0.15
            ),
            DemoDayProfile(
                kind: .stress,
                stepMultiplierRange: 1.0...1.35,
                stepCapRange: 7000...11000,
                hrDeltaRange: 8...15,
                spo2Range: 95...97,
                tempOffsetRange: 0...0.3,
                zigZagAmplitude: 0.6
            ),
            DemoDayProfile(
                kind: .lowSpo2,
                stepMultiplierRange: 0.5...0.9,
                stepCapRange: 4500...8500,
                hrDeltaRange: -1...6,
                spo2Range: 92...95,
                tempOffsetRange: -0.1...0.2,
                zigZagAmplitude: 0.35
            ),
            DemoDayProfile(
                kind: .hotSkin,
                stepMultiplierRange: 0.7...1.05,
                stepCapRange: 6000...10000,
                hrDeltaRange: 0...6,
                spo2Range: 95...98,
                tempOffsetRange: 0.5...1.1,
                zigZagAmplitude: 0.4
            )
        ]
    }

    static func pool(forDayCount count: Int) -> [DemoDayProfile] {
        guard count > 0 else { return [] }
        var pool: [DemoDayProfile] = []
        let requiredKinds: [Kind] = [.lowSteps, .stress, .lowSpo2, .hotSkin]

        for kind in requiredKinds {
            if pool.count >= count { break }
            if let match = catalog.first(where: { $0.kind == kind }) {
                pool.append(match)
            }
        }

        while pool.count < count {
            if let random = catalog.randomElement() {
                pool.append(random)
            }
        }

        return Array(pool.prefix(count)).shuffled()
    }
}
