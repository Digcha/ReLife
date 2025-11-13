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
        VStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(color)
                )
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Capsule()
                .fill(color.opacity(0.6))
                .frame(height: 3)
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
        .frame(maxWidth: .infinity)
        .frame(minHeight: 170)
        .multilineTextAlignment(.center)
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
        case _ where title.contains("Schritt"): return Double(sample.steps)
        default: return Double(sample.hr)
        }
    }
}
