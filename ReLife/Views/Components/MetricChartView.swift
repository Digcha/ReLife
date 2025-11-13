import SwiftUI
import Charts
import UIKit

// Größeres Linien-Diagramm für die ausgewählte Kennzahl
struct MetricChartView: View {
    let metric: MetricType
    let range: TimeWindow
    let samples: [Sample]
    let temperatureUnit: TemperatureUnit
    @State private var selectedDate: Date?
    @State private var selectedSample: Sample?
    @State private var lastHapticSampleID: UUID?

    // Nur die Daten im gewählten Zeitraum anzeigen
    private var filtered: [Sample] {
        samples.inLast(hours: range.hours)
    }

    private var title: String { metric.rawValue }

    private let cardWidth: CGFloat = 190
    private let cardHeight: CGFloat = 74
    @State private var cardPositionX: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            ZStack(alignment: .topLeading) {
                chart
                    .frame(height: 220)
                if let selected = selectedSample, let cardX = cardPositionX {
                    FloatingValueCard(date: selected.timestamp, valueText: formattedValue(for: selected), accent: accentColor)
                        .frame(width: cardWidth)
                        .offset(x: cardX - cardWidth / 2, y: -cardHeight - 12)
                        .transition(.opacity.combined(with: .offset(y: -10)))
                }
            }
            .padding(.top, selectedSample == nil ? 0 : cardHeight + 12)
            footer
        }
        .padding(20)
        .background(glassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 30, y: 14)
        .onChange(of: selectedDate, initial: false) { _, newValue in
            guard let newValue else {
                selectedSample = nil
                cardPositionX = nil
                return
            }
            selectedSample = nearestSample(to: newValue)
        }
        .onChange(of: selectedSample?.id, initial: false) { _, newID in
            guard let newID, newID != lastHapticSampleID else { return }
            lastHapticSampleID = newID
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.7)
        }
        .onChange(of: range, initial: false) { _, _ in
            selectedSample = nil
            selectedDate = nil
            cardPositionX = nil
        }
        .onChange(of: samples.count, initial: false) { _, _ in
            selectedSample = nil
            selectedDate = nil
            cardPositionX = nil
        }
        .accessibilityLabel(Text("Chart \(title)"))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: metricIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentColor)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(latestValueText)
                        .font(.title3.bold())
                }
            }
            Spacer()
            Text(range.rawValue)
                .font(.caption.weight(.bold))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            MetricFooterStat(label: "Min", value: statValues.map { formatStatValue($0.min) } ?? "—")
            MetricFooterStat(label: "Ø", value: statValues.map { formatStatValue($0.avg) } ?? "—")
            MetricFooterStat(label: "Max", value: statValues.map { formatStatValue($0.max) } ?? "—")
            Spacer()
            Text(metricTagline)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(filtered) { sample in
                AreaMark(
                    x: .value("Zeit", sample.timestamp),
                    y: .value("Wert", yValue(for: sample))
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Zeit", sample.timestamp),
                    y: .value("Wert", yValue(for: sample))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accentColor)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisTick().foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel().foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisTick().foregroundStyle(Color.white.opacity(0.2))
                AxisValueLabel().foregroundStyle(.secondary)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(plotGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let frame = geometry[plotFrame]
                    ZStack {
                        if let selected = selectedSample,
                           let xPos = proxy.position(forX: selected.timestamp),
                           let yPos = proxy.position(forY: yValue(for: selected)) {
                            let absoluteX = frame.origin.x + xPos
                            let absoluteY = frame.origin.y + yPos
                            Color.clear
                                .preference(key: CardXPreferenceKey.self, value: absoluteX)

                            Path { path in
                                path.move(to: CGPoint(x: absoluteX, y: frame.minY))
                                path.addLine(to: CGPoint(x: absoluteX, y: frame.maxY))
                            }
                            .stroke(crosshairGradient, style: StrokeStyle(lineWidth: 1.3))

                            Path { path in
                                path.move(to: CGPoint(x: frame.minX, y: absoluteY))
                                path.addLine(to: CGPoint(x: frame.maxX, y: absoluteY))
                            }
                            .stroke(crosshairGradient.opacity(0.35), style: StrokeStyle(lineWidth: 0.8, dash: [5, 4]))

                            Circle()
                                .fill(accentColor.opacity(0.28))
                                .frame(width: 46, height: 46)
                                .position(x: absoluteX, y: absoluteY)
                                .blur(radius: 4)

                            Circle()
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                                .background(Circle().fill(accentColor))
                                .frame(width: 12, height: 12)
                                .position(x: absoluteX, y: absoluteY)
                        } else {
                            Color.clear
                                .preference(key: CardXPreferenceKey.self, value: nil)
                        }
                    }
                } else {
                    Color.clear
                        .preference(key: CardXPreferenceKey.self, value: nil)
                }
            }
            .allowsHitTesting(false)
        }
        .onPreferenceChange(CardXPreferenceKey.self) { newValue in
            cardPositionX = newValue
        }
    }

    private var accentColor: Color {
        switch metric {
        case .hr, .all: return .rlPrimary
        case .spo2: return .rlSecondary
        case .skinTemp: return .orange
        case .steps: return .blue
        }
    }

    private var crosshairGradient: LinearGradient {
        LinearGradient(colors: [accentColor.opacity(0.1), accentColor.opacity(0.8)], startPoint: .top, endPoint: .bottom)
    }

    private var plotGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.02),
                accentColor.opacity(0.08),
                Color.black.opacity(0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                accentColor.opacity(0.35),
                accentColor.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.85),
                        Color.rlPrimary.opacity(0.2),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.45))
            )
    }

    private var metricIcon: String {
        switch metric {
        case .hr, .all: return "waveform.path.ecg"
        case .spo2: return "lungs.fill"
        case .skinTemp: return "thermometer.sun.fill"
        case .steps: return "figure.walk"
        }
    }

    private var latestValueText: String {
        if let selected = selectedSample {
            return formattedValue(for: selected)
        }
        guard let latest = filtered.last else { return "—" }
        return formattedValue(for: latest)
    }

    private var statValues: (min: Double, avg: Double, max: Double)? {
        guard !filtered.isEmpty else { return nil }
        let values = filtered.map { yValue(for: $0) }
        guard let min = values.min(), let max = values.max() else { return nil }
        let avg = values.reduce(0, +) / Double(values.count)
        return (min, avg, max)
    }

    private func formatStatValue(_ value: Double) -> String {
        switch metric {
        case .hr, .all:
            return "\(Int(value.rounded())) bpm"
        case .spo2:
            return "\(Int(value.rounded())) %"
        case .skinTemp:
            return String(format: "%.1f %@", value, temperatureUnit.rawValue)
        case .steps:
            return "\(Int(value.rounded()).formatted())"
        }
    }

    private var metricTagline: String {
        switch metric {
        case .hr, .all:
            return "60–90 bpm = steady energy"
        case .spo2:
            return "≥ 96 % hält dich im grünen Bereich"
        case .skinTemp:
            return "33–34 °C signalisiert Balance"
        case .steps:
            return "10.000 Schritte liefern Turbo-Energie"
        }
    }

    private func nearestSample(to date: Date) -> Sample? {
        guard !filtered.isEmpty else { return nil }
        return filtered.min(by: { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
        })
    }

    private func formattedValue(for sample: Sample) -> String {
        switch metric {
        case .hr, .all:
            return "\(sample.hr) bpm"
        case .spo2:
            return "\(sample.spo2) %"
        case .skinTemp:
            let temp = temperatureUnit == .celsius ? sample.skinTempC : sample.skinTempC * 9/5 + 32
            return String(format: "%.1f %@", temp, temperatureUnit.rawValue)
        case .steps:
            return "\(sample.steps.formatted()) Schritte"
        }
    }

    private func yValue(for sample: Sample) -> Double {
        switch metric {
        case .hr, .all:
            return Double(sample.hr)
        case .spo2:
            return Double(sample.spo2)
        case .skinTemp:
            return temperatureUnit == .celsius ? sample.skinTempC : sample.skinTempC * 9/5 + 32
        case .steps:
            return Double(sample.steps)
        }
    }
}

// Blendfreie Floating Card zur Anzeige des Messwerts
private struct FloatingValueCard: View {
    var date: Date
    var valueText: String
    var accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(valueText)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accent.opacity(0.45), lineWidth: 1)
                )
        )
        .overlay(
            Circle()
                .fill(accent.opacity(0.45))
                .frame(width: 6, height: 6)
                .offset(y: 16)
                .opacity(0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: accent.opacity(0.3), radius: 16, y: 8)
    }
}

private struct MetricFooterStat: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CardXPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() {
            value = next
        } else {
            value = nil
        }
    }
}
