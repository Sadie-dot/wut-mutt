import SwiftUI
import AVFoundation
import Vision

/// Capture session with photo output plus a throttled Vision pass over the
/// live feed: VNRecognizeAnimalsRequest looks for a dog roughly inside the
/// viewfinder region and gates the REVEAL button.
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
        }
        session.commitConfiguration()
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
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([request])

        // "In frame" ≈ the dog's box center falls in the middle of the shot,
        // matching the gilded viewfinder region.
        let central = CGRect(x: 0.12, y: 0.15, width: 0.76, height: 0.7)
        let found = (request.results ?? []).contains { obs in
            obs.labels.contains { $0.identifier == "Dog" && $0.confidence > 0.5 }
                && central.contains(CGPoint(x: obs.boundingBox.midX, y: obs.boundingBox.midY))
        }
        if found {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.dogInFrame else { return }
                // Sticky once seen — the caption flips and REVEAL stays lit.
                self.dogInFrame = true
            }
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
