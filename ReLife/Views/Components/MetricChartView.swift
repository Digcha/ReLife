import SwiftUI
import Charts

// Größeres Linien-Diagramm für die ausgewählte Kennzahl
struct MetricChartView: View {
    let metric: MetricType
    let range: TimeWindow
    let samples: [Sample]
    let temperatureUnit: TemperatureUnit

    // Nur die Daten im gewählten Zeitraum anzeigen
    private var filtered: [Sample] {
        samples.inLast(hours: range.hours)
    }

    private var title: String { metric.rawValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Font.headline)
            // Verschiedene Linien je nach Kennzahl
            Chart(filtered) { s in
                switch metric {
                case .hr:
                    LineMark(x: .value("Zeit", s.timestamp), y: .value("Puls", s.hr))
                        .foregroundStyle(Color.rlPrimary)
                case .spo2:
                    LineMark(x: .value("Zeit", s.timestamp), y: .value("SpO₂", s.spo2))
                        .foregroundStyle(Color.rlSecondary)
                    PointMark(x: .value("Zeit", s.timestamp), y: .value("SpO₂", s.spo2))
                        .foregroundStyle(Color.rlSecondary.opacity(0.6))
                case .skinTemp:
                    LineMark(
                        x: .value("Zeit", s.timestamp),
                        y: .value("Hauttemp.", temperatureUnit == .celsius ? s.skinTempC : s.skinTempC * 9/5 + 32)
                    )
                        .foregroundStyle(.orange)
                case .eda:
                    LineMark(x: .value("Zeit", s.timestamp), y: .value("Hautleitw.", s.edaMicroSiemens))
                        .foregroundStyle(.pink)
                case .all:
                    LineMark(x: .value("Zeit", s.timestamp), y: .value("Puls", s.hr))
                        .foregroundStyle(Color.rlPrimary)
                }
            }
            .frame(height: 180)
            .chartXAxis(.automatic)
            .chartYAxis(.automatic)
            .accessibilityLabel(Text("Chart \(title)"))
        }
        .padding()
        .background(Color.rlCardBG)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
