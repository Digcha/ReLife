import SwiftUI
#if os(iOS)
import UIKit
#endif

// Enthält wiederverwendbare Button-Varianten
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: {
            #if os(iOS)
            // Kurzes haptisches Feedback für iOS
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        }) {
            Text(title)
                .font(Font.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.rlPrimary)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel(Text(title))
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.headline)
                .foregroundColor(Color.rlSecondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.rlCardBG)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.rlSecondary.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
        }
        .accessibilityLabel(Text(title))
    }
}
