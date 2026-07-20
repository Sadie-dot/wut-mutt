import UIKit
import Security

// Live breed reveals via the Claude API (see the End Credits AI disclosure).
// The photo goes to Claude, which returns the episode's breed breakdown as
// strict JSON; anything that fails on the way falls back to the canned
// episode upstream — the viewer never sees an error screen.

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
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}

// MARK: - Verdict

enum BreedVerdict {
    case dog(breeds: [Breed], certainty: Int)
    case notADog
    case unavailable
}

enum BreedIdentifierError: Error {
    case missingKey, badImage, badResponse
}

// MARK: - Identifier

struct BreedIdentifier {

    static var hasCredentials: Bool { ClaudeKeyStore.key != nil }

    func identify(_ image: UIImage) async throws -> BreedVerdict {
        guard let key = ClaudeKeyStore.key else { throw BreedIdentifierError.missingKey }
        guard let jpeg = downscaledJPEG(image) else { throw BreedIdentifierError.badImage }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body(imageBase64: jpeg.base64EncodedString()))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw BreedIdentifierError.badResponse
        }

        let message = try JSONDecoder().decode(APIMessage.self, from: data)
        guard let text = message.content.first(where: { $0.type == "text" })?.text else {
            throw BreedIdentifierError.badResponse
        }
        return try parse(text)
    }

    private func body(imageBase64: String) -> [String: Any] {
        let prompt = """
        Analyze this photo. Return JSON: {"isDog": boolean, "certainty": integer 40-99 \
        (how confident the visual breed read is), "breeds": [3 or 4 items, "pct" integers \
        summing to 100, each {"name","pct","tagline","size","energy","drool","floof",\
        "clues":["3 short visual clues seen in THIS photo"],"fact"}]}. "tagline" is a \
        melodramatic soap-opera character description (e.g. "The brooding lead with a \
        hidden past"). "size"/"energy"/"drool"/"floof" are 1-3 word ratings. "fact" is a \
        real, fun, accurate breed fact in 1-2 sentences. If the mix is uncertain, the \
        last breed may be a wildcard named "A Special Guest". If no real live dog is \
        present, return {"isDog": false, "certainty": 99, "breeds": []}.
        """
        return [
            "model": "claude-sonnet-4-5",
            "max_tokens": 2500,
            "system": "You identify dog breeds from photos for Wut Mutt, a playful dog-breed app themed as a 1980s TV soap opera. Respond with STRICT JSON only — no markdown fences, no commentary.",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg", "data": imageBase64]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]
    }

    private func parse(_ text: String) throws -> BreedVerdict {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let wire = try? JSONDecoder().decode(WirePayload.self, from: data) else {
            throw BreedIdentifierError.badResponse
        }
        if wire.isDog == false { return .notADog }
        guard let wireBreeds = wire.breeds, !wireBreeds.isEmpty else {
            throw BreedIdentifierError.badResponse
        }
        let breeds = wireBreeds.prefix(4).enumerated().map { i, b in
            Breed(name: b.name,
                  pct: b.pct,
                  tagline: b.tagline ?? "",
                  size: b.size ?? "—",
                  energy: b.energy ?? "—",
                  drool: b.drool ?? "—",
                  floof: b.floof ?? "—",
                  clues: b.clues ?? [],
                  fact: b.fact ?? "",
                  colorIndex: i)
        }
        let certainty = max(40, min(99, wire.certainty ?? 80))
        return .dog(breeds: Array(breeds), certainty: certainty)
    }

    /// Downscale to ≤640px on the long edge and recompress until the base64
    /// payload stays under ~170KB, per the handoff's image budget.
    private func downscaledJPEG(_ image: UIImage) -> Data? {
        let longEdge = max(image.size.width, image.size.height)
        let scale = min(1, 640 / longEdge)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        var quality: CGFloat = 0.75
        var data = resized.jpegData(compressionQuality: quality)
        while let d = data, d.count > 127_000, quality > 0.3 {
            quality -= 0.15
            data = resized.jpegData(compressionQuality: quality)
        }
        return data
    }
}

// MARK: - Wire types

private struct APIMessage: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
}

private struct WirePayload: Decodable {
    let isDog: Bool
    let certainty: Int?
    let breeds: [WireBreed]?
}

private struct WireBreed: Decodable {
    let name: String
    let pct: Int
    let tagline: String?
    let size: String?
    let energy: String?
    let drool: String?
    let floof: String?
    let clues: [String]?
    let fact: String?
}
