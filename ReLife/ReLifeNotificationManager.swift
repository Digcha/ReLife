import Foundation
import UserNotifications
import UIKit

/// Manages local notifications for the ReLife connection status.
final class ReLifeNotificationManager: NSObject {
    static let shared = ReLifeNotificationManager()

    enum Action: String {
        case openScanner = "relife.action.scanner"
        case openToday = "relife.action.today"
    }

    private let center = UNUserNotificationCenter.current()
    private let identifier = "relife.connection.status"
    private let categoryIdentifier = "relife.connection.status.category"

    func configure() {
        center.delegate = self
        registerCategories()
        requestNotificationPermissionIfNeeded()
    }

    func requestNotificationPermissionIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .badge]) { _, _ in }
        }
    }

    /// Updates or replaces the single connection notification. Skips when the app is active.
    func updateConnectionNotification(isConnected: Bool) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                break
            default:
                return
            }

            DispatchQueue.main.async {
                // Do not show a banner while the app is active.
                if UIApplication.shared.applicationState == .active {
                    self.clearConnectionNotification()
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = "ReLife Status"
                content.body = isConnected ? "Gerät verbunden" : "Gerät getrennt"
                content.sound = nil
                content.categoryIdentifier = self.categoryIdentifier

                let request = UNNotificationRequest(
                    identifier: self.identifier,
                    content: content,
                    trigger: nil
                )

                self.center.add(request, withCompletionHandler: nil)
            }
        }
    }

    func clearConnectionNotification() {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private func registerCategories() {
        let scanner = UNNotificationAction(
            identifier: Action.openScanner.rawValue,
            title: "Gerät verbinden",
            options: [.foreground]
        )

        let today = UNNotificationAction(
            identifier: Action.openToday.rawValue,
            title: "Tagesansicht",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [scanner, today],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }
}

extension ReLifeNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let action = Action(rawValue: response.actionIdentifier) {
            NotificationCenter.default.post(
                name: .relifeNotificationAction,
                object: action
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let relifeNotificationAction = Notification.Name("relife.notification.action")
}
