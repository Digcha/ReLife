import SwiftUI
import Charts

// Darstellung längerfristiger Trends und CSV-Export

struct TrendsView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedMetric: MetricType = .all
    @State private var showShare = false
    @State private var csvText: String = ""

    // Kurzer Hinweis zum betrachteten Zeitraum
    private var rangeText: String { "Letzte 10 Tage" }

    // Berechnet einfache Min/Ø/Max-Werte für die Statistik-Kacheln
    private func stats(for metric: MetricType) -> (min: Double, avg: Double, max: Double)? {
        let xs: [Double]
        switch metric {
        case .hr: xs = app.samples.map { Double($0.hr) }
        case .spo2: xs = app.samples.map { Double($0.spo2) }
        case .skinTemp: xs = app.samples.map { app.temperatureUnit == .celsius ? $0.skinTempC : $0.skinTempC * 9/5 + 32 }
        case .steps: xs = app.samples.map { Double($0.steps) }
        case .all: return nil
        }
        guard !xs.isEmpty else { return nil }
        let minV = xs.min() ?? 0
        let maxV = xs.max() ?? 0
        let avgV = xs.reduce(0,+) / Double(xs.count)
        return (minV, avgV, maxV)
    }

    // Aggregiert Vitality-Snapshots für die letzten sieben Tage
    private var dailyVitalities: [DailyVitality] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var items: [DailyVitality] = []
        for offset in (0..<7).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                  let reference = cal.date(bySettingHour: 23, minute: 30, second: 0, of: day) else { continue }
            let snapshot = app.snapshot(for: reference)
            if snapshot == .empty { continue }
            items.append(DailyVitality(date: day, relifeScore: snapshot.relifeScore, balanceScore: snapshot.balanceScore))
        }
        return items
    }

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM."
        return df
    }()
    private let stepGoal = 10_000

    private var weeklySteps: [DailySteps] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var items: [DailySteps] = []
        for offset in (0..<7).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let samplesForDay = app.samples.filter { cal.isDate($0.timestamp, inSameDayAs: day) }
            guard let steps = samplesForDay.last?.steps else { continue }
            items.append(DailySteps(date: day, steps: steps))
        }
        return items
    }

    private func averageSteps(for days: [DailySteps]) -> Int {
        guard !days.isEmpty else { return 0 }
        let total = days.reduce(0) { $0 + $1.steps }
        return total / days.count
    }

    private func stepsSummary(for days: [DailySteps]) -> String {
        guard let latest = days.last else {
            return "Noch keine Schrittwerte vorhanden."
        }
        let avg = averageSteps(for: days)
        if latest.steps >= stepGoal {
            return "Du knackst dein Tagesziel regelmäßig – halte dieses Momentum fest."
        }
        if avg >= Int(Double(stepGoal) * 0.9) {
            return "Durchschnittlich \(avg.formatted()) Schritte – nur noch ein kleiner Push bis zum Ziel."
        }
        return "Aktuell \(latest.steps.formatted()) Schritte – plane Walks oder Treppenwege, um die \(stepGoal.formatted()) zu erreichen."
    }

    var body: some View {
        let steps = weeklySteps
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(rangeText)
                        .font(Font.title2.bold())
                    Spacer()
                    // Export bereitstellen, damit die Daten geteilt werden können
                    Button(action: { exportCSV() }) {
                        Label("CSV exportieren", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                // Verlauf des ReLife-Scores visualisieren
                if !dailyVitalities.isEmpty {
                    VitalityTimeline(dailyVitalities: dailyVitalities, formatter: dateFormatter)
                }

                if !steps.isEmpty {
                    StepsWeeklyView(
                        dailySteps: steps,
                        goal: stepGoal,
                        formatter: dateFormatter,
                        summary: stepsSummary(for: steps),
                        averageSteps: averageSteps(for: steps)
                    )
                }

                // Nutzer entscheidet, welche Kennzahl gezeigt wird
                Picker("Metrik", selection: $selectedMetric) {
                    ForEach(MetricType.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                // Statistikkarten zeigen Minimum, Durchschnitt und Maximum
                if let s = stats(for: selectedMetric == .all ? .hr : selectedMetric) {
                    HStack(spacing: 12) {
                        StatCard(title: "Min", value: String(format: selectedMetric == .skinTemp ? "%.1f" : "%.0f", s.min))
                        StatCard(title: "Ø", value: String(format: selectedMetric == .skinTemp ? "%.1f" : "%.0f", s.avg))
                        StatCard(title: "Max", value: String(format: selectedMetric == .skinTemp ? "%.1f" : "%.0f", s.max))
                    }
                }

                // Diagramme je nach Auswahl der Kennzahl
                VStack(spacing: 16) {
                    if selectedMetric == .all {
                        MetricChartView(metric: .hr, range: .h24, samples: app.samples, temperatureUnit: app.temperatureUnit)
                        MetricChartView(metric: .spo2, range: .h24, samples: app.samples, temperatureUnit: app.temperatureUnit)
                        MetricChartView(metric: .skinTemp, range: .h24, samples: app.samples, temperatureUnit: app.temperatureUnit)
                        MetricChartView(metric: .steps, range: .h24, samples: app.samples, temperatureUnit: app.temperatureUnit)
                    } else {
                        MetricChartView(metric: selectedMetric, range: .h24, samples: app.samples, temperatureUnit: app.temperatureUnit)
                    }
                }
            }
            .padding()
        }
        // Teilt die CSV über das iOS-Teilen-Menü
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [csvText])
        }
    }

    // Baut eine einfache CSV-Tabelle über alle Messwerte
    private func exportCSV() {
        var out = "timestamp,hr,spo2,skinTempC,steps\n"
        // Zeitstempel im ISO-Format ausgeben
        let df = ISO8601DateFormatter()
        for s in app.samples {
            out += "\(df.string(from: s.timestamp)),\(s.hr),\(s.spo2),\(String(format: "%.2f", s.skinTempC)),\(s.steps)\n"
        }
        csvText = out
        showShare = true
    }
}

