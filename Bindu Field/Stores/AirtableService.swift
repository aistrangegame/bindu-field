import Foundation

enum AirtableError: LocalizedError {
    case noToken
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noToken:             return "No Airtable token set. Update Secrets.swift."
        case .networkError(let e): return "Network: \(e.localizedDescription)"
        case .invalidResponse:     return "Unexpected response from Airtable."
        case .apiError(let msg):   return msg
        case .parseError:          return "Couldn't parse Airtable response."
        }
    }
}

@MainActor
final class AirtableService {
    static let shared = AirtableService()

    private let baseURL = "https://api.airtable.com/v0/app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6"
    private let pageSize = 100

    private init() {}

    func fetchTracks() async throws -> [Track] {
        let token = Secrets.airtableToken
        guard isPlausibleToken(token) else {
            throw AirtableError.noToken
        }

        // B16: walk Airtable's `offset` pagination until all records are
        // collected. Today's catalog is 22 records but this is what you
        // do if you ever cross 100.
        var allRecords: [AirtableRecord] = []
        var offset: String? = nil

        repeat {
            var components = URLComponents(string: baseURL)!
            var items = [URLQueryItem(name: "pageSize", value: "\(pageSize)")]
            if let offset { items.append(URLQueryItem(name: "offset", value: offset)) }
            components.queryItems = items
            guard let url = components.url else { throw AirtableError.invalidResponse }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw AirtableError.networkError(error)
            }

            guard let http = response as? HTTPURLResponse else {
                throw AirtableError.invalidResponse
            }

            if http.statusCode != 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? [String: Any],
                   let msg = err["message"] as? String {
                    throw AirtableError.apiError(msg)
                }
                throw AirtableError.apiError("HTTP \(http.statusCode)")
            }

            // O6: hop decoding to a detached task so JSON parsing doesn't
            // pin the main actor. Catalog is small today (~22 records) but
            // the cost grows linearly; the detach is free insurance.
            let decoded: AirtableResponse
            do {
                decoded = try await Task.detached(priority: .userInitiated) {
                    try JSONDecoder().decode(AirtableResponse.self, from: data)
                }.value
            } catch {
                throw AirtableError.parseError
            }

            allRecords.append(contentsOf: decoded.records)
            offset = decoded.offset
        } while offset != nil

        let tracks: [Track] = allRecords.compactMap { record in
            let f = record.fields
            guard let id = f.trackID,
                  let verb = f.verb,
                  let song = f.songTitle,
                  let artist = f.artist,
                  let element = f.element,
                  let stateRaw = f.brainwaveState,
                  let state = BrainwaveState(rawValue: stateRaw),
                  let typeRaw = f.trackType,
                  let type = TrackType(rawValue: typeRaw),
                  let audioURL = f.audioURL,
                  let seed = f.seedPhrase,
                  let carrierHz = f.carrierHz,
                  let beatHz = f.beatHz
            else { return nil }

            let chakra: ChakraName? = f.chakra.flatMap { ChakraName(rawValue: $0) }

            return Track(
                id: id,
                verb: verb,
                song: song,
                artist: artist,
                element: element,
                state: state,
                chakra: chakra,
                type: type,
                audioURL: audioURL,
                youtubeID: f.youtubeID,
                seed: seed,
                carrierHz: carrierHz,
                beatHz: beatHz,
                recognitionStatement: f.recognitionStatement,
                lyricalWordsReading: f.lyricalWordsReading ?? "",
                frequencyReading: f.frequencyReading ?? "",
                videoPulseReading: f.videoPulseReading ?? "",
                lalitasPerspective: f.lalitasPerspective
            )
        }

        return tracks.sorted { $0.id < $1.id }
    }

    // MARK: - Breath sessions
    //
    // Track Type = "breath" records (IDs 101–111) live in the same Airtable
    // table but carry a leaner field set than music tracks: no Artist /
    // Element / Audio URL / YouTube ID. `fetchTracks()` skips them because
    // its decoder requires those fields. This pass walks the same paginated
    // endpoint and decodes only the breath-session fields.
    //
    // The carrier+beat+state+seed+readings come from Airtable. The breath
    // rhythm (inhale/hold/exhale), intention assignment, safety tier, and
    // special cue live in `BreathProtocolMetadata` keyed by Track ID — they
    // aren't currently in the Airtable schema.

    func fetchBreathSessions() async throws -> [BreathSession] {
        let token = Secrets.airtableToken
        guard isPlausibleToken(token) else {
            throw AirtableError.noToken
        }

        var allRecords: [AirtableBreathRecord] = []
        var offset: String? = nil

        repeat {
            var components = URLComponents(string: baseURL)!
            var items = [URLQueryItem(name: "pageSize", value: "\(pageSize)")]
            if let offset { items.append(URLQueryItem(name: "offset", value: offset)) }
            components.queryItems = items
            guard let url = components.url else { throw AirtableError.invalidResponse }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw AirtableError.networkError(error)
            }

            guard let http = response as? HTTPURLResponse else {
                throw AirtableError.invalidResponse
            }

            if http.statusCode != 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err = json["error"] as? [String: Any],
                   let msg = err["message"] as? String {
                    throw AirtableError.apiError(msg)
                }
                throw AirtableError.apiError("HTTP \(http.statusCode)")
            }

            let decoded: AirtableBreathResponse
            do {
                decoded = try await Task.detached(priority: .userInitiated) {
                    try JSONDecoder().decode(AirtableBreathResponse.self, from: data)
                }.value
            } catch {
                throw AirtableError.parseError
            }

            allRecords.append(contentsOf: decoded.records)
            offset = decoded.offset
        } while offset != nil

        let sessions: [BreathSession] = allRecords.compactMap { record in
            let f = record.fields
            guard f.trackType == "breath",
                  let id = f.trackID,
                  let name = f.songTitle,
                  let verb = f.verb,
                  let state = f.brainwaveState,
                  let carrier = f.carrierHz,
                  let beat = f.beatHz,
                  let seed = f.seedPhrase
            else { return nil }
            return BreathSession(
                id: id,
                name: name,
                verb: verb,
                stateKey: state,
                carrierHz: Float(carrier),
                beatHz: Float(beat),
                seed: seed,
                recognitionStatement: f.recognitionStatement,
                lyricalWordsReading: f.lyricalWordsReading ?? "",
                frequencyReading: f.frequencyReading ?? "",
                lalitasPerspective: f.lalitasPerspective,
                phaseLabels: f.phaseLabels
            )
        }

        return sessions.sorted { $0.id < $1.id }
    }

    // MARK: - Helpers

    /// B17: reject obvious placeholders and shape-fail values. A real
    /// Airtable PAT begins with `pat`, has a `.` separator, and runs
    /// 60+ characters total.
    private func isPlausibleToken(_ token: String) -> Bool {
        guard !token.isEmpty,
              token != "PASTE_REAL_TOKEN_HERE",
              token != "YOUR_AIRTABLE_PAT_HERE"
        else { return false }
        guard token.hasPrefix("pat"),
              token.contains("."),
              token.count >= 60
        else { return false }
        return true
    }

}

