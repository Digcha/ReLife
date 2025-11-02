import SwiftUI

/// Entry point that guides the user through pairing the ReLife M1 device.
struct ConnectionView: View {
    @EnvironmentObject private var bleManager: BLEManager
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "wave.3.forward.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.rlPrimary)

                Text("Verbinde dein ReLife M1")
                    .font(.largeTitle.bold())

                Text("Schalte dein ReLife-Armband ein und halte es in die Nähe deines iPhones.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                PrimaryButton(title: bleManager.isScanning ? "Scannen…" : "Scannen & Verbinden") {
                    bleManager.startScan()
                }
                .disabled(bleManager.isScanning)

                if bleManager.isScanning {
                    Text("Suche nach ReLife M1 …")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let error = bleManager.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 8) {
                Text("Oder überspringen, um alte Daten anzuzeigen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Überspringen") {
                    bleManager.skipToDashboard()
                    if app.samples.isEmpty {
                        app.generateLast10Days()
                    }
                    app.isConnected = false
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .onChange(of: bleManager.isConnected, initial: false) { oldValue, newValue in
            guard newValue else {
                app.isConnected = false
                return
            }

            if bleManager.didSkipConnection {
                if app.samples.isEmpty {
                    app.generateLast10Days()
                }
                app.isConnected = false
            } else {
                app.connectAndLoadDemo()
            }
        }
        .onAppear {
            if bleManager.isScanning && bleManager.isConnected {
                bleManager.stopScan()
            }
        }
    }
}

#Preview {
    ConnectionView()
        .environmentObject(BLEManager.shared)
        .environmentObject(AppState())
}