// MARK: - Zusätzliche Strukturen für Vitalität
private struct DailyVitality: Identifiable {
    let id = UUID()
    let date: Date
    let relifeScore: Int
    let balanceScore: Int
}

private struct VitalityTimeline: View {
    var dailyVitalities: [DailyVitality]
    var formatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ReLife-Score Verlauf")
                .font(.title3.bold())
            Text("Balance & Energie der letzten 7 Tage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(dailyVitalities) { item in
                    AreaMark(
                        x: .value("Tag", item.date),
                        y: .value("Score", item.relifeScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.rlPrimary.opacity(0.55), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Tag", item.date),
                        y: .value("Score", item.relifeScore)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(Color.rlPrimary)

                    PointMark(
                        x: .value("Tag", item.date),
                        y: .value("Score", item.relifeScore)
                    )
                    .symbolSize(70)
                    .foregroundStyle(Color.white)
                    .annotation(position: .top) {
                        VStack(spacing: 2) {
                            Text("\(item.relifeScore)")
                                .font(.caption.bold())
                                .foregroundStyle(Color.rlPrimary)
                            Text(formatter.string(from: item.date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(formatter.string(from: date))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    if let score = value.as(Double.self) {
                        AxisValueLabel("\(Int(score))")
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DailySteps: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int
}

private struct StepsWeeklyView: View {
    var dailySteps: [DailySteps]
    var goal: Int
    var formatter: DateFormatter
    var summary: String
    var averageSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schritte (7 Tage)")
                .font(.title3.bold())
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(dailySteps) { item in
                    BarMark(
                        x: .value("Tag", item.date),
                        y: .value("Schritte", item.steps)
                    )
                    .foregroundStyle(item.steps >= goal ? Color.rlPrimary : Color.blue.opacity(0.7))
                    .cornerRadius(6)
                }
                RuleMark(y: .value("Ziel", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .topTrailing) {
                        Text("\(goal.formatted()) Ziel")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    if let date = value.as(Date.self) {
                        AxisValueLabel(formatter.string(from: date))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }

            HStack {
                Label("\(averageSteps.formatted()) Schritte Ø", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Label(goalLabel, systemImage: "flag.checkered")
                    .font(.subheadline)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.rlCardBG.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var goalLabel: String {
        if let last = dailySteps.last, last.steps >= goal {
            return "Ziel erreicht"
        }
        let latest = dailySteps.last?.steps ?? 0
        let remaining = max(goal - latest, 0)
        return "Noch \(remaining.formatted())"
    }
}
