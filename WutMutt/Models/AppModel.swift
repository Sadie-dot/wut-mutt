import SwiftUI
import PhotosUI
import AVFoundation
import Vision

// MARK: - Breed

struct Breed: Identifiable {
    let id = UUID()
    var name: String
    var pct: Int
    var tagline: String
    var size: String
    var energy: String
    var drool: String
    var floof: String
    var clues: [String]
    var fact: String
    var colorIndex: Int = 0

    /// Data colors assigned by list order, straight off the spoiler covers:
    /// the pink of the field, the yellow a featured couple's name is set in,
    /// a show-title blue, a show-title green. A tabloid doesn't do tasteful
    /// tone-on-tone, and a ramp of one hue read as muted next to the source.
    ///
    /// These are decorative emphasis, not a legend — every row states its own
    /// breed and percentage, and no other screen reads meaning out of the
    /// colour. That is what buys the freedom to be this loud: three of the
    /// four are too light to carry information on their own, and the bars
    /// borrow the covers' own fix by wearing an outline.
    static let palette: [Color] = [
        .wmAccent, .wmSpoilerYellow, .wmIceDeep, .wmSpoilerGreen
    ]

    /// The wildcard the prompt lets Claude return in place of a fourth breed.
    /// Kept here so the app can recognise it; the prompt's own copy of the
    /// name lives in `BreedIdentifier` and `proxy/src/index.js`.
    static let wildcardName = "Guest Star"

    /// The name as it reads in a sentence. The wildcard names a role rather
    /// than a breed, so it takes an article: "with Boxer, and a Guest Star".
    /// Matched case-insensitively because the name comes back from Claude
    /// rather than from us.
    ///
    /// Lives on `Breed` so every billing on the card goes through one place —
    /// the cast line was built from raw `name` and quietly lost the article.
    var billedName: String {
        name.caseInsensitiveCompare(Breed.wildcardName) == .orderedSame ? "a \(name)" : name
    }
    var color: Color { Breed.palette[colorIndex % Breed.palette.count] }

    /// Great Vibes hero name, auto-scaled to stay on one line.
    var heroNameSize: CGFloat {
        name.count <= 13 ? 54 : name.count <= 19 ? 40 : 32
    }

    /// Canned fallback episode, shown when Claude is unavailable or returns
    /// something unparseable. No error UI — the show must go on.
    static let fallbackEpisode: [Breed] = [
        Breed(name: "Plott Hound", pct: 41,
              tagline: "The brooding lead with a hidden past",
              size: "Large", energy: "Very high", drool: "Low", floof: "Minimal",
              clues: ["That gorgeous brindle coat", "Long, velvety hound ears", "Lean, athletic build"],
              fact: "Plott Hounds are the official state dog of North Carolina — bred to fearlessly hunt wild boar, currently fearlessly hunting your spot on the chair.",
              colorIndex: 0),
        Breed(name: "Mountain Cur", pct: 26,
              tagline: "The rugged stranger from out of town",
              size: "Medium", energy: "High", drool: "Low", floof: "Short & sleek",
              clues: ["Broad, blocky head shape", "Tight short coat", "That watchful expression"],
              fact: "Mountain Curs came west with American pioneers and were so valued that puppies rode in saddlebags on the wagon trail.",
              colorIndex: 1),
        Breed(name: "Boxer", pct: 19,
              tagline: "The lovable fool nobody suspects",
              size: "Large", energy: "Bouncy", drool: "Moderate", floof: "Minimal",
              clues: ["Deep chest, tucked waist", "Soulful wrinkly forehead", "Front paws crossed like royalty"],
              fact: "Boxers are famously puppy-brained: they are one of the slowest breeds to mature, staying goofy until about age three. Some never stop.",
              colorIndex: 2),
        Breed(name: Breed.wildcardName, pct: 14,
              tagline: "The fabulous mystery in the family tree",
              size: "Perfect", energy: "Dreamy", drool: "Effortless", floof: "Inspired",
              clues: ["A certain je ne sais quoi", "Refuses to be categorized", "Extra good for no reason"],
              fact: "Every great mutt keeps a little mystery. Studies show mixed-breed dogs often live longer than purebreds — the mystery is good for them.",
              colorIndex: 3)
    ]
}

