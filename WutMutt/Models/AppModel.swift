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

    /// Data colors assigned by list order (Mountain-Cur gold darkened to
    /// #9A6E0F per the accessibility audit).
    static let palette: [Color] = [
        Color(hex: "#D91F5C"), Color(hex: "#9A6E0F"),
        Color(hex: "#E13A6F"), Color(hex: "#3EBFA5")
    ]
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
        Breed(name: "A Special Guest", pct: 14,
              tagline: "The long-lost twin, presumed missing",
              size: "Unknowable", energy: "Surprise", drool: "TBD", floof: "Classified",
              clues: ["A certain je ne sais quoi", "Refuses to be categorized", "Extra good for no reason"],
              fact: "Every great mutt keeps a little mystery. Studies show mixed-breed dogs often live longer than purebreds — the mystery is good for them.",
              colorIndex: 3)
    ]
}

// MARK: - App model

enum Screen: Equatable {
    case curtain, home, analyzing, results, nodog
    case detail(Int)

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
    @Published var creditsOpen = false
    @Published var keyEntryOpen = false
    @Published var cameraDeniedAlert = false

    // Camera
    @Published var dogDetected = false

    // Analyzing
    @Published var teaserIdx = 0
    let teasers = [
        "Ever since waking from…",
        "A squirrel-induced coma…",
        "The look in those puppy eyes hasn't been the same.",
        "Both brain cells had one question…",
        "Am I a chihuahua?"
    ]

    // Episode data
    @Published var capturedImage: UIImage?
    @Published var portraitImage: UIImage?      // face-centered crop for the gilded portrait
    @Published var breeds: [Breed] = Breed.fallbackEpisode
    @Published var certainty: Int = 87
    @Published var breedPhotos: [String: UIImage] = [:]

    // Photo picker (shared by curtain Upload, camera ALBUM, no-dog Upload)
    @Published var pickerPresented = false
    @Published var pickedItem: PhotosPickerItem?

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
    }

    // MARK: Derived episode copy

    var certaintyLabel: String {
        certainty >= 80 ? "Devastatingly sure"
        : certainty >= 60 ? "Reasonably scandalized" : "Merely suspicious"
    }

    var breedCountWord: String {
        [2: "two", 3: "three", 4: "four"][breeds.count] ?? String(breeds.count)
    }

    var castHeadline: String {
        breeds.contains { $0.name.localizedCaseInsensitiveContains("chihuahua") }
            ? "EXCLUSIVE: CHIHUAHUA VIBES CONFIRMED!"
            : "EXCLUSIVE: NOT A CHIHUAHUA"
    }

    /// Share-card verdict kicker — the cast headline without "EXCLUSIVE: ".
    var shareKicker: String {
        castHeadline.replacingOccurrences(of: "EXCLUSIVE: ", with: "")
    }

    var shareTitle: String {
        guard let lead = breeds.first else { return "" }
        return "\(lead.name) — \(lead.pct)%"
    }

    var shareOthers: String {
        guard breeds.count > 1 else { return "a purebred plot line" }
        let rest = breeds.dropFirst().map(\.name)
        if rest.count == 1 { return "with \(rest[0])" }
        // Glue "and" to the last name with a non-breaking space so they wrap together.
        return "with " + rest.dropLast().joined(separator: ", ") + ", and\u{00A0}" + rest.last!
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
        // In the simulator a missing key doesn't block the show: the Claude
        // call fails fast and the canned fallback episode plays instead.
        #if !targetEnvironment(simulator)
        guard BreedIdentifier.hasCredentials else {
            keyEntryOpen = true
            return
        }
        #endif
        capturedImage = image
        portraitImage = nil
        teaserIdx = 0
        shareOpen = false
        screen = .analyzing

        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            async let verdict = Self.identify(image)

            // Teasers play once, 1.6s apiece, then hold on the last — the
            // sequence itself is the 8s minimum runtime.
            for i in 1..<teasers.count {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                self.teaserIdx = i
            }
            try? await Task.sleep(nanoseconds: 1_600_000_000)

            let result = await verdict
            guard !Task.isCancelled, self.screen == .analyzing else { return }

            switch result {
            case .notADog:
                self.screen = .nodog
            case .dog(let breeds, let certainty):
                self.breeds = breeds
                self.certainty = certainty
                self.cropPortrait(from: image)
                self.screen = .results
            case .unavailable:
                // Claude failure or malformed JSON — run the canned episode.
                self.breeds = Breed.fallbackEpisode
                self.certainty = 87
                self.cropPortrait(from: image)
                self.screen = .results
            }
        }
    }

    private nonisolated static func identify(_ image: UIImage) async -> BreedVerdict {
        do { return try await BreedIdentifier().identify(image) }
        catch { return .unavailable }
    }

    // MARK: Portrait crop

    /// Centers the gilded portrait on the dog's face using Vision's animal
    /// detector; falls back to a center-square crop.
    private func cropPortrait(from image: UIImage) {
        Task.detached(priority: .userInitiated) { [weak self] in
            let cropped = Self.faceCrop(image)
            await MainActor.run { self?.portraitImage = cropped }
        }
    }

    private nonisolated static func faceCrop(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        var box: CGRect?
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation))
        if (try? handler.perform([request])) != nil,
           let animal = request.results?.first(where: { obs in
               obs.labels.contains { $0.identifier == "Dog" }
           }) {
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

    // MARK: Breed reference photos (dog.ceo stand-in)

    func loadBreedPhoto(for breed: Breed) {
        let name = breed.name
        guard breedPhotos[name] == nil else { return }
        Task {
            if let image = await DogImageFetcher.shared.photo(matching: name) {
                self.breedPhotos[name] = image
            }
        }
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
