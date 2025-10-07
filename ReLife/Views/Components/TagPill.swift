import SwiftUI

// Kleines Abzeichen für Tags in Listen
struct TagPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Font.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.rlSecondary.opacity(0.15))
            .foregroundColor(Color.rlSecondary)
            .cornerRadius(8)
            .accessibilityLabel(Text(text))
    }
}
