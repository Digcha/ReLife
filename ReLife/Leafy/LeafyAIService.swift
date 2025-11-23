import Foundation

enum LeafyAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case network

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Kein API-Key hinterlegt."
        case .invalidResponse:
            return "Leafy hat nicht verstanden, was zurückkam."
        case .network:
            return "Keine Verbindung."
        }
    }
}

final class LeafyAIService {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let knowledgeBase: String = """
    {
      "resting_heart_rate": {
        "range_normal": [60, 90],
        "range_soft_warning": [90, 100],
        "range_strong_warning": ">100",
        "messages": {
          "normal": "liegt im üblichen Bereich vieler gesunder Menschen.",
          "soft_warning": "liegt etwas darüber. Das kann bei Stress, wenig Schlaf oder Erschöpfung vorkommen.",
          "strong_warning": "liegt deutlich darüber. Falls das länger anhält oder du Beschwerden hast, sprich bitte mit einer Ärztin oder einem Arzt."
        }
      },
      "sleep_duration_hours": {
        "range_normal": [7, 9],
        "range_soft_warning": [6, 7],
        "range_strong_warning": "<6",
        "messages": {
          "normal": "liegt in der üblichen Spanne von 7-9 Stunden.",
          "soft_warning": "liegt darunter, das kann Müdigkeit und Stress begünstigen.",
          "strong_warning": "liegt deutlich darunter; bitte achte auf Erholung und hol dir Hilfe, wenn du dich schlecht fühlst."
        }
      },
      "stress_hrv": {
        "hint": "Niedrigere HRV kann auf Belastung hinweisen, höhere HRV eher auf Erholung."
      },
      "steps": {
        "range_normal": [6000, 10000],
        "range_soft_warning": [3000, 6000],
        "range_strong_warning": "<3000",
        "messages": {
          "normal": "liegt in einem typischen Aktivitätsbereich.",
          "soft_warning": "liegt darunter, das kann für Inaktivität sprechen.",
          "strong_warning": "liegt deutlich darunter; kurze Spaziergänge können helfen, wenn es dir möglich ist."
        }
      },
      "safety": "Keine Diagnosen, keine Heilversprechen, keine Selbstverletzungsanleitungen. Bei starken Beschwerden oder Not sofort an Vertrauenspersonen oder medizinische Hilfe verweisen."
    }
    """

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Generates a Leafy reply. Falls back to a local draft if no API key is present.
    func generateResponse(for userMessage: String, context: LeafyContext, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.success(makeLocalDraft(for: userMessage, context: context)))
            return
        }

        let systemPrompt = """
        Du bist Leafy, der persönliche Health- und Life-Assistant in der ReLife-App. Sprich locker, freundlich, empathisch und modern. Du duzt den User. Keine Markdown-Formatierung, keine Listen. Antworte ultrakurz (1-4 Sätze): 1 Satz Analyse basierend auf Daten + Health-Regeln, 1 Satz Reflexion, 1 Frage zum Zustand. Keine Diagnosen oder Heilversprechen. Bei psychischer Belastung: validieren, ruhig machen, auf vertrauenswürdige Hilfe verweisen. Nutze diese interne Wissensbasis (nicht im Internet nachschlagen): \(knowledgeBase)
        """

        let userPrompt = """
        Kontext:
        \(context.healthSummary)
        ---
        Daten:
        \(context.healthPayload)
        ---
        Letzte Nachrichten:
        \(context.recentMessages.map { $0.isUser ? "User: \($0.text)" : "Leafy: \($0.text)" }.joined(separator: "\\n"))
        ---
        Neue Nachricht: \(userMessage)
        Bitte antworte kurz, warm und direkt. Wenn psychische Belastung erkennbar ist, beruhige und schlage kleine Schritte vor (Atmen, kurz rausgehen, jemanden anrufen). Kein Markdown. Beende immer mit einer kurzen Frage.
        """

        var request = URLRequest(url: endpoint, timeoutInterval: 35)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.6,
            "max_tokens": 300
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(.failure(LeafyAIError.network))
                return
            }
            guard
                let data,
                let completionResponse = try? JSONDecoder().decode(LeafyOpenAIResponse.self, from: data),
                let text = completionResponse.choices.first?.message.content
            else {
                completion(.failure(LeafyAIError.invalidResponse))
                return
            }
            completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        task.resume()
    }

    private func makeLocalDraft(for userMessage: String, context: LeafyContext) -> String {
        let lower = userMessage.lowercased()
        let crisisKeywords = ["depress", "panik", "überfordert", "kann nicht mehr", "gar keine motivation", "selbstverletz"]

        if crisisKeywords.contains(where: { lower.contains($0) }) {
            return "Hey, danke, dass du das sagst. Das wirkt gerade viel. Atme kurz tief ein und aus. Wenn es sehr schwer ist, hol dir bitte sofort jemanden dazu, dem du vertraust."
        }

        if context.healthSummary.contains("Keine ReLife-Daten") {
            return "Ich habe gerade nur wenige Daten, aber ich höre dir zu. Was würde dir heute gut tun? Vielleicht ein Glas Wasser, frische Luft oder kurz strecken."
        }

        if lower.contains("müde") {
            return "Klingt nach Müdigkeit. Dein Puls war zuletzt entspannt, vielleicht hilft dir ein kleiner Walk und früher schlafen. Was würdest du gern schaffen, bevor du Pause machst?"
        }

        return "Verstanden. Deine Werte wirken stabil. Was brauchst du als nächsten kleinen Schritt? Ich bin hier, lass uns das gemeinsam angehen."
    }

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            return env
        }
        if let stored = UserDefaults.standard.string(forKey: "LeafyOpenAIKey"), !stored.isEmpty {
            return stored
        }
        return LeafySecrets.openAIKey
    }
}

private struct LeafyOpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