// MARK: - App model

enum Screen: Equatable {
    case curtain, home, analyzing, results, nodog
    case detail(Int)
    case offAir(OffAir)

    var isDarkSet: Bool {
        switch self {
        case .results, .detail: return false
        default: return true
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var screen: Screen = .curtain {
        didSet { announceScreenChange(from: oldValue) }
    }
    @Published var shareOpen = false
    @Published var aiDisclosureOpen = false
    @Published var imageCreditsOpen = false
    @Published var cameraDeniedAlert = false
    /// An off-air retry was refused because the device is clearly offline —
    /// the card shows its "still no feed" beat while this is set.
    @Published var retryDeniedOffline = false

    // Camera
    @Published var dogDetected = false

    // Analyzing
    @Published var teaserIdx = 0

    /// What put the dog under, rotating per reveal. All six start on a
    /// consonant, so beat 2's "A …-induced" article holds for every one.
    static let comaCauses = ["squirrel", "meatball", "kitten",
                             "cheddar", "sausage", "squeaker"]

    /// This episode's cause, fixed when the reveal starts — beat 2 plays at
    /// 1.6s, long before there's a verdict to consult.
    @Published var comaCause = AppModel.comaCauses[0]

    /// The setup. One sentence in four parts, not four interchangeable lines —
    /// beat 1 doesn't parse without beat 2, and beat 4 is the setup whose
    /// payoff is `closing.question`. Shuffling these would produce word salad;
    /// only the cause and the closing question vary.
    var setup: [String] {
        // U+2060 WORD JOINER after the hyphen. The line runs 286-300pt in a
        // 282pt column whichever cause is drawn, so it always wraps — the
        // question is only where. Left alone the engine takes the hyphen and
        // strands "induced coma…" on its own line; forbidding that break sends
        // it to the space instead, for "A meatball-induced" / "coma…".
        //
        // A word joiner rather than a non-breaking hyphen (U+2011): it carries
        // no glyph, so it can't come out as a missing-character box if a face
        // in the family doesn't cover that codepoint.
        ["Ever since waking from…",
         "A \(comaCause)-\u{2060}induced coma…",
         "The look in those puppy eyes hasn't been the same.",
         "Both brain cells had one question…"]
    }

    /// The fifth beat, chosen once the studio has actually seen the dog.
    @Published var closing = AppModel.smallQuestions[0]

    /// What's on screen now.
    var currentTeaser: String {
        teaserIdx < setup.count ? setup[teaserIdx] : closing.question
    }

    // Episode data
    @Published var capturedImage: UIImage?
    @Published var portraitImage: UIImage?      // face-centered crop for the gilded portrait

    /// Where the dog is in `capturedImage`, normalized 0…1 with a **top-left**
    /// origin (Vision's own boxes are bottom-left; this is already flipped).
    ///
    /// Vision finds this to build the portrait crop and the old code dropped it
    /// on the floor. The share card needs it too: it gives half its area to the
    /// photo, and without knowing where the subject is it can only centre-crop,
    /// which puts a wall where the dog should be on any wide shot.
    ///
    /// `nil` means Vision didn't run or found nothing — including everywhere in
    /// the simulator, where the detector can't create an inference context at
    /// all. Consumers must have a centred fallback.
    @Published var dogBox: CGRect?
    @Published var breeds: [Breed] = Breed.fallbackEpisode
    @Published var certainty: Int = 87

    // Photo picker (one "Album" everywhere: curtain, camera, twist, Reshoot!)
    @Published var pickerPresented = false
    @Published var pickedItem: PhotosPickerItem?

    // MARK: The closing question

    /// The analyzing screen's last beat, and the headline that answers it.
    ///
    /// The joke is proportion: the question is absurd against the dog actually
    /// in frame, so a Great Dane is asked whether it's a chihuahua and a
    /// chihuahua is asked whether it's a Great Dane. The results headline has to
    /// answer whatever got asked, so all of it travels together.
    /// The confirmations read "CHANNELING X" rather than "X VIBES CONFIRMED!"
    /// because the share card's kicker is 12pt Playfair at 4pt kerning in 300pt
    /// of card, and the longer form spent every one of them: Saint Bernard
    /// overflowed outright at 331pt, and Rottweiler landed on exactly 300.
    /// "CHANNELING X" tops out at 274pt, so the whole set has real headroom —
    /// and the kicker scales with Dynamic Type, so headroom is the point.
    struct ClosingQuestion {
        let question: String        // "Am I a chihuahua?"
        let denial: String          // "NOT A CHIHUAHUA"
        let confirmation: String    // "CHANNELING CHIHUAHUA"
        /// Lowercased needle for "did the mix actually contain this?" — Claude
        /// returns "Yorkshire Terrier", never "Yorkie". nil never confirms.
        let match: String?
    }

    /// Asked of a big dog.
    static let smallQuestions = [
        ClosingQuestion(question: "Am I a chihuahua?", denial: "NOT A CHIHUAHUA",
                        confirmation: "CHANNELING CHIHUAHUA", match: "chihuahua"),
        ClosingQuestion(question: "Am I a pug?", denial: "NOT A PUG",
                        confirmation: "CHANNELING PUG", match: "pug"),
        ClosingQuestion(question: "Am I a Yorkie?", denial: "NOT A YORKIE",
                        confirmation: "CHANNELING YORKIE", match: "yorkshire"),
        ClosingQuestion(question: "Am I a whippet?", denial: "NOT A WHIPPET",
                        confirmation: "CHANNELING WHIPPET", match: "whippet")
    ]

    /// Asked of a little dog.
    static let largeQuestions = [
        ClosingQuestion(question: "Am I a Great Dane?", denial: "NOT A GREAT DANE",
                        confirmation: "CHANNELING GREAT DANE", match: "dane"),
        ClosingQuestion(question: "Am I a Rottweiler?", denial: "NOT A ROTTWEILER",
                        confirmation: "CHANNELING ROTTWEILER", match: "rottweiler"),
        ClosingQuestion(question: "Am I a Saint Bernard?", denial: "NOT A SAINT BERNARD",
                        confirmation: "CHANNELING SAINT BERNARD", match: "bernard"),
        ClosingQuestion(question: "Am I a wolfhound?", denial: "NOT A WOLFHOUND",
                        confirmation: "CHANNELING WOLFHOUND", match: "wolfhound")
    ]

    /// Asked of a dog that won't be placed. The coat is inverted on purpose —
    /// the flat-coated get asked about the curliest breed there is, the fluffy
    /// about the smoothest.
    static let poodleQuestion = ClosingQuestion(
        question: "Am I a poodle?", denial: "NOT A POODLE",
        confirmation: "CHANNELING POODLE", match: "poodle")
    static let bulldogQuestion = ClosingQuestion(
        question: "Am I a bulldog?", denial: "NOT A BULLDOG",
        confirmation: "CHANNELING BULLDOG", match: "bulldog")

    /// For an actual poodle, the only question left worth asking. `match` is nil
    /// because no mix ever comes back human, so this one only ever denies.
    static let humanQuestion = ClosingQuestion(
        question: "Am I human?", denial: "NOT HUMAN",
        confirmation: "CHANNELING HUMAN", match: nil)

    /// Picks the closing beat against what the studio saw.
    ///
    /// Order matters. A poodle also satisfies the coat branch, and asking a
    /// poodle whether it's a poodle is the one reading with no joke in it.
    func closingQuestion(for look: DogLook?, breeds: [Breed]) -> ClosingQuestion {
        if breeds.contains(where: { $0.name.localizedCaseInsensitiveContains("poodle") }) {
            return Self.humanQuestion
        }
        // No look means a studio that predates the fields — ask what the app
        // always asked rather than inventing a reading of the dog.
        guard let look else { return Self.smallQuestions[0] }

        switch (look.size, look.coat) {
        case (.unclear, .flat):   return Self.poodleQuestion
        case (.unclear, .fluffy): return Self.bulldogQuestion
        case (.large, _):         return Self.rotate(Self.smallQuestions, key: "wm-question-idx")
        case (.small, _):         return Self.rotate(Self.largeQuestions, key: "wm-question-idx")
        }
    }

    /// Advances a persisted counter and hands back the next element, so two big
    /// dogs in a row don't both get asked about a chihuahua — the trick
    /// `starIdx` plays on the opening portrait. Rotation rather than random,
    /// because random repeats, which is the whole thing this is meant to fix.
    ///
    /// Each pool keeps its own key: the question only advances on the pooled
    /// branches, so sharing a counter with the coma cause would drift them into
    /// step with each other.
    private static func rotate<T>(_ pool: [T], key: String) -> T {
        let defaults = UserDefaults.standard
        let next = ((defaults.object(forKey: key) as? Int) ?? -1) + 1
        defaults.set(next, forKey: key)
        return pool[next % pool.count]
    }

    // Opening-screen star: one of 5 cast portraits, advancing one per launch.
    struct Star {
        let asset: String       // bundled image name
        let anchor: UnitPoint   // crop position from the prototype
        let headline: String    // paired 1:1 with the image
        let nickname: String    // end-credits cast name
    }
    static let stars: [Star] = [
        Star(asset: "star-golden-retriever", anchor: .init(x: 0.5, y: 0.60),
             headline: "Spoiler Alert!", nickname: "The Weeping Golden"),
        Star(asset: "star-australian-shepherd", anchor: .init(x: 0.5, y: 0.10),
             headline: "Shocking revelation", nickname: "The Aussie with a Secret"),
        Star(asset: "star-basset-hound", anchor: .init(x: 0.5, y: 0.35),
             headline: "Plot twist", nickname: "The Basset Who Knew Too Much"),
        Star(asset: "star-chinese-crested", anchor: .init(x: 0.5, y: 0.42),
             headline: "No more secrets", nickname: "The Crested Heiress"),
        Star(asset: "star-staffordshire-bull-terrier", anchor: .init(x: 0.5, y: 0.08),
             headline: "Exposed!", nickname: "The Brooding Staffie")
    ]
    let starIdx: Int
    var star: Star { Self.stars[starIdx] }

    private var scanTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let prev = defaults.object(forKey: "wm-star-idx") as? Int
        starIdx = prev.map { ($0 + 1) % Self.stars.count } ?? 0
        defaults.set(starIdx, forKey: "wm-star-idx")

        #if DEBUG
        // `SIMCTL_CHILD_WM_JUMP=1` with WM_FORCE_VERDICT set: launch directly
        // on the verdict's screen — design comps skip the whole
        // curtain → camera → analyzing drive.
        if ProcessInfo.processInfo.environment["WM_JUMP"] != nil,
           let forced = Self.forcedVerdict() {
            // The twist mugshot and the Cut! disc both show `capturedImage`,
            // which a direct jump never sets. Tonight's star stands in.
            capturedImage = UIImage(named: Self.stars[starIdx].asset)
            switch forced {
            case .notADog:
                screen = .nodog
            case .offAir(let info):
                screen = .offAir(info)
            case .dog(let breeds, let certainty, _):
                self.breeds = breeds
                self.certainty = certainty
                screen = .results
            }
        }
        #endif
    }

    // MARK: Derived episode copy

    var certaintyLabel: String {
        certainty >= 80 ? "Devastatingly sure"
        : certainty >= 60 ? "Reasonably scandalized" : "Merely suspicious"
    }

    var breedCountWord: String {
        [2: "two", 3: "three", 4: "four"][breeds.count] ?? String(breeds.count)
    }

    /// Answers whatever the analyzing screen just asked. The question is chosen
    /// to be absurd, so the denial is the usual outcome and a confirmation is
    /// the rare surprise — a small dog asked about a Great Dane that turns out
    /// to have one in the mix.
    var castHeadline: String {
        guard let match = closing.match,
              breeds.contains(where: { $0.name.localizedCaseInsensitiveContains(match) })
        else { return "EXCLUSIVE: \(closing.denial)" }
        return "EXCLUSIVE: \(closing.confirmation)"
    }

    /// Share-card verdict kicker — the cast headline without "EXCLUSIVE: ".
    var shareKicker: String {
        castHeadline.replacingOccurrences(of: "EXCLUSIVE: ", with: "")
    }

    /// The card bills its cast; it doesn't publish figures. A percentage that
    /// leaves the app leaves the disclaimer behind with it, and "40%" pasted
    /// into a group chat reads as a measurement rather than the juicy guess
    /// this is. Same call the certainty dial already made by showing an
    /// adjective instead of a number.
    var shareStar: String { breeds.first?.name ?? "" }

    /// The rosette every dog gets, on the results pennant and on the card's
    /// yellow badge. One definition because it is now user-visible in two
    /// places, and a line this app repeats had better repeat exactly.
    var shareBadge: String { "a very good dog" }

    var shareOthers: String {
        guard breeds.count > 1 else { return "a purebred plot line" }
        let rest = breeds.dropFirst().map(\.billedName)
        if rest.count == 1 { return "with \(rest[0])" }
        // The whole closing unit is glued with non-breaking spaces, not just
        // "and" to the word after it. Gluing only "and" moved the break one
        // word later, which for the wildcard's "a Guest Star" billing ended a
        // line on "and a" and orphaned "Guest Star" below it — the article
        // stranded on the wrong side of the joke. The longest possible unit
        // ("and American Staffordshire Terrier") still fits a line on its own.
        let closer = "and \(rest.last!)".replacingOccurrences(of: " ", with: "\u{00A0}")
        return "with " + rest.dropLast().joined(separator: ", ") + ", " + closer
    }


    // MARK: Camera permission

    func requestCameraThenHome() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            goHome()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { self.goHome() }
                }
            }
        default:
            cameraDeniedAlert = true
        }
    }

    func goHome() {
        scanTask?.cancel()
        shareOpen = false
        dogDetected = false
        retryDeniedOffline = false
        screen = .home
        #if targetEnvironment(simulator)
        // The simulator has no camera feed for Vision to watch; stand in for
        // detection so the flow stays demoable (mirrors the prototype's 2.2s).
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if self.screen == .home { self.dogDetected = true }
        }
        #endif
    }

    func openPicker() {
        pickerPresented = true
    }

    /// Called when the shared PhotosPicker delivers an item.
    func handlePickedItem() {
        guard let item = pickedItem else { return }
        pickedItem = nil
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                startScan(with: image)
            }
        }
    }

    // MARK: The scan — analyzing beat + Claude call

    func startScan(with image: UIImage) {
        #if targetEnvironment(simulator)
        // Nothing configured in the simulator — play the canned episode so
        // the whole show stays demoable without credentials. This is the
        // ONLY path that fabricates a reading, and it can't reach a device.
        // A device build without proxy config runs the real call instead and
        // lands on the stand-by card — a developer mistake, honestly reported.
        guard BreedIdentifier.hasCredentials else {
            runEpisode(with: image) {
                .dog(breeds: Breed.fallbackEpisode, certainty: 87,
                     look: DogLook(size: .large, coat: .flat))
            }
            return
        }
        #endif
        runEpisode(with: image) { await Self.identify(image) }
    }

    /// Re-runs the reveal on the photo we already have, for the off-air card.
    /// When the device is clearly offline the retry refuses to replay the
    /// analyzing theater — an inline beat on the card says so instead.
    func retryScan() {
        guard let image = capturedImage else { goHome(); return }
        guard !FeedMonitor.shared.retryWouldFail else {
            retryDeniedOffline = true
            return
        }
        retryDeniedOffline = false
        startScan(with: image)
    }

    /// The analyzing beat: four setup teasers, then the question, running
    /// alongside whatever is producing the verdict.
    ///
    /// The closing question can't be picked until the verdict lands, because it
    /// is asked *about* the dog the verdict describes — so the beat holds on
    /// setup line four, "Both brain cells had one question…", until the studio
    /// answers. That line is a setup, so waiting there reads as suspense; the
    /// old sequence held on the punchline instead, where a slow reveal looked
    /// like a hang. The 8s floor is unchanged: 6.4s of setup, 1.6s of question.
    private func runEpisode(with image: UIImage,
                            verdict: @escaping @Sendable () async -> BreedVerdict) {
        capturedImage = image
        portraitImage = nil
        dogBox = nil
        retryDeniedOffline = false
        teaserIdx = 0
        comaCause = Self.rotate(Self.comaCauses, key: "wm-coma-idx")
        closing = Self.smallQuestions[0]
        shareOpen = false
        screen = .analyzing

        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            async let pending = verdict()

            // Setup beats 2-4 on their marks; beat 1 is already up.
            for i in 1..<self.setup.count {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                self.teaserIdx = i
            }
            // Beat 4 gets its own beat, and holds past it if the studio is slow.
            try? await Task.sleep(nanoseconds: 1_600_000_000)

            let result = await pending
            guard !Task.isCancelled, self.screen == .analyzing else { return }

            // Now the dog is known, so the question can be about this dog.
            if case .dog(let breeds, _, let look) = result {
                self.closing = self.closingQuestion(for: look, breeds: breeds)
            }
            self.teaserIdx = self.setup.count
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled, self.screen == .analyzing else { return }

            switch result {
            case .notADog:
                self.screen = .nodog
            case .dog(let breeds, let certainty, _):
                self.breeds = breeds
                self.certainty = certainty
                self.cropPortrait(from: image)
                self.screen = .results
            case .offAir(let info):
                self.screen = .offAir(info)
            }
        }
    }

    private nonisolated static func identify(_ image: UIImage) async -> BreedVerdict {
        #if DEBUG
        if let forced = Self.forcedVerdict() { return forced }
        #endif
        do { return try await BreedIdentifier().identify(image) }
        catch { return .offAir(BreedIdentifier.offAir(for: error)) }
    }

    #if DEBUG
    /// Dev hooks: `SIMCTL_CHILD_WM_FORCE_VERDICT=<case> simctl launch` forces
    /// a path without needing to reproduce it for real. Shared by identify()
    /// and the WM_JUMP launch shortcut.
    private nonisolated static func forcedVerdict() -> BreedVerdict? {
        switch ProcessInfo.processInfo.environment["WM_FORCE_VERDICT"] {
        case "nodog":                       // the prototype's teddy-bear shortcut
            return .notADog
        case "offair":                      // daily cap spent (message is app-owned)
            return .offAir(BreedIdentifier.offAir(for: BreedIdentifierError.api(
                type: "rate_limit", message: "")))
        case "offline":                     // lost the feed
            return .offAir(BreedIdentifier.offAir(for: URLError(.notConnectedToInternet)))
        case "standby":                     // any server-side trouble that isn't the cap
            return .offAir(BreedIdentifier.offAir(for: BreedIdentifierError.api(
                type: "upstream_unavailable", message: "")))
        case "refused":                     // Claude declined the photo
            return .offAir(BreedIdentifier.offAir(for: BreedIdentifierError.refused))
        case "badimage":                    // the capture couldn't be encoded
            return .offAir(BreedIdentifier.offAir(for: BreedIdentifierError.badImage))
        case "dog":                         // the happy path, without spending a reveal
            return .dog(breeds: Self.forcedBreeds, certainty: 87, look: Self.forcedLook)
        case "nolook":                      // a proxy that predates dogSize/dogCoat
            return .dog(breeds: Breed.fallbackEpisode, certainty: 87, look: nil)
        default:
            return nil
        }
    }
    #endif

    #if DEBUG
    /// `SIMCTL_CHILD_WM_FORCE_LOOK=<case>` alongside `WM_FORCE_VERDICT=dog`,
    /// so every closing question is reachable without hunting for a photo of
    /// the right dog.
    private nonisolated static var forcedLook: DogLook {
        switch ProcessInfo.processInfo.environment["WM_FORCE_LOOK"] {
        case "small":  return DogLook(size: .small, coat: .flat)
        case "flat":   return DogLook(size: .unclear, coat: .flat)
        case "fluffy": return DogLook(size: .unclear, coat: .fluffy)
        default:       return DogLook(size: .large, coat: .flat)
        }
    }

    /// `WM_FORCE_BREED=<name>` renames the lead breed. Both the human question
    /// and the "CHANNELING X" headline key off the mix rather than the look,
    /// and that headline is the longest string either screen can hold.
    private nonisolated static var forcedBreeds: [Breed] {
        var breeds = Breed.fallbackEpisode
        if let name = ProcessInfo.processInfo.environment["WM_FORCE_BREED"], !name.isEmpty {
            breeds[0].name = name
        }
        // `WM_FORCE_CAST=<name>,<name>` renames the supporting cast in order
        // (the wildcard keeps its slot), because the cast line's wrap depends
        // on which names precede "and a Guest Star" and the fallback episode
        // only ever exercises the one-line case.
        if let cast = ProcessInfo.processInfo.environment["WM_FORCE_CAST"], !cast.isEmpty {
            for (i, name) in cast.split(separator: ",").enumerated()
            where i + 1 < breeds.count {
                breeds[i + 1].name = String(name)
            }
        }
        return breeds
    }
    #endif

    // MARK: Portrait crop

    /// Centers the gilded portrait on the dog's face using Vision's animal
    /// detector; falls back to a center-square crop. Publishes the dog's
    /// bounding box alongside it, so the share card can aim its own crop
    /// without paying for a second detection pass.
    private func cropPortrait(from image: UIImage) {
        Task.detached(priority: .userInitiated) { [weak self] in
            let found = Self.locateDog(image)
            await MainActor.run {
                self?.portraitImage = found.portrait
                self?.dogBox = found.box ?? Self.forcedDogBox
            }
        }
    }

    #if DEBUG
    /// `SIMCTL_CHILD_WM_FORCE_DOGBOX=x,y,w,h` (normalized, top-left origin)
    /// stands in for a detection the simulator cannot perform — the animal
    /// detector has no inference context here, so `dogBox` is otherwise always
    /// nil and the card's aiming can only be exercised on a device.
    static var forcedDogBox: CGRect? {
        let parts = (ProcessInfo.processInfo.environment["WM_FORCE_DOGBOX"] ?? "")
            .split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }
    #else
    static var forcedDogBox: CGRect? { nil }
    #endif

    /// The dog, and the copy of the image Vision found it in.
    ///
    /// One pass isn't reliable enough here. Vision's animal detector has narrow
    /// framings where it returns *no observation at all* rather than a weak
    /// one — not low confidence, nothing to threshold — and a single pixel
    /// decides it. Measured on one photo: of 31 crop widths, 30 detected at
    /// 0.63-0.79 and one returned nothing, with tighter crops on both sides
    /// fine. Re-encoding, JPEG quality and resampling didn't move it; trimming
    /// one pixel off each edge did, and rescued all 13 failing variants
    /// collected, none below 0.57.
    ///
    /// The live REVEAL gate never needed this — it runs twice a second on a
    /// handheld feed, so no two frames are identical and a basin this narrow
    /// washes out immediately. Here there is one image and one chance, and the
    /// album path never runs the gate at all, so this pass is the only
    /// detection that ever happens for it.
    ///
    /// Crops are taken from whichever copy answered, so there is no coordinate
    /// remapping to get wrong. The insets are symmetric and a few pixels on a
    /// photo thousands wide — invisible in a 224pt circle.
    ///
    /// A *thrown* request is a different thing from an empty one, and stops the
    /// ladder immediately: nothing about the image was the problem, so retrying
    /// only burns time. The simulator is the case in point — every request
    /// there fails with "Could not create inference context", because the
    /// detector wants hardware the simulator doesn't have. This whole path is
    /// therefore dead in the simulator and the portrait is always the
    /// center-square fallback, which also means the retry can only be
    /// confirmed on a device.
    private nonisolated static func findDog(_ cg: CGImage,
                                            _ orientation: CGImagePropertyOrientation)
        -> (image: CGImage, animal: VNRecognizedObjectObservation)? {
        for inset in [0, 1, 3, 8] {
            let candidate = inset == 0 ? cg : cg.cropping(to: CGRect(
                x: inset, y: inset,
                width: cg.width - inset * 2, height: cg.height - inset * 2))
            guard let candidate else { continue }
            let request = VNRecognizeAnimalsRequest()
            let handler = VNImageRequestHandler(cgImage: candidate, orientation: orientation)
            // Picking the subject the same way the REVEAL gate does, so a shot
            // with more than one dog portraits the one that lit the button
            // rather than whichever observation Vision happened to return first.
            guard (try? handler.perform([request])) != nil else { return nil }
            if let animal = DogSubject.best(in: request.results ?? []) {
                return (candidate, animal)
            }
        }
        return nil
    }

    /// One detection pass, two answers: the square the gilded portrait wants,
    /// and where the dog actually is so other layouts can aim for themselves.
    ///
    /// The box is normalized against the *inset* copy Vision answered on rather
    /// than the original. The insets top out at 8px on a photo thousands wide —
    /// under half a percent, and this box only steers a crop, it doesn't measure
    /// anything — so it is left unmapped rather than risking an orientation
    /// remap for a sub-pixel gain.
    private nonisolated static func locateDog(_ image: UIImage)
        -> (portrait: UIImage, box: CGRect?) {
        guard let full = image.cgImage else { return (image, nil) }
        let found = findDog(full, .init(image.imageOrientation))
        let cg = found?.image ?? full
        // Vision's origin is bottom-left; everything downstream of here is UIKit.
        let box = found.map { f -> CGRect in
            let b = f.animal.boundingBox
            return CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
        }
        return (faceCrop(image, cg: cg, animal: found?.animal), box)
    }

    private nonisolated static func faceCrop(_ image: UIImage,
                                             cg: CGImage,
                                             animal: VNRecognizedObjectObservation?) -> UIImage {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        var box: CGRect?
        if let animal {
            // Vision boxes are normalized with a bottom-left origin. Favor the
            // upper part of the body box — that's where the face lives.
            let b = animal.boundingBox
            let rect = CGRect(x: b.minX * w, y: (1 - b.maxY) * h,
                              width: b.width * w, height: b.height * h)
            let side = min(max(rect.width, rect.height * 0.6) * 1.15, min(w, h))
            box = CGRect(x: rect.midX - side / 2, y: rect.minY - side * 0.08,
                         width: side, height: side)
        }
        var crop = box ?? CGRect(x: 0, y: 0, width: min(w, h), height: min(w, h))
            .offsetBy(dx: (w - min(w, h)) / 2, dy: (h - min(w, h)) / 4)
        crop.origin.x = min(max(0, crop.origin.x), w - crop.width)
        crop.origin.y = min(max(0, crop.origin.y), h - crop.height)
        crop = crop.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard let cut = cg.cropping(to: crop) else { return image }
        return UIImage(cgImage: cut, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: VoiceOver

    private func announceScreenChange(from old: Screen) {
        guard screen != old else { return }
        let message: String?
        switch screen {
        case .analyzing: message = "Analyzing your photo. A dramatic pause."
        case .results:   message = "The results are in: \(breeds.first?.name ?? "") leads the cast."
        case .nodog:     message = "Shocking twist: that is not a dog."
        case .home:      message = "Camera. Fit your dog in the frame."
        case .offAir(let info):
            message = "\(info.headline) \(info.message.replacingOccurrences(of: "\n", with: " "))"
        default:         message = nil
        }
        if let message {
            UIAccessibility.post(notification: .screenChanged, argument: message)
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
