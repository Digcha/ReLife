import SwiftUI
import Charts

// Tagesübersicht mit wichtigsten Messwerten und Aktionen
struct TodayView: View {
    @EnvironmentObject var app: AppState
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
                Text("ReLife – Heute")
                    .font(Font.largeTitle.bold())

                // Hinweis falls Nutzer noch nicht verbunden ist
                if !app.isConnected {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Nicht verbunden")
                            .font(Font.headline)
                        Spacer()
                        Button("Verbinden") { app.connectAndLoadDemo() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.rlCardBG)
                    .cornerRadius(12)
                }

                // Kacheln mit aktuellen Kennzahlen
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCardView(
                        title: "Puls",
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
    }
}

// Das AddNoteSheet liegt unter Components/AddNoteSheet.swift zur Wiederverwendung
