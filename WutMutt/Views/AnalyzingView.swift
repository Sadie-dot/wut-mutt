import SwiftUI

/// Covers Claude latency with a soap beat: the captured photo pushes in
/// slowly while five teasers play (1.6s apiece — the 8s minimum), holding on
/// the last until the API answers.
struct AnalyzingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Push triggers, one per sharp rendering. Since the backdrop opens on
    /// the blur, BOTH sharp renderings are inserted after the screen
    /// appears — a shared appear-time flag would materialize them pre-zoomed
    /// at their final scale with no visible travel (each branch found this
    /// out separately on device). Each rendering's own onAppear starts its
    /// journey at its own insertion.
    @State private var fillZoomed = false
    @State private var tightZoomed = false

    /// Where the subject should land on screen. Not the geometric middle:
    /// the teaser block owns the bottom third, so a subject aimed at true
    /// center can end up under the caption (a curled-up sleeper's head did
    /// exactly that on device). The stage sits where the vignette and the
    /// push-in anchor already point — about a third down.
    private static let stage = CGPoint(x: 0.5, y: 0.36)

    /// How far to shift the filled backdrop so the dog sits on the stage —
    /// the slack between the filled image and the screen, spent toward the
    /// aim point and clamped at the edges. Zero until the box arrives, and
    /// zero slack on an axis means the photo is shown whole there already.
    ///
    /// Known and accepted (the user's call, 2026-08-13): landscape captures
    /// bind on height, so vertical slack is zero and a head low in the
    /// photo sits low on screen, dimmed under the caption band. Buying
    /// vertical room out of the push-in's 1.12 was considered and declined —
    /// the pan and the push run on different clocks, and an eager offset
    /// could expose a content edge for the vignette to (mostly) hide.
    /// Portrait captures, the common case, aim on both axes.
    private func aimOffset(for image: UIImage, W: CGFloat, H: CGFloat) -> CGSize {
        // The head pose is the aim when it exists — centering a long dog's
        // BOX centers the body and pushes the head off-frame (the cushion
        // crime scene proved it). The box's middle is the fallback.
        guard let target = model.dogFocus
            ?? model.dogBox.map({ CGPoint(x: $0.midX, y: $0.midY) })
        else { return .zero }
        let iw = image.size.width, ih = image.size.height
        guard iw > 0, ih > 0 else { return .zero }
        let scale = max(W / iw, H / ih)
        let dw = iw * scale, dh = ih * scale
        let dx = min(max((Self.stage.x - 0.5) * W - (target.x - 0.5) * dw,
                         -(dw - W) / 2), (dw - W) / 2)
        let dy = min(max((Self.stage.y - 0.5) * H - (target.y - 0.5) * dh,
                         -(dh - H) / 2), (dh - H) / 2)
        return CGSize(width: dx, height: dy)
    }

    /// The teaser pool, on the same Dynamic Type curve as the teaser's font.
    /// It was a fixed 96, which held two lines at the default size and
    /// silently starved the type everywhere above it — a height-starved Text
    /// truncates mid-word, and "The look in those puppy eyes hasn't been the
    /// sa…" is how a user's phone actually rendered it. Scaling the pool with
    /// the type keeps the no-layout-jump guarantee at every size instead of
    /// only the one the number was tuned at.
    @ScaledMetric(relativeTo: .title2) private var teaserPool: CGFloat = 96

    var body: some View {
        let W = WMScreen.width
        let H = WMScreen.height

        ZStack {
            Color.wmRaspberry

            if let image = model.capturedImage {
                // The opening shot is always the blur: the look pass hasn't
                // answered yet, and committing to sharp fill or letterbox
                // before it does meant flashing the wrong mode for tight
                // shots. The blur stays up as the letterbox's backing; for
                // normal shots it dissolves into the aimed fill — the
                // picture resolving mid-analysis, which is the beat anyway.
                if !model.lookFinished || model.tightShot {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: W, height: H)
                        .clipped()
                        .blur(radius: 26)
                        .saturation(0.85)
                        .transition(.opacity)
                }
                if model.lookFinished, model.tightShot {
                    // The capture is already a face — the classifier rescue
                    // admits shots the detector can't see a whole dog in.
                    // Letterboxed whole, with the same slow push-in as the
                    // fill (1.12; subtler cuts read as static on device).
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: W, height: H)
                        .scaleEffect(tightZoomed && !reduceMotion ? 1.12 : 1)
                        .animation(.easeOut(duration: 14), value: tightZoomed)
                        .saturation(0.85)
                        .contrast(1.05)
                        .transition(.opacity)
                        .onAppear { tightZoomed = true }
                }
                if model.lookFinished, !model.tightShot {
                    // The fill is aimed, not centered: same philosophy as the
                    // share card — spend the fill's slack bringing the dog to
                    // the middle, clamped so no edge ever pulls into frame. A
                    // face at the photo's edge otherwise gets lopped by the
                    // center crop (a device reveal caught exactly that).
                    let aim = aimOffset(for: image, W: W, H: H)
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: W, height: H)
                            .offset(aim)
                    }
                    .frame(width: W, height: H)
                    .clipped()
                    .scaleEffect(fillZoomed && !reduceMotion ? 1.12 : 1,
                                 anchor: .init(x: 0.55, y: 0.28))
                    .animation(.easeOut(duration: 14), value: fillZoomed)
                    .saturation(0.85)
                    .contrast(1.05)
                    .transition(.opacity)
                    .onAppear { fillZoomed = true }
                }
            }

            // Heavy raspberry vignette
            RadialGradient(stops: [
                .init(color: .clear, location: 0.2),
                .init(color: Color.wmDeep.opacity(0.75), location: 0.7),
                .init(color: Color.wmDeep.opacity(0.98), location: 1)
            ], center: .init(x: 0.5, y: 0.35), startRadius: 0, endRadius: H * 0.62)

            GlowPulse(duration: 2.5, center: .init(x: 0.5, y: 0.3), opacity: 0.18)

            // Teaser block — bottom 90
            VStack(spacing: 18) {
                Hairline(width: 60)

                Text(model.currentTeaser)
                    .font(.playfair(24, bold: true, italic: true, relativeTo: .title2))
                    .foregroundColor(.wmCream)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .shadow(color: Color.wmNearBlack.opacity(0.95), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                    // Backstop for the accessibility range, where even the
                    // scaled pool can meet a three-line teaser: shrink a
                    // little before ever truncating — a cut-off tease is the
                    // one thing this screen must not do.
                    .minimumScaleFactor(0.85)
                    // The pool prevents layout jumps between 1- and 2-line
                    // teasers; scaled, not fixed — see `teaserPool`.
                    .frame(height: teaserPool)
                    .frame(maxWidth: .infinity)
                    .shadowPool(opacity: 0.6, midOpacity: 0.45, radiusFraction: 0.9)
                    .accessibilityAddTraits(.updatesFrequently)

                BobbingDots()

                Text("BEGGING FOR THE ANSWER")
                    .font(.playfair(12, relativeTo: .caption))
                    .kerning(5)
                    .foregroundColor(.wmPink)
            }
            .padding(.horizontal, 40)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 90)
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
        // The tight-shot verdict and the aim box arrive a beat after the
        // screen does (the Vision pass runs with the episode). The mode swap
        // is a slow dissolve (explicit .opacity transitions on both
        // renderings — a 0.45s swap still read as a pop on device); the aim
        // glides — a slow easeInOut pan toward the dog reads as a camera
        // move beside the 14s push-in. Scoped to those values.
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.0),
                   value: model.tightShot)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.0),
                   value: model.lookFinished)
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.2),
                   value: model.dogBox)
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.2),
                   value: model.dogFocus)
    }
}

/// Three ice-blue dots bobbing on a 1.2s stagger; still under Reduce Motion.
struct BobbingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.wmIce)
                    .frame(width: 8, height: 8)
                    .opacity(reduceMotion ? 1 : (up ? 1 : 0.35))
                    .offset(y: up && !reduceMotion ? -8 : 0)
                    .animation(reduceMotion ? nil :
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                               value: up)
            }
        }
        .onAppear { if !reduceMotion { up = true } }
        .accessibilityHidden(true)
    }
}
