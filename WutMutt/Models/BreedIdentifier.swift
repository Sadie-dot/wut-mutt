import UIKit
import Security

// Live breed reveals via the Claude API (see the End Credits AI disclosure).
// The photo goes to Claude — either through the developer-hosted Worker proxy
// (which holds the API key) or, when no proxy is configured, directly with the
// user's own key.
//
// Nothing here ever invents a breed reading. When the studio can't be reached,
// the caller gets an `.offAir` verdict describing what actually happened.

// MARK: - API key storage (Keychain)

enum ClaudeKeyStore {
    private static let service = "com.wutmutt.claude-api-key"

    static var key: String? {
        #if DEBUG
        // Dev hook: `SIMCTL_CHILD_WM_CLAUDE_KEY=… simctl launch` for testing
        // without touching the Keychain.
        if let env = ProcessInfo.processInfo.environment["WM_CLAUDE_KEY"], !env.isEmpty {
            return env
        }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8), !str.isEmpty else { return nil }
        return str
    }

    static func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    /// Drops a key the API has rejected, so the next reveal asks for a new one
    /// instead of failing the same way forever.
    static func clear() {
        SecItemDelete(base as CFDictionary)
    }

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    }
}

// MARK: - Verdict

/// What the photo showed, separate from the breed read.
///
/// The analyzing screen's closing question is chosen against the animal in
/// frame rather than against its breeds' typical builds, so a Great Dane puppy
/// reads small and gets asked whether it's a wolfhound. Deriving this from the
/// breed names would get that backwards.
struct DogLook {
    enum Size: String { case large, small, unclear }
    enum Coat: String { case flat, fluffy }

    let size: Size
    let coat: Coat
}

/// What the studio came back with.
enum BreedVerdict {
    /// `look` is nil when the studio didn't say — a proxy deployed before these
    /// fields existed. The caller falls back to its original closing question
    /// rather than guessing.
    case dog(breeds: [Breed], certainty: Int, look: DogLook?)
    case notADog
    /// Couldn't get a real reading. Carries what to tell the viewer — the app
    /// never fills this gap with a fabricated episode.
    case offAir(OffAir)
}

/// The copy for an off-air card, in the show's voice.
struct OffAir: Equatable {
    /// What the card invites, which is the real taxonomy: replay the same
    /// take, walk back to the set, or shoot a fresh one because the photo
    /// itself is what failed.
    enum Action { case retry, home, newShot }

    /// What fills the card's disc — each card gets its own set dressing.
    /// `bare` drops the disc entirely: the wrap card's statement is a dark,
    /// emptied set, and furniture would argue with it. `cutTake` shows the
    /// offending photo itself, grayscaled and grease-penciled like a take
    /// marked for the cutting-room floor.
    enum Centerpiece { case testPattern, snow, cutTake, bare }

    let headline: String
    let kicker: String
    let message: String
    let action: Action
    var centerpiece: Centerpiece = .testPattern
    /// The one word of dog signing off the bottom of the card.
    var signOff: String = "MLEM"
}

enum BreedIdentifierError: LocalizedError {
    case notConfigured
    case badImage
    case api(type: String?, message: String)
    case refused

    var errorDescription: String? {
        switch self {
        case .notConfigured:  return "No way to reach Claude is configured."
        case .badImage:       return "Couldn't read that photo."
        case .api(_, let m):  return m
        case .refused:        return "Claude declined to analyze this photo."
        }
    }
}

// MARK: - Backend selection

/// How the app reaches Claude. When the Info.plist carries a proxy URL the app
/// routes through the developer-hosted Worker (which holds the API key) and no
/// per-user key is needed. Otherwise each user supplies their own key.
enum IdentifyBackend {
    /// Developer-hosted proxy: the app ships no key, users just point and shoot.
    case proxy(url: URL, appToken: String?)
    /// Bring-your-own-key: the user's key is read from the Keychain.
    case directKey(String)

