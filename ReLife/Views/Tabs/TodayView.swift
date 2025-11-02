import SwiftUI
import Charts

// Tagesübersicht mit wichtigsten Messwerten und Aktionen
struct TodayView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var bleManager: BLEManager
    @State private var timeWindow: TimeWindow = .h6
    @State private var showAddNote = false
    @State private var noteText: String = ""
    @State private var noteTag: NoteTag? = nil

    // Messwerte nur für den aktuellen Tag
    private var today: [Sample] { app.samples.forToday() }
    // Daten für das gewählte Zeitfenster
    private var window: [Sample] { app.samples.inLast(hours: timeWindow.hours) }

    private var latest: Sample? { today.last }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ReLife – Heute")
                        .font(Font.largeTitle.bold())
                    Text(app.vitality.recoveryPhase)
                        .font(Font.subheadline)
                        .foregroundStyle(.secondary)
                }

                VitalityHero(snapshot: app.vitality)

                // Hinweis falls Nutzer noch nicht verbunden ist
                if !bleManager.isConnected {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Nicht verbunden")
                            .font(Font.headline)
                        Spacer()
                        Button("Scannen & Verbinden") {
                            app.isConnected = false
                            bleManager.resumeConnectionFlow()
                        }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.rlCardBG)
                    .cornerRadius(12)
                }

                // Kacheln mit aktuellen Kennzahlen
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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

                    MetricCardView(
                        title: "Hautleitwert",
                        value: latest != nil ? String(format: "%.1f", latest!.edaMicroSiemens) : "–",
                        unit: "µS",
                        icon: "waveform.path.ecg",
                        sparklineData: today,
                        color: .pink
                    )
                    .onTapGesture {}
                }

                // Vitalitäts-Hinweise
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

                // Steuerung für das Zeitfenster der Charts
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
                    MetricChartView(metric: .eda, range: timeWindow, samples: app.samples, temperatureUnit: app.temperatureUnit)
                }

                // Schnellaktionen
                VStack(alignment: .leading, spacing: 12) {
                    Text("Schnellaktionen")
                        .font(Font.headline)
                    HStack(spacing: 12) {
                        Button {
                            app.addStressMarker()
                        } label: {
                            Label("Stress-Marke setzen", systemImage: "exclamationmark.circle")
                        }
                        .buttonStyle(.bordered)

                        Button { showAddNote = true } label: {
                            Label("Notiz hinzufügen", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding()
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteSheet(noteText: $noteText, noteTag: $noteTag) {
                app.addNote(tag: noteTag, text: noteText)
                // Eingaben nach dem Speichern zurücksetzen
                noteText = ""
                noteTag = nil
            }
        }
        .onChange(of: app.samples) {
            app.refreshWellnessInsights()
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
                        Text("Vitality Score")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(snapshot.vitalityScore)")
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

// Das AddNoteSheet liegt unter Components/AddNoteSheet.swift zur Wiederverwendung
