import UIKit

/// PLACEHOLDER breed-headshot source, per the handoff: fetches a random photo
/// from the public dog.ceo API by fuzzy-matching Claude's breed name against
/// its breed list. Unmatched names (like "A Special Guest") return nil and the
/// detail screen falls back to the 2×2 trait grid. Production should ship one
/// curated, face-forward photo per breed instead.
actor DogImageFetcher {
    static let shared = DogImageFetcher()

    private var breedList: [String: [String]]?
    private var cache: [String: UIImage] = [:]
    private var misses: Set<String> = []

    func photo(matching name: String) async -> UIImage? {
        if let hit = cache[name] { return hit }
        if misses.contains(name) { return nil }

        guard let path = await bestMatch(for: name),
              let url = await randomImageURL(breedPath: path),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            misses.insert(name)
            return nil
        }
        cache[name] = image
        return image
    }

    private func bestMatch(for name: String) async -> String? {
        if breedList == nil {
            guard let url = URL(string: "https://dog.ceo/api/breeds/list/all"),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let decoded = try? JSONDecoder().decode(BreedListResponse.self, from: data) else {
                return nil
            }
            breedList = decoded.message
        }
        guard let list = breedList else { return nil }

        let tokens = Set(name.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        var best: String?
        var bestScore = 0
        for (breed, subs) in list {
            if tokens.contains(breed), bestScore < 1 { best = breed; bestScore = 1 }
            for sub in subs {
                if tokens.contains(breed) && tokens.contains(sub), bestScore < 2 {
                    best = "\(breed)/\(sub)"; bestScore = 2
                } else if tokens.contains(sub), bestScore < 1 {
                    best = "\(breed)/\(sub)"; bestScore = 1
                }
            }
        }
        return best
    }

    private func randomImageURL(breedPath: String) async -> URL? {
        guard let url = URL(string: "https://dog.ceo/api/breed/\(breedPath)/images/random"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(RandomImageResponse.self, from: data) else {
            return nil
        }
        return URL(string: decoded.message)
    }

    private struct BreedListResponse: Decodable { let message: [String: [String]] }
    private struct RandomImageResponse: Decodable { let message: String }
}
