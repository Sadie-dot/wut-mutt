import UIKit

// Live breed reveals via the Claude API (see the End Credits AI disclosure).
// The photo goes to Claude through the developer-hosted Worker proxy, which
// holds the API key so the app never ships or stores one. There is no
// bring-your-own-key path — this app will never ask a viewer for an API key.
//
// Nothing here ever invents a breed reading. When the studio can't be reached,
// the caller gets an `.offAir` verdict describing what actually happened.

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

/// How the app reaches Claude: the developer-hosted Worker proxy named in the
/// Info.plist. `resolve()` returning nil means a build without proxy config —
/// a developer mistake, not a state a viewer can cause or fix.
enum IdentifyBackend {
    /// Developer-hosted proxy: the app ships no key, users just point and shoot.
    case proxy(url: URL, appToken: String?)

    static func resolve() -> IdentifyBackend? {
        let info = Bundle.main.infoDictionary
        guard let raw = (info?["WMIdentifyProxyURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, let url = URL(string: raw) else { return nil }
        let token = (info?["WMIdentifyAppToken"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .proxy(url: url, appToken: (token?.isEmpty == false) ? token : nil)
    }
}

// MARK: - Identifier

struct BreedIdentifier {

    /// Whether a reveal can even be attempted — a proxy is configured.
    static var hasCredentials: Bool { IdentifyBackend.resolve() != nil }

    func identify(_ image: UIImage) async throws -> BreedVerdict {
        guard case .proxy(let url, let appToken)? = IdentifyBackend.resolve() else {
            throw BreedIdentifierError.notConfigured
        }
        guard let jpeg = downscaledJPEG(image) else { throw BreedIdentifierError.badImage }
        let request = proxyRequest(url: url, appToken: appToken,
                                   imageBase64: jpeg.base64EncodedString())
        return try await send(request)
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

    // MARK: Pipeline

    private func send(_ request: URLRequest) async throws -> BreedVerdict {
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw BreedIdentifierError.api(
                type: envelope?.error.type ?? Self.errorType(for: http.statusCode),
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

    /// When the response body isn't the proxy's envelope — an edge error page —
    /// classify by status so the app still says the right thing. A bare 429 can
    /// only be the daily cap: the Worker reports upstream throttling as 503.
    private static func errorType(for status: Int) -> String {
        switch status {
        case 429:        return "rate_limit"
        case 500...599:  return "upstream_unavailable"
        default:         return "upstream_config"
        }
    }

    /// Claude sometimes bills baroque names — "Poodle (Standard)", "Sheepdog
    /// Mix (Old English Sheepdog type)" — which wrap the results row to three
    /// lines and truncate the share card's one-line billing. The prompt now
    /// forbids them at the source; this normalizes whatever arrives anyway,
    /// once, where Breed is born — every surface and the photo matcher
    /// inherit the plain name.
    private static func plainName(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "",
                                 options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func parse(_ data: Data) throws -> BreedVerdict {
        guard let wire = try? JSONDecoder().decode(WirePayload.self, from: data) else {
            throw BreedIdentifierError.api(type: nil, message: "Couldn't read the studio's answer.")
        }
        guard wire.isDog, !wire.breeds.isEmpty else { return .notADog }
        // Claude has always returned a clean cast — distinct names, percentages
        // summing to 100 — but the schema enforces neither, and both failures
        // would render as quiet nonsense: twin rows for one breed, bars that
        // undercut their own caption's arithmetic. Folded and rescaled once
        // here, so every surface downstream can trust the invariant.
        var seen: [String: Int] = [:]           // lowercased plain name → index
        var merged: [(breed: WireBreed, pct: Int)] = []
        for b in wire.breeds {
            let key = Self.plainName(b.name).lowercased()
            let pct = max(0, b.pct)
            if let i = seen[key] { merged[i].pct += pct }
            else { seen[key] = merged.count; merged.append((b, pct)) }
        }
        merged = Array(merged.prefix(4))
        var pcts = merged.map(\.pct)
        let sum = pcts.reduce(0, +)
        if sum == 0 {
            pcts[0] = 100                       // non-empty per the guard above
        } else if sum != 100 {
            pcts = pcts.map { $0 * 100 / sum }  // floor-scaled…
            pcts[0] += 100 - pcts.reduce(0, +)  // …drift goes to the lead
        }
        let breeds = merged.enumerated().map { i, m in
            Breed(name: Self.plainName(m.breed.name), pct: pcts[i],
                  tagline: m.breed.tagline, size: m.breed.size,
                  energy: m.breed.energy, drool: m.breed.drool,
                  floof: m.breed.floof, clues: m.breed.clues,
                  fact: m.breed.fact, colorIndex: i)
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
