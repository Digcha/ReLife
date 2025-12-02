import SwiftUI
import Charts

// Tagesübersicht mit wichtigsten Messwerten und Aktionen
struct TodayView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var bleManager: BluetoothManager
    @EnvironmentObject var sampleStore: SampleStore
    @State private var timeWindow: TimeWindow = .h6
    private let metricColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    // Messwerte nur für den aktuellen Tag
    private var today: [Sample] { app.samples.forToday() }
    private var latest: Sample? { today.last }
    private let stepGoal: Int = 10_000
    private var todaysSteps: Int { latest?.steps ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ReLife – Heute")
                                .font(Font.largeTitle.bold())
                            Text(app.vitality.recoveryPhase)
                                .font(Font.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if sampleStore.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Daten werden geladen")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.rlCardBG)
                            .clipShape(Capsule(style: .continuous))
                        } else if today.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Waiting for connect")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.rlCardBG)
                            .clipShape(Capsule(style: .continuous))
                        }
                    }
                }

                if !bleManager.isConnected {
                    Button {
                        app.isConnected = false
                        bleManager.resumeConnectionFlow()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.title2)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nicht verbunden")
                                    .font(.headline)
                                Text("Tippen zum Scannen & Verbinden")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.rlCardBG)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.09), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                }

                if today.isEmpty {
                    EmptyTodayCard(isLoading: sampleStore.isLoading, isConnected: bleManager.isConnected)
                } else {
                    LazyVGrid(columns: metricColumns, alignment: .center, spacing: 16) {
                        MetricCardView(
                            title: "Puls aktuell",
                            value: latest != nil ? "\(latest!.hr)" : "–",
                            unit: "bpm",
                            icon: "heart.fill",
                            sparklineData: today,
                            color: .rlPrimary
                        )
                        .onTapGesture {}

                        MetricCardView(
                            title: "SpO₂",
                            value: latest != nil ? "\(latest!.spo2)" : "–",
                            unit: "%",
                            icon: "aqi.medium",
                            sparklineData: today,
                            color: .rlSecondary
                        )
                        .onTapGesture {}

                        let temp = latest != nil ? (app.temperatureUnit == .celsius ? latest!.skinTempC : latest!.skinTempC * 9/5 + 32) : nil
                        MetricCardView(
                            title: "Hauttemp.",
                            value: temp != nil ? String(format: "%.1f", temp!) : "–",
                            unit: app.temperatureUnit.rawValue,
                            icon: "thermometer.sun",
                            sparklineData: today,
                            color: .orange
                        )
                        .onTapGesture {}
                    }

                    CompactStepsCard(steps: todaysSteps, goal: stepGoal)

                    VitalityHero(snapshot: app.vitality)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ReLife Insight")
                            .font(Font.title2.bold())
                        InsightRow(text: app.vitality.summary, icon: "sparkles")
                        InsightRow(text: app.vitality.highlight, icon: "leaf.circle")
                        InsightRow(text: app.vitality.trendDescription, icon: "chart.line.uptrend.xyaxis")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Picker("Zeitraum", selection: $timeWindow) {
                        ForEach(TimeWindow.allCases) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 16) {
                        MetricChartView(metric: .hr, range: timeWindow, samples: app.samples, temperatureUnit: app.temperatureUnit)
                        MetricChartView(metric: .spo2, range: timeWindow, samples: app.samples, temperatureUnit: app.temperatureUnit)
                        MetricChartView(metric: .skinTemp, range: timeWindow, samples: app.samples, temperatureUnit: app.temperatureUnit)
                        MetricChartView(metric: .steps, range: timeWindow, samples: app.samples, temperatureUnit: app.temperatureUnit)
                    }
                }
            }
            .padding()
        }
    }
}

// Hero-Kachel verdichtet den ReLife-Score visuell in einer Glasoptik
private struct VitalityHero: View {
    var snapshot: VitalitySnapshot

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(gradientBorder, lineWidth: 1.2)
                        .blendMode(.softLight)
                )
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(heroGradient)
                        .scaleEffect(1.03)
                        .blur(radius: 24)
                )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ReLife-Score")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(snapshot.relifeScore)")
                                .font(.system(size: 58, weight: .bold, design: .rounded))
                                .foregroundStyle(scoreGradient)
                            Text("von 100")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Label("\(snapshot.balanceScore)", systemImage: "circle.circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Balance-Level")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Label(snapshot.recoveryPhase, systemImage: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .symbolVariant(.fill)
                        .foregroundStyle(Color.rlPrimary)
                        .font(.title2)
                }
            }
            .padding(24)
        }
        .padding(.vertical, 8)
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.75),
                Color.rlPrimary.opacity(0.68),
                Color.black.opacity(0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var scoreGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color.rlPrimary.opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var gradientBorder: AngularGradient {
        AngularGradient(
            colors: [
                .white.opacity(0.35),
                Color.rlPrimary.opacity(0.45),
                .white.opacity(0.15),
                .black.opacity(0.35),
                Color.rlSecondary.opacity(0.3)
            ],
            center: .center
        )
    }
}

// Zeile mit ikonischem Hinweistext
private struct InsightRow: View {
    var text: String
    var icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.rlPrimary)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

// Kompakter Steps-Block mit Highlight-Ring
private struct CompactStepsCard: View {
    var steps: Int
    var goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1.0)
    }

    private var remainingSteps: Int {
        max(goal - steps, 0)
    }

    private var goalReached: Bool { steps >= goal }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AngularGradient(colors: [.rlSecondary, .rlPrimary, .blue], center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: goalReached ? Color.rlSecondary.opacity(0.5) : Color.rlPrimary.opacity(0.3), radius: 6, y: 4)
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.bold))
                    Text("ZIEL")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                Label("Schritte", systemImage: "figure.walk.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(steps.formatted())
                    .font(.title.bold())
                Text(goalReached ? "Ziel erreicht – Bonusbewegung starten." : "\(remainingSteps.formatted()) Schritte bis \(goal.formatted()).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    StepsBadge(
                        text: goalReached ? "Ziel erreicht" : "Noch \(remainingSteps.formatted())",
                        systemImage: goalReached ? "sparkles" : "flag.checkered",
                        highlight: goalReached
                    )
                    StepsBadge(text: "Move+", systemImage: "bolt.heart")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 8)
    }
}

private struct LoadingStateView: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct EmptyTodayCard: View {
    var isLoading: Bool
    var isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isLoading ? "arrow.clockwise" : "antenna.radiowaves.left.and.right")
                .font(.title2.weight(.semibold))
                .foregroundStyle(isLoading ? Color.rlPrimary : .secondary)
                .rotationEffect(isLoading ? .degrees(360) : .degrees(0))
                .animation(isLoading ? .linear(duration: 1.2).repeatForever(autoreverses: false) : .default, value: isLoading)
            VStack(alignment: .leading, spacing: 4) {
                Text(isLoading ? "Daten werden geladen …" : (isConnected ? "Warte auf erste Messwerte" : "Waiting for connect"))
                    .font(.headline)
                Text(isConnected ? "ReLife M1 sendet gleich erste Samples." : "Tippe oben, um dein ReLife M1 zu verbinden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.rlCardBG)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

private struct StepsBadge: View {
    var text: String
    var systemImage: String
    var highlight: Bool = false

    var body: some View {
        Label(text.uppercased(), systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .foregroundStyle(highlight ? Color.black : Color.secondary)
            .background(
                Capsule()
                    .fill(highlight ? Color.rlSecondary.opacity(0.25) : Color.white.opacity(0.08))
            )
    }
}
