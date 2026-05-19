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

            // Decode on the main actor — catalog is small (22 records),
            // and the project's actor-isolation default makes hopping
            // off main require extra plumbing for no measurable win.
            let decoded: AirtableResponse
            do {
                decoded = try JSONDecoder().decode(AirtableResponse.self, from: data)
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
                beatHz: beatHz
            )
        }

        return tracks.sorted { $0.id < $1.id }
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

private struct AirtableResponse: Decodable {
    let records: [AirtableRecord]
    let offset: String?
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
