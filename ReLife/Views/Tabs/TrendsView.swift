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
