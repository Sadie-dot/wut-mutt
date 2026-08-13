// The REVEAL-gate harness: runs the app's gate rules (DogSubject in
// CameraController.swift) over still photos using the Mac's own Vision
// stack — the simulator has no inference context, but the Mac does, so
// detection behavior can be probed without a device.
//
// Usage:  swiftc -O gatecheck.swift -o gatecheck && ./gatecheck <photos…>
//
// History (2026-08-12, open item #9): run over 29 real photos, everyday
// framing passed 26/29 with margins; the failures — a nose-boop face shot,
// a from-above scene, a camouflage sprawl — returned ZERO observations,
// which ruled out threshold/region tuning and motivated the classifier
// rescue (VNClassifyImageRequest fallback) now in DogSubject: the face
// shot classified dog at 0.62, the incidental-dog overhead at 0.11, and
// app-screenshot controls at zero, so 0.35 splits the cases cleanly.
import Foundation
import Vision

let region = CGRect(x: 0.12, y: 0.15, width: 0.76, height: 0.7)
let minConfidence: Float = 0.5
let classifierFloor: Float = 0.35

print("photo, detector, confidence, centered, classifier-dog, GATE")
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let animals = VNRecognizeAnimalsRequest()
    let classify = VNClassifyImageRequest()
    do { try VNImageRequestHandler(url: url).perform([animals, classify]) } catch {
        print("\(url.lastPathComponent), ERROR: \(error.localizedDescription)")
        continue
    }
    let dogs = (animals.results ?? []).compactMap { obs -> (Float, CGRect)? in
        guard let label = obs.labels.first(where: { $0.identifier == "Dog" })
        else { return nil }
        return (label.confidence, obs.boundingBox)
    }
    let best = dogs.max(by: { $0.0 < $1.0 })
    let centered = best.map { region.contains(CGPoint(x: $0.1.midX, y: $0.1.midY)) } ?? false
    let detected = (best?.0 ?? 0) > minConfidence && centered
    let cls = (classify.results ?? [])
        .filter { $0.identifier == "dog" || $0.identifier == "canine" }
        .map(\.confidence).max() ?? 0
    let rescued = cls > classifierFloor
    let conf = best.map { String(format: "%.2f", $0.0) } ?? "-"
    print("\(url.lastPathComponent), \(best != nil ? "dog" : "none"), \(conf), \(centered), \(String(format: "%.2f", cls)), \(detected || rescued ? "PASS" : "FAIL")")
}