// MARK: - Airtable JSON shape
//
// `nonisolated` lets these types participate in decoding from a detached
// task (O6) under Swift's MainActor-by-default project setting. Without
// it, the synthesized `Decodable` conformance is MainActor-isolated and
// Swift 6 rejects the off-actor `JSONDecoder().decode` call.

private nonisolated struct AirtableResponse: Decodable {
    let records: [AirtableRecord]
    let offset: String?
}

private nonisolated struct AirtableRecord: Decodable {
    let fields: AirtableFields
}

// MARK: - Breath session JSON shape
//
// Like `AirtableFields` but only requires the breath-relevant fields and
// makes everything optional so a partially-populated record still
// decodes. `phaseLabels` is the new Airtable column the design's PHASES
// reading tab consumes (rendered as-is when populated).

private nonisolated struct AirtableBreathResponse: Decodable {
    let records: [AirtableBreathRecord]
    let offset: String?
}

private nonisolated struct AirtableBreathRecord: Decodable {
    let fields: AirtableBreathFields
}

private nonisolated struct AirtableBreathFields: Decodable {
    let trackID: Int?
    let songTitle: String?
    let verb: String?
    let trackType: String?
    let brainwaveState: String?
    let carrierHz: Double?
    let beatHz: Double?
    let seedPhrase: String?
    let recognitionStatement: String?
    let lyricalWordsReading: String?
    let frequencyReading: String?
    let lalitasPerspective: String?
    let phaseLabels: String?

    enum CodingKeys: String, CodingKey {
        case trackID = "Track ID"
        case songTitle = "Song Title"
        case verb = "Verb"
        case trackType = "Track Type"
        case brainwaveState = "Brainwave State"
        case carrierHz = "Carrier Hz"
        case beatHz = "Beat Hz"
        case seedPhrase = "Seed Phrase"
        case recognitionStatement = "Recognition Statement"
        case lyricalWordsReading = "Lyrical Words Reading"
        case frequencyReading = "Frequency Reading"
        case lalitasPerspective = "Lalita's Perspective"
        case phaseLabels = "Phase Labels"
    }
}

private nonisolated struct AirtableFields: Decodable {
    let trackID: Int?
    let verb: String?
    let songTitle: String?
    let artist: String?
    let trackType: String?
    let element: String?
    let brainwaveState: String?
    let chakra: String?
    let audioURL: String?
    let youtubeID: String?
    let carrierHz: Double?
    let beatHz: Double?
    let seedPhrase: String?
    let recognitionStatement: String?
    let lyricalWordsReading: String?
    let frequencyReading: String?
    let videoPulseReading: String?
    let lalitasPerspective: String?

    enum CodingKeys: String, CodingKey {
        case trackID = "Track ID"
        case verb = "Verb"
        case songTitle = "Song Title"
        case artist = "Artist"
        case trackType = "Track Type"
        case element = "Element"
        case brainwaveState = "Brainwave State"
        case chakra = "Chakra"
        case audioURL = "Audio URL"
        case youtubeID = "YouTube ID"
        case carrierHz = "Carrier Hz"
        case beatHz = "Beat Hz"
        case seedPhrase = "Seed Phrase"
        case recognitionStatement = "Recognition Statement"
        case lyricalWordsReading = "Lyrical Words Reading"
        case frequencyReading = "Frequency Reading"
        case videoPulseReading = "Video Pulse Reading"
        case lalitasPerspective = "Lalita's Perspective"
    }
}
