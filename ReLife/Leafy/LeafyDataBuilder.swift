import Foundation

struct LeafyDailySummary: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let pulseMin: Int
    let pulseAvg: Double
    let pulseMax: Int
    let spo2Avg: Double
    let skinTempAvg: Double
    let steps: Int
    let relifeScore: Int
    let recoveryPhase: String
    let peakTime: Date?
    let peakPulse: Int
    let notableEvents: [String]
}

struct LeafyTrendSnapshot: Hashable {
    let metric: String
    let direction: String
    let delta: Double
}

struct LeafyDataPackage {
    let jsonPayload: String
    let summaries: [LeafyDailySummary]
    let trends: [LeafyTrendSnapshot]
    let peakEvents: [String]
    let notableEvents: [String]
    let poorSleepDays: [String]?
}

enum LeafyDataBuilder {
    static func buildPackage(appState: AppState, learningModeEnabled: Bool) -> LeafyDataPackage {
        let samples = appState.samples
        guard !samples.isEmpty else {
            let emptyPayload = """
            {
              "days": 0,
              "notes": [],
              "message": "Keine Sensordaten verfügbar – bitte ReLife verbinden."
            }
            """
            return LeafyDataPackage(
                jsonPayload: emptyPayload,
                summaries: [],
                trends: [],
                peakEvents: [],
                notableEvents: [],
                poorSleepDays: nil
            )
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.timestamp) }
        let sortedDays = grouped.keys.sorted()
        let dayCount = min(14, max(7, sortedDays.count))
        let selectedDays = Array(sortedDays.suffix(dayCount))

        var summaries: [LeafyDailySummary] = []
        var peakEvents: [String] = []
        var notableEvents: [String] = []

        for day in selectedDays {
            guard let entries = grouped[day], !entries.isEmpty else { continue }
            let hrValues = entries.map { $0.hr }
            let spo2Values = entries.map { $0.spo2 }
            let tempValues = entries.map { $0.skinTempC }

            let hrMin = hrValues.min() ?? 0
            let hrMax = hrValues.max() ?? 0
            let hrAvg = entries.map { Double($0.hr) }.average()
            let spo2Avg = spo2Values.map { Double($0) }.average()
            let skinAvg = tempValues.average()
            let steps = entries.last?.steps ?? 0

            let peakSample = entries.max { $0.hr < $1.hr }
            if let sample = peakSample {
                let formatter = DateFormatter.leafyHourFormatter
                peakEvents.append("\(formatter.string(from: sample.timestamp)) — \(sample.hr) bpm")
            }

            var events: [String] = []
            if hrMax >= 150 {
                events.append("Sehr hoher Puls (\(hrMax) bpm)")
            } else if hrMax >= 130 {
                events.append("Hoher Pulspeak (\(hrMax) bpm)")
            }
            if spo2Values.min() ?? 100 < 94 {
                events.append("Niedrige SpO₂ Phase")
            }
            if skinAvg >= 34.5 {
                let skinTempStr = String(format: "%.1f", skinAvg)
                events.append("Hauttemperatur erhöht (\(skinTempStr)°C)")
            }
            if steps < 3000 {
                events.append("Sehr inaktiver Tag (\(steps) Schritte)")
            } else if steps >= 12000 {
                events.append("Aktiver Tag (\(steps) Schritte)")
            }

            notableEvents.append(contentsOf: events.map { "\(day.asLeafyDateString()): \($0)" })

            let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day) ?? day
            let snapshot = appState.snapshot(for: dayEnd)

            let summary = LeafyDailySummary(
                date: day,
                pulseMin: hrMin,
                pulseAvg: hrAvg,
                pulseMax: hrMax,
                spo2Avg: spo2Avg,
                skinTempAvg: skinAvg,
                steps: steps,
                relifeScore: snapshot.relifeScore,
                recoveryPhase: snapshot.recoveryPhase,
                peakTime: peakSample?.timestamp,
                peakPulse: peakSample?.hr ?? hrMax,
                notableEvents: events
            )
            summaries.append(summary)
        }

        let trends = buildTrends(from: summaries)
        let payload = makePayload(
            summaries: summaries,
            trends: trends,
            peakEvents: peakEvents,
            notableEvents: notableEvents,
            learningModeEnabled: learningModeEnabled
        )

        return LeafyDataPackage(
            jsonPayload: payload,
            summaries: summaries,
            trends: trends,
            peakEvents: peakEvents,
            notableEvents: notableEvents,
            poorSleepDays: nil
        )
    }

    private static func buildTrends(from summaries: [LeafyDailySummary]) -> [LeafyTrendSnapshot] {
        guard let first = summaries.first, let last = summaries.last else { return [] }
        let descriptors: [(metric: String, start: Double, end: Double, sensitivity: Double)] = [
            ("Puls", first.pulseAvg, last.pulseAvg, 3),
            ("SpO₂", first.spo2Avg, last.spo2Avg, 0.8),
            ("Hauttemperatur", first.skinTempAvg, last.skinTempAvg, 0.3),
            ("Schritte", Double(first.steps), Double(last.steps), 500),
            ("ReLife Score", Double(first.relifeScore), Double(last.relifeScore), 4)
        ]

        return descriptors.map { descriptor in
            let delta = descriptor.end - descriptor.start
            let absDelta = abs(delta)
            let direction: String
            if absDelta < descriptor.sensitivity {
                direction = "stabil"
            } else {
                direction = delta > 0 ? "steigend" : "fallend"
            }
            return LeafyTrendSnapshot(metric: descriptor.metric, direction: direction, delta: delta)
        }
    }

    private static func makePayload(
        summaries: [LeafyDailySummary],
        trends: [LeafyTrendSnapshot],
        peakEvents: [String],
        notableEvents: [String],
        learningModeEnabled: Bool
    ) -> String {
        let formatter = DateFormatter.leafyDateFormatter

        let payload: [String: Any] = [
            "days": summaries.count,
            "dates": summaries.map { formatter.string(from: $0.date) },
            "pulse_min": summaries.map { $0.pulseMin },
            "pulse_avg": summaries.map { Int($0.pulseAvg.rounded()) },
            "pulse_max": summaries.map { $0.pulseMax },
            "spo2_avg": summaries.map { Int($0.spo2Avg.rounded()) },
            "skin_temp_avg": summaries.map { Double(String(format: "%.2f", $0.skinTempAvg)) ?? $0.skinTempAvg },
            "steps": summaries.map { $0.steps },
            "relife_score": summaries.map { $0.relifeScore },
            "recovery_phases": summaries.map { $0.recoveryPhase },
            "trend_data": trends.map { ["metric": $0.metric, "direction": $0.direction, "delta": $0.delta] },
            "peak_events": peakEvents,
            "poor_sleep_days": NSNull(),
            "notable_events": notableEvents,
            "learning_mode": learningModeEnabled,
            "notes": []
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            return String(decoding: jsonData, as: UTF8.self)
        }

        return """
        {
          "days": \(summaries.count),
          "notes": ["JSON Encoding fehlgeschlagen"]
        }
        """
    }
}

private extension Date {
    func asLeafyDateString() -> String {
        DateFormatter.leafyDateFormatter.string(from: self)
    }
}

private extension DateFormatter {
    static let leafyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    static let leafyHourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM HH:mm"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}
