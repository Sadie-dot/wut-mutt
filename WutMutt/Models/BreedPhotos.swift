import UIKit

/// Bundled reference photos, matched against whatever Claude decided to call
/// the breed.
///
/// The names arriving here are free text. Claude is given no catalog — that
/// was deliberate, since constraining it to a kennel-club list would make it
/// lie about the pit-bull cluster and every doodle — so the matcher has to
/// absorb the spread: "Chinese Crested (Powderpuff)" and "Chinese Crested",
/// "German Shepherd Dog" and "German Shepherd", "Retriever (Golden)" and
/// "Golden Retriever", "Pit Bull mix" and "American Pit Bull Terrier".
///
/// A miss is a normal outcome, not a failure. "A Special Guest" is a deliberate
/// wildcard with no breed behind it, and the long tail of real breeds will
/// always outrun 55 bundled photos. The detail screen falls back to the 2×2
/// trait grid, which is a complete design in its own right.
enum BreedPhotos {

    /// The bundled photo whose breed best matches `name`, or nil.
    ///
    /// Synchronous on purpose. These are asset-catalog entries, so the read is
    /// local and UIImage keeps its own cache — the view can ask during body
    /// evaluation instead of routing through the model and a Task.
    static func image(for name: String) -> UIImage? {
        credit(for: name).flatMap { UIImage(named: $0.imageName) }
    }

    /// Exposed for the credits screen and for tests.
    static func credit(for name: String) -> PhotoCredit? {
        let query = queryTokens(of: name)
        guard !query.isEmpty else { return nil }

        var best: (credit: PhotoCredit, score: Double)?
        for credit in photoCredits {
            let breed = tokens(of: credit.breed)
            let shared = breed.intersection(query)
            guard !shared.isEmpty else { continue }

            // Weight each shared word by how rare it is across the whole set.
            // "Terrier" is worth almost nothing — it is in a dozen entries —
            // while "Vizsla" alone is decisive. Without this, "Boston Terrier"
            // and "Yorkshire Terrier" are one word from being the same breed.
            let score = shared.reduce(0.0) { $0 + 1.0 / Double(documentFrequency[$1] ?? 1) }

            // Require at least one word that belongs to essentially this breed
            // alone, so a lone shared "hound" or "mountain" can't carry a match.
            guard shared.contains(where: { (documentFrequency[$0] ?? 1) <= 2 }) else { continue }

            // Every word of the shorter name should be accounted for. This is
            // what separates "Australian Shepherd" from "Australian Cattle
            // Dog": both are distinctive, only one covers the query.
            let needed = min(breed.count, query.count)
            guard shared.count >= needed || score >= 1.0 else { continue }

            if best == nil || score > best!.score { best = (credit, score) }
        }
        return best?.credit
    }

    // MARK: Tokenizing

    /// Words that carry no breed identity, and would otherwise create matches
    /// out of nothing. "Mix"/"cross" matter here: Claude returns "Lab mix" and
    /// "Poodle cross" freely, and the reference photo for the base breed is
    /// still the right picture to show.
    private static let noise: Set<String> = [
        "dog", "dogs", "breed", "mix", "mixed", "cross", "crossbreed", "type",
        "a", "an", "the", "and", "of", "standard", "miniature", "toy", "giant"
    ]

    /// Lowercased words, parentheses flattened rather than dropped: AKC writes
    /// "Retriever (Golden)" and Claude writes variety qualifiers the same way,
    /// so the words inside are usually the useful half of the name.
    private static func tokens(of name: String) -> Set<String> {
        Set(name.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 1 && !noise.contains($0) })
    }

    /// Nicknames and rival spellings, mapped onto the words the catalog uses.
    /// Claude writes the way people talk — "Lab mix", "Dobermann", "Blue
    /// Heeler" — and none of those share a word with the formal name.
    ///
    /// Only unambiguous ones belong here. "Doodle" is absent on purpose: it is
    /// equally either doodle in the set, and a coin flip is worse than the
    /// trait grid. "Staffy" resolves to the Staffordshire Bull Terrier, its
    /// British sense, rather than to the American breed one word away.
    private static let aliases: [String: [String]] = [
        "lab": ["labrador"],
        "labs": ["labrador"],
        "dobermann": ["doberman"],
        "alsatian": ["german", "shepherd"],
        "frenchie": ["french", "bulldog"],
        "yorkie": ["yorkshire"],
        "sheltie": ["shetland"],
        "aussie": ["australian", "shepherd"],
        "berner": ["bernese"],
        "staffy": ["staffordshire", "bull"],
        "staffie": ["staffordshire", "bull"],
        "pitbull": ["pit", "bull"],
        "pittie": ["pit", "bull"],
        "heeler": ["cattle"],
        "wiener": ["dachshund"],
        "weiner": ["dachshund"],
        "sausage": ["dachshund"],
    ]

    /// Query side only — the catalog's own names are already canonical, and
    /// expanding them would skew the word rarity the score depends on.
    private static func queryTokens(of name: String) -> Set<String> {
        Set(tokens(of: name).flatMap { aliases[$0] ?? [$0] })
    }

    /// How many bundled breeds each word appears in.
    private static let documentFrequency: [String: Int] = {
        var counts: [String: Int] = [:]
        for credit in photoCredits {
            for token in tokens(of: credit.breed) { counts[token, default: 0] += 1 }
        }
        return counts
    }()

}
