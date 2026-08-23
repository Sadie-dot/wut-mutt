import SwiftUI
import AVFoundation
import Vision

/// Capture session with photo output plus a throttled Vision pass over the
/// live feed: VNRecognizeAnimalsRequest looks for a dog near the middle of the
/// shot (see `DogSubject`) and gates the REVEAL button.
final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var dogInFrame = false

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "wutmutt.camera.frames")
    private var configured = false
    private var position: AVCaptureDevice.Position = .back
    private var captureCompletion: ((UIImage?) -> Void)?
    private var lastDetection = Date.distantPast
    /// When a dog last passed the gate; REVEAL stays lit within `dogGrace` of
    /// this even through missed frames.
    private var lastDogSeen = Date.distantPast
    private let dogGrace: TimeInterval = 2.0
    /// The bound input device, kept so pinch-to-zoom has something to zoom.
    private var activeDevice: AVCaptureDevice?

    /// Current zoom, 1x up. The screen's pinch gesture reads this back as its
    /// baseline so successive pinches compound instead of restarting at 1.
    @Published private(set) var zoomFactor: CGFloat = 1

    /// Pinch-to-zoom, clamped to 1x-5x (or the format's max if lower). 5x is
    /// generous for a phone-to-dog distance while still leaving the too-tight
    /// shots that fight the whole-body Vision gate out of easy reach. The
    /// zoom applies to the feed Vision reads AND to the captured photo, so
    /// what passes the gate is what gets revealed. No-ops in the simulator,
    /// where there is no device.
    func setZoom(_ factor: CGFloat) {
        guard let device = activeDevice else { return }
        let clamped = max(1, min(factor, min(5, device.activeFormat.videoMaxZoomFactor)))
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
        zoomFactor = clamped
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func flip() {
        position = position == .back ? .front : .back
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.reconfigureInput()
        }
    }

    func capture(completion: @escaping (UIImage?) -> Void) {
        guard configured, session.isRunning else {
            completion(nil)
            return
        }
        captureCompletion = completion
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
        activeDevice = device
        configured = true
    }

    private func reconfigureInput() {
        guard configured else { return }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            activeDevice = device
        }
        session.commitConfiguration()
        // A fresh device starts at 1x; published so the pinch baseline
        // follows the flip instead of jumping on the next gesture.
        DispatchQueue.main.async { self.zoomFactor = 1 }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let completion = captureCompletion
        captureCompletion = nil
        DispatchQueue.main.async {
            if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
                completion?(image)
            } else {
                completion?(nil)
            }
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Two Vision passes per second is plenty for a gate.
        guard Date().timeIntervalSince(lastDetection) > 0.5,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastDetection = Date()

        let request = VNRecognizeAnimalsRequest()
        let classify = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request, classify])

        let found = (request.results ?? []).contains {
            DogSubject.isDog($0) && DogSubject.isCentered($0)
        } || DogSubject.classifiedDog(classify.results ?? [])
        // Hysteresis, not stickiness. The gate used to latch on the first
        // sighting and never release — pan from your dog to an empty
        // sidewalk and REVEAL stayed lit, which a live-dog test proved by
        // submitting the sidewalk. But a gate that tracks every frame
        // flickers, because Vision blanks on a head turn. So: light
        // instantly on a sighting, dim only after a real absence — four
        // consecutive misses at the 0.5s cadence.
        if found { lastDogSeen = Date() }
        let lit = found || Date().timeIntervalSince(lastDogSeen) <= dogGrace
        DispatchQueue.main.async { [weak self] in
            guard let self, self.dogInFrame != lit else { return }
            self.dogInFrame = lit
        }
    }
}

// MARK: - Subject selection

/// What counts as the dog you meant — shared by the REVEAL gate and the
/// portrait crop so the two can't disagree about which dog that is.
///
/// `region` is a subject heuristic, not a crop boundary. It encodes where
/// people put the thing they are pointing at, and it keeps a dog wandering
/// through the background from lighting REVEAL. It is deliberately not tied to
/// the gilded frame: that appears only once a dog is found, so there is
/// nothing on screen to line up with while you aim.
enum DogSubject {
    static let region = CGRect(x: 0.12, y: 0.15, width: 0.76, height: 0.7)
    static let minConfidence: VNConfidence = 0.5

    static func isDog(_ obs: VNRecognizedObjectObservation, confident: Bool = true) -> Bool {
        obs.labels.contains {
            $0.identifier == "Dog" && (!confident || $0.confidence > minConfidence)
        }
    }

    static func isCentered(_ obs: VNRecognizedObjectObservation) -> Bool {
        region.contains(CGPoint(x: obs.boundingBox.midX, y: obs.boundingBox.midY))
    }

    /// The close-up rescue. A face filling the frame is invisible to the
    /// object detector — measured on real nose-boop photos: zero observations,
    /// so no threshold or region tweak can help — but unmistakable to the
    /// image classifier, which answers "what is this a picture of" without
    /// having to localize anything. 0.35 splits the measured cases with room
    /// on both sides: a real face shot classified dog at 0.62, while a busy
    /// overhead scene whose dog was incidental scored 0.11 and should stay
    /// gated. No bounding box comes with a classification, and none is
    /// needed: a frame that classifies as "dog" has the dog as its subject,
    /// which is what the center check exists to establish. The portrait
    /// crop's dogBox stays detection-only and falls back to its centered
    /// crop, exactly as it already does when Vision finds nothing.
    static let classifierFloor: VNConfidence = 0.35

    static func classifiedDog(_ observations: [VNClassificationObservation]) -> Bool {
        observations.contains {
            ($0.identifier == "dog" || $0.identifier == "canine")
                && $0.confidence > classifierFloor
        }
    }

    /// The observation the portrait should crop to. Prefers a confident,
    /// centered dog — the same test the gate applies, so the portrait shows
    /// the dog that lit the button — then falls back to any dog at all, since
    /// library picks never passed the gate and needn't be composed the way a
    /// viewfinder shot is. Ties go to the largest box, usually the one nearest
    /// the camera.
    static func best(in observations: [VNRecognizedObjectObservation]) -> VNRecognizedObjectObservation? {
        let dogs = observations.filter { isDog($0, confident: false) }
        let preferred = dogs.filter { isDog($0) && isCentered($0) }
        let pool = preferred.isEmpty ? dogs : preferred
        return pool.max {
            $0.boundingBox.width * $0.boundingBox.height
                < $1.boundingBox.width * $1.boundingBox.height
        }
    }
}

// MARK: - Preview layer

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView(session: session)
        view.backgroundColor = UIColor(Color.wmNearBlack)
        return view
    }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

final class PreviewUIView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init(frame: .zero)
        layer.insertSublayer(previewLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
