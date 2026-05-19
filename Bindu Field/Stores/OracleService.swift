import Foundation

enum OracleError: LocalizedError {
    case noAPIKey
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:        return "No API key set. Add one in Settings."
        case .networkError(let e): return "Network: \(e.localizedDescription)"
        case .invalidResponse: return "Unexpected response from Oracle."
        case .apiError(let msg):   return msg
        case .parseError:      return "Couldn't understand the Oracle's response."
        }
    }
}

struct OracleResponse {
    let trackID: String
    let why: String
}

@MainActor
final class OracleService {
    static let shared = OracleService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-haiku-4-5-20251001"

    private init() {}

    func ask(_ stateText: String, allTracks: [Track]) async throws -> OracleResponse {
        guard let key = KeychainHelper.load(), !key.isEmpty else {
            throw OracleError.noAPIKey
        }

        let catalogLines = allTracks.map { t in
            "id=\(t.id) | verb=\(t.verb) | \(t.song) — \(t.artist) | state=\(t.state.rawValue) | element=\(t.element) | seed=\(t.seed)"
        }.joined(separator: "\n")

        let systemPrompt = """
        You are the Oracle of Bindu Field, a consciousness instrument. The user describes their current state, mood, or what they need. Recommend ONE track from the catalog below that meets them where they are.

        Catalog:
        \(catalogLines)

        Respond with ONLY valid JSON in this exact format, no markdown, no preamble:
        {"track_id": "<exact id from catalog>", "why": "<2-3 sentences of intuitive reading addressed directly to the user. Speak as the Oracle. Reference what they shared. Be specific to the track you chose. Sparse, serif, italic in spirit. No emojis.>"}
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 500,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": stateText]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OracleError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OracleError.invalidResponse
        }

        if http.statusCode != 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw OracleError.apiError(msg)
            }
            throw OracleError.apiError("HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstText = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String else {
            throw OracleError.invalidResponse
        }

        // Inner JSON
        let cleaned = firstText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let innerData = cleaned.data(using: .utf8),
              let innerJSON = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any],
              let trackID = innerJSON["track_id"] as? String,
              let why = innerJSON["why"] as? String else {
            throw OracleError.parseError
        }

        return OracleResponse(trackID: trackID, why: why)
    }
}
