import Foundation

struct LeafyMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

struct LeafyContext {
    let recentMessages: [LeafyMessage]
    let healthPayload: String
    let healthSummary: String

    static func build(from appState: AppState, recentMessages: [LeafyMessage]) -> LeafyContext {
        let package = LeafyDataBuilder.buildPackage(appState: appState, learningModeEnabled: false)

        let transcript = recentMessages.suffix(10).map { message in
            let sender = message.isUser ? "User" : "Leafy"
            return "\(sender): \(message.text)"
        }.joined(separator: "\n")

        let summary: String
        if package.summaries.isEmpty {
            summary = "Keine ReLife-Daten verbunden. Nur Demo-Kontext aktiv."
        } else {
            let last = package.summaries.last!
            summary = "Letzte Kennzahlen: Puls min \(last.pulseMin), Ø \(Int(last.pulseAvg)), max \(last.pulseMax). Schritte \(last.steps). ReLife Score \(last.relifeScore). Recovery: \(last.recoveryPhase)."
        }

        let payload = """
        {
        "relife_data": \(package.jsonPayload),
        "recent_chat": "\(transcript)"
        }
        """

        return LeafyContext(
            recentMessages: Array(recentMessages.suffix(10)),
            healthPayload: payload,
            healthSummary: summary
        )
    }
}

extension Notification.Name {
    static let leafyClearToday = Notification.Name("LeafyClearToday")
}
