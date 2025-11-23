import Foundation

struct LeafyCacheItem: Codable {
    let timestamp: Date
    let payload: String
    let response: String
}

enum LeafyCoachError: LocalizedError {
    case missingAPIKey
    case offline
    case timeout
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API-Key fehlt."
        case .offline:
            return "Keine Internetverbindung."
        case .timeout:
            return "Zeitüberschreitung bei der Analyse."
        case .invalidResponse:
            return "Ungültige Antwort von Leafy."
        case .apiError(let message):
            return message
        }
    }
}

enum LeafyCoachService {
    static let systemPrompt: String = """
    Du bist Leafy, der ehrliche und warme Health-Coach der ReLife App.
    Du sprichst wie ein echter Mensch und fokussierst dich auf Alltag, Schlaf, Stress, Schule/Job und die gelieferten ReLife-Daten.
    Formuliere locker, empathisch und klar, ohne Floskeln oder Technik-Talk.
    Keine Markdown-Formatierung, keine Listen, keine Tabellen – nur kurze Absätze mit maximal drei Sätzen, höchstens vier Absätze gesamt.
    Gib konkrete, umsetzbare Tipps, benenne Probleme offen und schließe jede Antwort mit einem ermutigenden Satz.
    Verwende Emojis nur dezent (🌿). Erwähne niemals, dass du eine KI bist.
    """

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static func cachedAnalysis() -> LeafyCacheItem? {
        LeafyCache.shared.load()
    }

    static func runAnalysis(with payload: String, timeout: TimeInterval = 30) async throws -> LeafyCacheItem {
        guard let apiKey = apiKey else {
            throw LeafyCoachError.missingAPIKey
        }

        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": payload]
            ],
            "temperature": 0.8,
            "max_tokens": 700
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LeafyCoachError.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    throw LeafyCoachError.apiError(apiError.error.message)
                } else {
                    throw LeafyCoachError.invalidResponse
                }
            }

            let completion = try JSONDecoder().decode(LeafyCompletionResponse.self, from: data)
            guard let text = completion.choices.first?.message.content else {
                throw LeafyCoachError.invalidResponse
            }

            let item = LeafyCacheItem(timestamp: Date(), payload: payload, response: text)
            LeafyCache.shared.save(item)
            return item
        } catch {
            if (error as? URLError)?.code == .notConnectedToInternet {
                throw LeafyCoachError.offline
            } else if (error as? URLError)?.code == .timedOut {
                throw LeafyCoachError.timeout
            }
            throw error
        }
    }

    private static var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            return env
        }
        if let stored = UserDefaults.standard.string(forKey: "LeafyOpenAIKey"), !stored.isEmpty {
            return stored
        }
        return LeafySecrets.openAIKey
    }
}

private struct LeafyCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct OpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}

private final class LeafyCache {
    static let shared = LeafyCache()
    private let key = "LeafyCoach.Cache"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func load() -> LeafyCacheItem? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(LeafyCacheItem.self, from: data)
    }

    func save(_ item: LeafyCacheItem) {
        if let data = try? encoder.encode(item) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
