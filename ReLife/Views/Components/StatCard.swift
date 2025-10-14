import SwiftUI

// Zeigt eine kleine Statistik wie Minimum, Mittelwert oder Maximum
struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Font.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(Font.headline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.rlCardBG)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }
}
