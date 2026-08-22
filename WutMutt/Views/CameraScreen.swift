import SwiftUI

/// The camera set: full-bleed feed, gilded viewfinder, and the
/// ALBUM / REVEAL / FLIP control row. REVEAL stays dim until Vision spots a
/// dog in the frame.
struct CameraScreen: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var camera = CameraController()

    var body: some View {
        let W = WMScreen.width
        let H = WMScreen.height

        ZStack {
            // Feed
            Color.wmNearBlack
            #if targetEnvironment(simulator)
            // No camera here, and a black void tells you nothing about the
            // shot. Show the same stand-in photo that capture() sends, under
            // the same grade as the live feed, so what you frame is what you
            // reveal — the viewfinder, the portrait, and Claude's read all
            // agree, and the detection beat has something to land on.
            if let stand = WMSimulator.standIn {
                Image(uiImage: stand)
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H)
                    .clipped()
                    .saturation(0.95)
                    .contrast(0.98)
                    .brightness(0.04)
            }
            #else
            CameraPreviewView(session: camera.session)
                .frame(width: W, height: H)
                .clipped()
                .saturation(0.95)
                .contrast(0.98)
                .brightness(0.04)
            #endif

            // Single consolidated overlay: top fade + raspberry vaseline vignette
            LinearGradient(stops: [
                .init(color: Color.wmNearBlack.opacity(0.9), location: 0),
                .init(color: Color.wmNearBlack.opacity(0.45), location: 0.08),
                .init(color: .clear, location: 0.2)
            ], startPoint: .top, endPoint: .bottom)
            RadialGradient(stops: [
                .init(color: .clear, location: 0.45),
                .init(color: Color.wmDeep.opacity(0.4), location: 0.78),
                .init(color: Color.wmDeep.opacity(0.85), location: 1)
            ], center: .init(x: 0.5, y: 0.42), startRadius: 0, endRadius: H * 0.62)
            GlowPulse(center: .init(x: 0.5, y: 0.3))

            // Gilded frame — StarFrame geometry, identical to the curtain's.
            //
            // Arrives with the dog rather than sitting there throughout. The
            // handoff has it permanent, as a "fit your dog here" guide, but it
            // never guided anything: capture is full-sensor and Vision re-crops,
            // so a rectangle that looks like a crop boundary was teaching a
            // model the app doesn't honor. Aiming is the caption's job now.
            //
            // What it earns instead is meaning. This is the same frame that
            // holds tonight's star on the curtain, so having it appear when
            // your star does reuses the motif — and it lands on the same 0.5s
            // curve as REVEAL brightening, so the two read as one beat.
            //
            // Same object means same measurements: it used to be 32pt narrower
            // and 14pt higher than the curtain's, so the motif landed slightly
            // off its mark on a screen you reach one tap later.
            GildedFrame { Color.clear }
                .frame(width: StarFrame.width, height: StarFrame.height)
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(y: StarFrame.topInset)
                .opacity(model.dogDetected ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: model.dogDetected)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // Caption on a feathered shadow pool, below the frame
            VStack(spacing: 5) {
                Text(model.dogDetected ? "Every pup has a story to tell…" : "Cue dramatic entrance")
                    .font(.playfair(18, italic: true, relativeTo: .body))
                    .foregroundColor(.wmCream)
                    // This shadow is load-bearing for contrast, not decor. The
                    // pool behind it feathers to nothing, so over a blown-out
                    // white feed the outermost glyphs sit on as little as
                    // ~0.5-alpha backing — cream on that alone is ~3.4:1,
                    // under the 4.5:1 floor. The shadow's halo carries the
                    // worst case to ~6.5:1 (measured 2026-08-22).
                    .shadow(color: Color.wmNearBlack.opacity(0.95), radius: 5, y: 2)
                // "Cue dramatic entrance" directs the dog, not the viewer — on
                // its own it never says why REVEAL is dimmed. A screenplay
                // parenthetical is the set's own register for stage direction,
                // so it can carry the instruction without breaking voice.
                // Leaves with the dog's arrival.
                //
                // Phrased as the action to take rather than the deficiency, and
                // says *centre* because that is what the gate actually checks:
                // DogSubject.region wants the dog's box centre inside the
                // middle of the shot, so "point the camera at it" could be
                // followed exactly, with the subject off to one side, and
                // REVEAL would stay dead. The region is generous (76% x 70%),
                // so this asks for a little more than strictly required — the
                // safe direction for an instruction to err.
                //
                // Says "dog" rather than the earlier "our star": point this at a
                // cat and the metaphor never tells you the gate wants a dog
                // specifically, so REVEAL just stays dead with no clue why.
                // Costs some of the show's voice; the parenthetical is the one
                // place in the app where being understood beats being in
                // character.
                //
                // "Body" asks for the whole animal, not the face. Vision's
                // detector is trained on animal bodies and boxes them as such,
                // so a head-filling shot gives it less to work with — and the
                // instinct when photographing a dog is to get closer. It also
                // matches what the portrait crop wants: faceCrop takes the top
                // of the *body* box, so a head-only box crops to a muzzle.
                //
                // Avoids "frame" deliberately: the gilded rectangle is decor,
                // not a crop boundary — capture is full-sensor and Vision
                // re-crops — so framing language would teach the wrong model.
                if !model.dogDetected {
                    Text("(center dog's body on screen)")
                        .font(.playfair(13, italic: true, relativeTo: .footnote))
                        .foregroundColor(Color.wmPink.opacity(0.9))
                        .shadow(color: Color.wmNearBlack.opacity(0.95), radius: 4, y: 1)
                }
                Hairline()
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .shadowPool()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 268)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)

            // Bottom controls — ALBUM / REVEAL / FLIP
            HStack(alignment: .center) {
                albumButton
                Spacer()
                revealButton
                Spacer()
                flipButton
            }
            .padding(.horizontal, 36)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 42)
            // The REVEAL disc is fixed geometry: at AX5 its label wrapped to
            // "REV / EAL" and spilled outside the circle while ALBUM and FLIP
            // crowded it (2026-08-22 audit). Control chrome, staged cap —
            // the caption band above scales on, its pool grows with it.
            .stagedType()
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
        .onAppear {
            #if !targetEnvironment(simulator)
            camera.start()
            #endif
        }
        .onDisappear { camera.stop() }
        .onReceive(camera.$dogInFrame) { seen in
            if seen { model.dogDetected = true }
        }
    }

    // MARK: Controls

    /// Mini Polaroid opening the photo library. The grayscale Chinese-crested
    /// print is part of the button's design (the app can't know the upload in
    /// advance).
    private var albumButton: some View {
        Button {
            model.openPicker()
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    StarPortrait(star: AppModel.Star(
                        asset: "star-chinese-crested", anchor: .init(x: 0.5, y: 0.2),
                        headline: "", nickname: ""))
                        .brightness(0.08)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.wmDeep))
                }
                .padding(EdgeInsets(top: 4, leading: 4, bottom: 12, trailing: 4))
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.wmCream))
                .rotationEffect(.degrees(-5))
                .shadow(color: Color.wmDeep.opacity(0.55), radius: 4, y: 3)

                Text("ALBUM")
                    .font(.nunito(12, weight: .extraBold))
                    .kerning(2)
                    .foregroundColor(.wmPink)
                    .shadow(color: Color.wmDeep.opacity(0.9), radius: 2, y: 1)
            }
        }
        .accessibilityLabel("Album — pick a photo from your library")
    }

    private var revealButton: some View {
        Button {
            guard model.dogDetected else { return }
            capture()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.wmIce)
                    .frame(width: 92, height: 92)
                Text("REVEAL")
                    .font(.playfair(15, bold: true))
                    .kerning(2)
                    .foregroundColor(.wmDeep)
            }
            .overlay(Circle().stroke(Color.wmDeep.opacity(0.6), lineWidth: 3).frame(width: 95, height: 95))
            .overlay(Circle().stroke(Color.wmIce.opacity(0.75), lineWidth: 2).frame(width: 100, height: 100))
            .shadow(color: Color.wmIce.opacity(model.dogDetected ? 0.5 : 0), radius: 17)
        }
        .modifier(ButtonPulse(active: model.dogDetected))
        .opacity(model.dogDetected ? 1 : 0.3)
        .saturation(model.dogDetected ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.5), value: model.dogDetected)
        .accessibilityLabel(model.dogDetected
                            ? "Reveal — capture and analyze"
                            : "Reveal, disabled — waiting for a dog in frame")

    }

    private var flipButton: some View {
        Button {
            camera.flip()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.wmCream.opacity(0.12))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().strokeBorder(Color.wmCream.opacity(0.7), lineWidth: 2))
                    // The design specifies ⟳ (U+27F3, one gapped circle arrow)
                    // at 30px. arrow.clockwise is its SF Symbol twin — a single
                    // arrowhead, same thin stroke — where the literal glyph
                    // would risk font fallback. Was arrow.triangle.2.circlepath,
                    // the double-headed refresh mark, which reads heavier and
                    // busier than the reference at this size.
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.wmCream)
                }
                Text("FLIP")
                    .font(.nunito(12, weight: .extraBold))
                    .kerning(2)
                    .foregroundColor(.wmPink)
                    .shadow(color: Color.wmDeep.opacity(0.9), radius: 2, y: 1)
            }
        }
        .accessibilityLabel("Flip camera")
    }

    private func capture() {
        #if targetEnvironment(simulator)
        // No camera in the simulator — send the stand-in that's on screen.
        if let stand = WMSimulator.standIn {
            model.startScan(with: stand)
        }
        #else
        camera.capture { image in
            if let image {
                model.startScan(with: image)
            }
        }
        #endif
    }
}

