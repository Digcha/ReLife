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
        case .eda: xs = app.samples.map { $0.edaMicroSiemens }
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
            items.append(DailyVitality(date: day, vitalityScore: snapshot.vitalityScore, balanceScore: snapshot.balanceScore))
        }
        return items
    }

    // Aufteilung der letzten 24 Stunden nach Leitwert-Zonen
    private var electroDermalDistribution: [EDAZone] {
        let recent = app.samples.inLast(hours: 24)
        guard !recent.isEmpty else { return [] }
        let slice = recent.reduce(into: [EDAZone.Kind: Int]()) { partial, sample in
            let kind: EDAZone.Kind
            switch sample.edaMicroSiemens {
            case ..<2.2: kind = .calm
            case 2.2..<4.5: kind = .focus
            default: kind = .charged
            }
            partial[kind, default: 0] += 1
        }
        let total = Double(recent.count)
        return EDAZone.Kind.allCases.map { kind in
            let count = Double(slice[kind, default: 0])
            return EDAZone(kind: kind, ratio: count / total)
        }
    }

    private var edaSummary: String {
        guard let focusZone = electroDermalDistribution.first(where: { $0.kind == .focus }) else {
            return "Noch keine Verteilung vorhanden."
        }
        let focusPercent = Int(focusZone.ratio * 100)
        if focusPercent > 42 {
            return "Starker Fokus-Window – nimm Micro-Pausen für Balance."
        }
        if focusPercent < 25 {
            return "Sehr ruhige Leitwerte – achte auf dynamische Aktivierung."
        }
        return "Solide Balance zwischen Ruhe und Fokus."
    }

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd.MM."
        return df
    }()

    var body: some View {
        ScrollView {
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

                // Verlauf des Vitalitätsscores visualisieren
                if !dailyVitalities.isEmpty {
                    VitalityTimeline(dailyVitalities: dailyVitalities, formatter: dateFormatter)
                }

                if !electroDermalDistribution.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EDA-Zonen (24h)")
                            .font(.title3.bold())
                        Text(edaSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(electroDermalDistribution) { zone in
                                ZoneCard(zone: zone)
                            }
                        }
                    }
                    .padding()
                    .background(Color.rlCardBG.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                        MetricChartView(metric: .eda, range: .h24, samples: app.samples, temperatureUnit: app.temperatureUnit)
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
        var out = "timestamp,hr,spo2,skinTempC,edaMicroSiemens\n"
        // Zeitstempel im ISO-Format ausgeben
        let df = ISO8601DateFormatter()
        for s in app.samples {
            out += "\(df.string(from: s.timestamp)),\(s.hr),\(s.spo2),\(String(format: "%.2f", s.skinTempC)),\(String(format: "%.3f", s.edaMicroSiemens))\n"
        }
        csvText = out
        showShare = true
    }
}

// MARK: - Zusätzliche Strukturen für Vitalität
private struct DailyVitality: Identifiable {
    let id = UUID()
    let date: Date
    let vitalityScore: Int
    let balanceScore: Int
}

private struct VitalityTimeline: View {
    var dailyVitalities: [DailyVitality]
    var formatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ReLife Score Verlauf")
                .font(.title3.bold())
            Text("Balance & Vitalität der letzten 7 Tage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(dailyVitalities) { item in
                    AreaMark(
                        x: .value("Tag", item.date),
                        y: .value("Score", item.vitalityScore)
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
                        y: .value("Score", item.vitalityScore)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(Color.rlPrimary)

                    PointMark(
                        x: .value("Tag", item.date),
                        y: .value("Score", item.vitalityScore)
                    )
                    .symbolSize(70)
                    .foregroundStyle(Color.white)
                    .annotation(position: .top) {
                        VStack(spacing: 2) {
                            Text("\(item.vitalityScore)")
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

private struct EDAZone: Identifiable {
    enum Kind: CaseIterable, Identifiable {
        case calm
        case focus
        case charged
        var id: Self { self }

        var title: String {
            switch self {
            case .calm: return "Calm"
            case .focus: return "Focus"
            case .charged: return "Charged"
            }
        }

        var icon: String {
            switch self {
            case .calm: return "water.waves"
            case .focus: return "scope"
            case .charged: return "bolt.fill"
            }
        }

        var tint: Color {
            switch self {
            case .calm: return Color.mint
            case .focus: return Color.rlPrimary
            case .charged: return Color.pink
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let ratio: Double
}

private struct ZoneCard: View {
    var zone: EDAZone

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: zone.kind.icon)
                .font(.title2)
                .foregroundStyle(zone.kind.tint)
            Text(zone.kind.title)
                .font(.headline)
            Text("\(Int(zone.ratio * 100)) %")
                .font(.title3.bold())
                .foregroundStyle(zone.kind.tint)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
