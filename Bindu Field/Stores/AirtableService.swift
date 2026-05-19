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

    private let endpoint = URL(string: "https://api.airtable.com/v0/app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6?pageSize=100")!

    private init() {}

    func fetchTracks() async throws -> [Track] {
        let token = Secrets.airtableToken
        guard !token.isEmpty, token != "PASTE_REAL_TOKEN_HERE", token != "YOUR_AIRTABLE_PAT_HERE" else {
            throw AirtableError.noToken
        }

        var request = URLRequest(url: endpoint)
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

        let decoded: AirtableResponse
        do {
            decoded = try JSONDecoder().decode(AirtableResponse.self, from: data)
        } catch {
            throw AirtableError.parseError
        }

        let tracks: [Track] = decoded.records.compactMap { record in
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
                beatHz: beatHz
            )
        }

        return tracks.sorted { $0.id < $1.id }
    }
}

// MARK: - Airtable JSON shape

private struct AirtableResponse: Decodable {
    let records: [AirtableRecord]
}

private struct AirtableRecord: Decodable {
    let fields: AirtableFields
}

private struct AirtableFields: Decodable {
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
    }
}
