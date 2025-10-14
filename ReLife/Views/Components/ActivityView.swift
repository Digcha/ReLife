import SwiftUI
import UIKit

// Wrapper, um das iOS Teilen-Sheet aus SwiftUI aufzurufen
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Controller mit den zu teilenden Objekten erzeugen
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