#if targetEnvironment(simulator)
/// The photo that plays the part of the camera when there isn't one.
///
/// A real dog in real light, not one of the cast portraits: those are AI
/// renders, so identifying them was Claude reading its own kind of image, and
/// the results said more about the render than about the pipeline. This one
/// has the things a phone actually hands us — motion, mixed shade, a subject
/// that fills the frame — so what the simulator shows is worth believing.
///
/// Don't crop it tighter. The source photo is 4:3 landscape; this is a 1040x1200
/// portrait cut of it, which is about as close as you can get before
/// VNRecognizeAnimalsRequest stops finding the dog at all. Trimming another
/// 200pt off the width — still a full head, still obviously a dog to a person —
/// took detection from 0.75 confidence to zero results, which silently costs
/// the Vision-cropped portrait on the results screen. The detector wants body,
/// not face.
///
/// Excluded from Release in Config.xcconfig, so it never leaves this machine
/// in a build. Optional on purpose: without the file the viewfinder is simply
/// black and REVEAL does nothing, which is the old behavior, not a crash.
enum WMSimulator {
    // By explicit path, not UIImage(named:). That lookup finds the loose
    // star-*.png files by bare name, but returns nil for this .jpg — it
    // resolves extensionless names against the asset catalog and PNG, so the
    // photo was in the bundle and the viewfinder was still black.
    static let standIn: UIImage? = Bundle.main
        .url(forResource: "sim-stand-in", withExtension: "jpg")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap(UIImage.init(data:))
}
#endif