    static func resolve() -> IdentifyBackend? {
        if let (url, token) = Self.proxyConfig {
            return .proxy(url: url, appToken: token)
        }
        if let key = ClaudeKeyStore.key {
            return .directKey(key)
        }
        return nil
    }

    private static var proxyConfig: (URL, String?)? {
        let info = Bundle.main.infoDictionary
        guard let raw = (info?["WMIdentifyProxyURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, let url = URL(string: raw) else { return nil }
        let token = (info?["WMIdentifyAppToken"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (url, (token?.isEmpty == false) ? token : nil)
    }

    /// Whether the "Connect Claude" key prompt should ever appear. A configured
    /// proxy never prompts.
    static var usesProxy: Bool { proxyConfig != nil }
}

// MARK: - Identifier

struct BreedIdentifier {

    /// Whether a reveal can even be attempted — a proxy is configured, or the
    /// user has stored a key.
    static var hasCredentials: Bool { IdentifyBackend.resolve() != nil }

    func identify(_ image: UIImage) async throws -> BreedVerdict {
        guard let backend = IdentifyBackend.resolve() else {
            throw BreedIdentifierError.notConfigured
        }
        guard let jpeg = downscaledJPEG(image) else { throw BreedIdentifierError.badImage }
        let imageBase64 = jpeg.base64EncodedString()

        let request: URLRequest
        switch backend {
        case .proxy(let url, let appToken):
            request = proxyRequest(url: url, appToken: appToken, imageBase64: imageBase64)
        case .directKey(let key):
            request = directRequest(apiKey: key, imageBase64: imageBase64)
        }

        return try await send(request, backend: backend)
    }

    // MARK: Requests

    private func proxyRequest(url: URL, appToken: String?, imageBase64: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let appToken { request.setValue(appToken, forHTTPHeaderField: "x-wm-app-token") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["image": imageBase64])
        return request
    }

    /// Talks to the Anthropic API directly with the user's own key. Mirrors the
    /// proxy's model, prompt, and schema — keep the two in sync.
    private func directRequest(apiKey: String, imageBase64: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "claude-sonnet-5",
            "max_tokens": 2500,
            "system": "You identify dog breeds from photos for Wut Mutt, a playful dog-breed app themed as a 1980s TV soap opera.",
            // Thinking is on by default and shares the max_tokens budget with
            // the response; a schema-constrained photo read doesn't need it.
            "thinking": ["type": "disabled"],
            "output_config": ["format": ["type": "json_schema", "schema": Self.verdictSchema]],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg", "data": imageBase64]],
                    ["type": "text", "text": Self.prompt]
                ]
            ]]
        ])
        return request
    }

    // MARK: Pipeline

    private func send(_ request: URLRequest, backend: IdentifyBackend) async throws -> BreedVerdict {
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw BreedIdentifierError.api(
                type: envelope?.error.type ?? Self.errorType(for: http.statusCode, backend: backend),
                message: envelope?.error.message ?? Self.genericFailure(status: http.statusCode))
        }

        let message = try JSONDecoder().decode(APIMessage.self, from: data)
        if message.stopReason == "refusal" { throw BreedIdentifierError.refused }
        guard let text = message.content.first(where: { $0.type == "text" })?.text,
              let payload = text.data(using: .utf8) else {
            throw BreedIdentifierError.api(type: nil, message: "Empty response from Claude.")
        }
        return try parse(payload)
    }

    /// Shown when the failure carried no message of its own. Viewers get the
    /// show's voice; the status code is for whoever is holding the debugger.
    private static func genericFailure(status: Int) -> String {
        #if DEBUG
        return "Something came between us and the studio.\n(HTTP \(status))"
        #else
        return "Something came between us and the studio."
        #endif
    }

    /// When the response body isn't our envelope — a direct-to-Anthropic call,
    /// or an edge error — classify by status so the app still says the right
    /// thing. A rejected key on the BYOK path is the one worth naming.
    private static func errorType(for status: Int, backend: IdentifyBackend) -> String {
        switch (status, backend) {
        case (401, .directKey), (403, .directKey): return "invalid_key"
        case (429, _):                             return "rate_limit"
        case (500...599, _):                       return "upstream_unavailable"
        default:                                   return "upstream_config"
        }
    }

    private func parse(_ data: Data) throws -> BreedVerdict {
        guard let wire = try? JSONDecoder().decode(WirePayload.self, from: data) else {
            throw BreedIdentifierError.api(type: nil, message: "Couldn't read the studio's answer.")
        }
        guard wire.isDog, !wire.breeds.isEmpty else { return .notADog }
        let breeds = wire.breeds.prefix(4).enumerated().map { i, b in
            Breed(name: b.name, pct: b.pct, tagline: b.tagline,
                  size: b.size, energy: b.energy, drool: b.drool, floof: b.floof,
                  clues: b.clues, fact: b.fact, colorIndex: i)
        }
        // Size is what decides the question, so no size means no look at all —
        // a missing coat alone falls back to flat rather than losing the read.
        let look = wire.dogSize.flatMap(DogLook.Size.init(rawValue:)).map {
            DogLook(size: $0, coat: wire.dogCoat.flatMap(DogLook.Coat.init(rawValue:)) ?? .flat)
        }
        return .dog(breeds: Array(breeds),
                    certainty: max(40, min(99, wire.certainty)),
                    look: look)
    }

    // MARK: Off-air copy

    /// Turns a failure into something honest to put on screen. The one thing
    /// it never does is pretend the reveal succeeded.
    ///
    /// Four cards, bucketed by what the viewer can actually do: fix the
    /// connection, come back tomorrow, wait out the studio's trouble, or
    /// shoot a fresh take. Every server-side failure that isn't the daily
    /// cap — outage, misconfiguration, a rejected key — lands on the same
    /// stand-by card, because from the couch they're indistinguishable and
    /// the remedy is identical.
    static func offAir(for error: Error) -> OffAir {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .cannotConnectToHost, .cannotFindHost, .timedOut:
                return OffAir(headline: "We've lost the feed.",
                              kicker: "TECHNICAL DIFFICULTIES",
                              message: "Please check the connection\nin your secret lair.",
                              action: .retry,
                              centerpiece: .snow)
            default:
                break
            }
        }

        switch error {
        case BreedIdentifierError.api("rate_limit", _):
            // The one by-design ending. The kicker carries the literal fact —
            // the rest of the card is allowed its metaphor because that line
            // does the explaining. (The proxy still sends a message with its
            // 429; the app owns this copy now and doesn't display it.)
            return OffAir(headline: "It's intermission time.",
                          kicker: "YOU'VE USED ALL OF TODAY'S REVEALS",
                          message: "Please come back tomorrow\nafter ice cream with your secret family.",
                          action: .home,
                          centerpiece: .bare,
                          signOff: "BOOF")

        case BreedIdentifierError.refused, BreedIdentifierError.badImage:
            // One card for both "the photo is the problem" failures — a
            // refusal and an unreadable capture invite the same remedy, and
            // the message names it plainly.
            return OffAir(headline: "Reshoot!",
                          kicker: "THAT PHOTO ISN'T WORKING",
                          message: "Please try a new photo when the aliens\nfinally get bored of you.",
                          action: .newShot,
                          centerpiece: .cutTake,
                          signOff: "BORK")

        default:
            return OffAir(headline: "Please stand by.",
                          kicker: "SOMETHING WENT WRONG",
                          message: "Say goodbye to your evil twin,\nand give it another go.",
                          action: .retry,
                          signOff: "SNARF")
        }
    }

    // MARK: Prompt + schema (mirrors proxy/src/index.js)

    private static let prompt = """
    Analyze this photo for Wut Mutt, a playful dog-breed app themed as a 1980s TV soap opera.

    Rules:
    - If no real live dog is present, set isDog false, certainty 99, breeds to an empty array, dogSize "unclear" and dogCoat "flat".
    - Otherwise give 3 or 4 breeds whose "pct" values are integers summing to exactly 100, most confident first.
    - "certainty" is 40-99: how confident the visual breed read is.
    - "dogSize" describes THIS animal, not its breeds' typical build: "large" or "small" only when it plainly reads that way, otherwise "unclear". A large-breed puppy is "small".
    - "dogCoat" is "flat" or "fluffy" for the coat actually visible in the photo.
    - "tagline" is a melodramatic soap-opera character description, e.g. "The brooding lead with a hidden past".
    - "size"/"energy"/"drool"/"floof" are 1-3 word ratings.
    - "clues" are 3 short visual details seen in THIS photo.
    - "fact" is a real, accurate, fun breed fact in 1-2 sentences. Never invent facts.
    - If the mix is uncertain, the last breed may be a wildcard named "Guest Star".
    """

    private static var verdictSchema: [String: Any] {
        let str: [String: Any] = ["type": "string"]
        let breed: [String: Any] = [
            "type": "object",
            "properties": [
                "name": str, "pct": ["type": "integer"], "tagline": str,
                "size": str, "energy": str, "drool": str, "floof": str,
                "clues": ["type": "array", "items": str], "fact": str
            ],
            "required": ["name", "pct", "tagline", "size", "energy", "drool", "floof", "clues", "fact"],
            "additionalProperties": false
        ]
        return [
            "type": "object",
            "properties": [
                "isDog": ["type": "boolean"],
                "certainty": ["type": "integer"],
                "dogSize": ["type": "string", "enum": ["large", "small", "unclear"]],
                "dogCoat": ["type": "string", "enum": ["flat", "fluffy"]],
                "breeds": ["type": "array", "items": breed]
            ],
            "required": ["isDog", "certainty", "dogSize", "dogCoat", "breeds"],
            "additionalProperties": false
        ]
    }

    /// Downscale to ≤1024px on the long edge and recompress until the base64
    /// payload stays under ~530KB.
    ///
    /// The handoff budgeted 640px / ~170KB, but that was the prototype working
    /// around browser base64 limits. Breed calls live in coat texture, ear set,
    /// and muzzle shape — the detail 640px throws away — and the model accepts
    /// far more, so the extra resolution buys accuracy for a modest token cost.
    /// The byte ceiling rises with it; otherwise the quality loop would claw
    /// back exactly the detail the larger image was meant to carry.
    private func downscaledJPEG(_ image: UIImage) -> Data? {
        let longEdge = max(image.size.width, image.size.height)
        let scale = min(1, 1024 / longEdge)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        var quality: CGFloat = 0.8
        var data = resized.jpegData(compressionQuality: quality)
        while let d = data, d.count > 400_000, quality > 0.5 {
            quality -= 0.1
            data = resized.jpegData(compressionQuality: quality)
        }
        return data
    }
}

// MARK: - Wire types

private struct APIErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let type: String?
        let message: String
    }
    let error: Payload
}

private struct APIMessage: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}

/// The schema guarantees these fields, so they're non-optional by contract
/// rather than by hope.
private struct WirePayload: Decodable {
    let isDog: Bool
    let certainty: Int
    let breeds: [WireBreed]
    /// Optional against the same schema that requires them, deliberately: a
    /// proxy deployed before these fields existed omits them, and a reveal that
    /// still works is worth more than a stricter contract. Nothing to
    /// coordinate — an updated Worker's extra keys are ignored by older builds
    /// in the other direction.
    let dogSize: String?
    let dogCoat: String?
}

private struct WireBreed: Decodable {
    let name: String
    let pct: Int
    let tagline: String
    let size: String
    let energy: String
    let drool: String
    let floof: String
    let clues: [String]
    let fact: String
}
