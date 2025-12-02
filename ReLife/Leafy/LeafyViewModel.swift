import Foundation
import SwiftUI

@MainActor
final class LeafyChatViewModel: ObservableObject {
    @Published var messages: [LeafyMessage] = []
    @Published var isThinking: Bool = false
    @Published var inputText: String = ""
    @Published var archiveDates: [Date] = []
    @Published var showArchive: Bool = false
    @Published var selectedArchiveDate: Date?

    private let calendar = Calendar.current
    private let archiveService: LeafyArchiveService
    private let aiService: LeafyAIService
    private let appState: AppState
    private var currentConversationDay: Date
    private var clearObserver: NSObjectProtocol?

    init(appState: AppState, archiveService: LeafyArchiveService = LeafyArchiveService(), aiService: LeafyAIService = LeafyAIService()) {
        self.appState = appState
        self.archiveService = archiveService
        self.aiService = aiService
        self.currentConversationDay = Calendar.current.startOfDay(for: Date())
        loadTodayChat()
        clearObserver = NotificationCenter.default.addObserver(
            forName: .leafyClearToday,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.clearTodaysChat()
            }
        }
    }

    deinit {
        if let clearObserver { NotificationCenter.default.removeObserver(clearObserver) }
    }

    func loadTodayChat() {
        currentConversationDay = calendar.startOfDay(for: Date())
        messages = archiveService.loadChat(for: currentConversationDay)
        archiveDates = archiveService.listArchivedDates()
        ensureWelcomeMessage()
    }

    func sendUserMessage(_ text: String) {
        archiveTodayChatIfNeeded()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        let userMessage = LeafyMessage(text: trimmed, isUser: true)
        messages.append(userMessage)
        inputText = ""
        persistToday()

        receiveLeafyResponse(for: trimmed)
    }

    func receiveLeafyResponse(for text: String) {
        isThinking = true

        let context = LeafyContext.build(from: appState, recentMessages: messages)
        aiService.generateResponse(for: text, context: context) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isThinking = false
                switch result {
                case .success(let reply):
                    let leafy = LeafyMessage(text: reply, isUser: false)
                    self.messages.append(leafy)
                case .failure:
                    let fallback = LeafyMessage(
                        text: "Ich bekomme gerade keine Verbindung. Versuch es gleich nochmal – ich bleibe hier.",
                        isUser: false
                    )
                    self.messages.append(fallback)
                }
                self.persistToday()
            }
        }
    }

    func archiveTodayChatIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        guard !calendar.isDate(today, inSameDayAs: currentConversationDay) else { return }
        archiveService.saveChat(for: currentConversationDay, messages: messages)
        currentConversationDay = today
        messages = []
        ensureWelcomeMessage()
        archiveDates = archiveService.listArchivedDates()
    }

    func openArchive() {
        showArchive = true
        archiveDates = archiveService.listArchivedDates()
    }

    /// Removes today's messages and persists an empty chat.
    func clearTodaysChat() {
        messages.removeAll()
        archiveService.clearChat(for: currentConversationDay)
        ensureWelcomeMessage()
    }

    func loadArchive(for date: Date) -> [LeafyMessage] {
        archiveService.loadChat(for: date)
    }

    private func ensureWelcomeMessage() {
        guard messages.isEmpty else { return }
        let welcome = LeafyMessage(
            text: makeIntroLine(),
            isUser: false
        )
        messages.append(welcome)
        persistToday()
    }

    private func persistToday() {
        archiveService.saveChat(for: currentConversationDay, messages: messages)
        archiveDates = archiveService.listArchivedDates()
    }

    private func makeIntroLine() -> String {
        let package = LeafyDataBuilder.buildPackage(appState: appState, learningModeEnabled: false)
        if let last = package.summaries.last {
            let pulse = Int(last.pulseAvg.rounded())
            let pulseNote = pulseClassification(pulse)
            let stepsNote: String
            if last.steps < 4000 {
                stepsNote = "Aktivität war eher ruhig."
            } else if last.steps > 9000 {
                stepsNote = "Du warst ziemlich aktiv."
            } else {
                stepsNote = "Deine Aktivität lag im Mittelfeld."
            }
            return "Wie fühlst du dich heute? Dein Ruhepuls lag zuletzt bei \(pulse) bpm, \(pulseNote) \(stepsNote) Wenn es sich anders anfühlt, sag mir kurz, was los ist."
        }
        return "Wie geht’s dir heute? Ich habe nur wenige Daten, erzähl mir kurz, wie du dich fühlst."
    }

    private func pulseClassification(_ pulse: Int) -> String {
        switch pulse {
        case ..<60:
            return "das ist eher niedrig, falls dir schwindlig ist, sag Bescheid."
        case 60...90:
            return "das liegt im üblichen Bereich vieler Erwachsener."
        case 91...100:
            return "etwas erhöht, das kann von Stress oder wenig Schlaf kommen."
        default:
            return "deutlich erhöht; falls du Beschwerden hast, hol dir bitte medizinischen Rat."
        }
    }
}
