import SwiftUI

// Einfache Einstiegsansicht zum Laden der Demo-Daten
struct ConnectScreen: View {
    @EnvironmentObject var app: AppState
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            // Funk-Icon und Kernaussage
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(Font.system(size: 64))
                .foregroundColor(.rlSecondary)
            Text("ReLife verbinden")
                .font(Font.largeTitle.bold())
            Text("Tippe auf Verbinden, um ReLife zu koppeln.")
                .font(Font.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Primäre Aktion verbindet nur das Gerät
            PrimaryButton(title: "Verbinden") {
                app.connectDevice()
            }
            .padding(.horizontal)
            // Zusätzliche Info über Sheet
            Button("Mehr erfahren") { showInfo = true }
                .foregroundColor(.rlSecondary)

            Spacer()
        }
        // Zeigt erklärenden Hinweis als Sheet
        .sheet(isPresented: $showInfo) {
            VStack(spacing: 16) {
                Text("Über ReLife")
                    .font(Font.title2.bold())
                Text("Offline-Version ohne echte Verbindungen. Verbinde dein Gerät, um Live-Daten zu erhalten.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                PrimaryButton(title: "Schließen") { showInfo = false }
                    .padding(.horizontal)
                Spacer()
            }
            .presentationDetents([.medium])
            .padding()
        }
        .padding()
    }
}
