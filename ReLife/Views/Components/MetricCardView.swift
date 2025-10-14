import SwiftUI
import Charts

// Kleine Kennzahlenkarte mit Icon, Wert und Mini-Chart
struct MetricCardView: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let sparklineData: [Sample]
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(Font.title3)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(Font.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Text(unit)
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(Font.subheadline)
                .foregroundColor(.secondary)
            // Sparklines visualisieren den Verlauf kompakt
            Chart(sparklineData) { s in
                LineMark(
                    x: .value("Zeit", s.timestamp),
                    y: .value("Wert", yValue(for: title, sample: s))
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 40)
        }
        .padding()
        .background(Color.rlCardBG)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue("\(value) \(unit)")
    }

    // Hilfsfunktion, um passenden Wert aus Sample zu ziehen
    private func yValue(for title: String, sample: Sample) -> Double {
        switch title {
        case _ where title.contains("Puls"): return Double(sample.hr)
        case _ where title.contains("SpO"): return Double(sample.spo2)
        case _ where title.contains("Hauttemp"): return sample.skinTempC
        default: return sample.edaMicroSiemens
        }
    }
}
