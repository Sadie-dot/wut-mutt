import SwiftUI

/// The studio is dark: the daily cap is spent, the feed dropped, or the
/// reveal simply didn't make it to air. Built on the same dimmed set as the
/// shocking-twist screen so a failure still feels like part of the show —
/// but it says what actually happened instead of inventing an episode.
struct OffAirView: View {
    @EnvironmentObject private var model: AppModel
    let offAir: OffAir

    var body: some View {
        let W = WMScreen.width
        let H = WMScreen.height

        ZStack {
            PolkaBackground(dotOpacity: 0.08,
                            colors: [.wmRaspberry, .wmDeep, .wmDimmedBase],
                            stops: [0, 0.5, 1])
            GlowPulse()

            VStack(spacing: 16) {
                // Balanced no-break spaces give Great Vibes' swashes room
                // before the text bounds clip them, as on the twist screen.
                Text("\u{00A0}\(offAir.headline)\u{00A0}")
                    .font(.greatVibes(52))
                    .foregroundColor(.wmIce)
                    .shadow(color: Color.wmIce.opacity(0.45), radius: 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.vertical, -6)
                    .accessibilityAddTraits(.isHeader)

                Text(offAir.kicker)
                    .font(.playfair(14, italic: true, relativeTo: .subheadline))
                    .kerning(4)
                    .foregroundColor(.wmPink)
                    .multilineTextAlignment(.center)

                Hairline()

                // The disc — an off-air card needs something to look at where
                // the mugshot sits on the twist screen. Each card dresses it
                // for its own failure; the wrap card goes without, because
                // its whole statement is an emptied set.
                if offAir.centerpiece != .bare {
                    OffAirDisc {
                        switch offAir.centerpiece {
                        case .testPattern: TestPatternBars()
                        case .snow:        StaticSnow()
                        case .bare:        EmptyView()
                        }
                    }
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                }

                Text(offAir.message)
                    .font(.playfair(16, italic: true, relativeTo: .body))
                    .foregroundColor(.wmPink)
                    .lineSpacing(6.5)
                    .padding(.top, 4)

                Hairline(width: 80)

                switch offAir.action {
                case .retry:
                    // One action, plainly named: the same photo gets another
                    // take. The way out lives underneath as a quiet link —
                    // demoted, not deleted, because these buttons are the
                    // card's only navigation and a persistent outage would
                    // otherwise loop forever.
                    SnapPill(title: "Try that photo again") { model.retryScan() }
                        .frame(width: W - 72)
                        .padding(.top, 10)
                    Button { model.goHome() } label: {
                        Text("or go back to the camera")
                            .font(.playfair(15, italic: true, relativeTo: .subheadline))
                            .foregroundColor(.wmIce)
                            .underline()
                            .frame(minHeight: 44)   // full tap target despite the quiet look
                    }
                case .newShot:
                    Text("Try a fresh take.")
                        .font(.playfair(16, italic: true, relativeTo: .body))
                        .foregroundColor(.wmCream)
                    SnapUploadRow(width: W - 72,
                                  onSnap: { model.requestCameraThenHome() },
                                  onUpload: { model.openPicker() })
                        .padding(.top, 10)
                case .home:
                    // A dismissal, not a destination — the camera is capped
                    // out, so the button takes the show's leave rather than
                    // promising more of anything. It must exist (these
                    // buttons are the card's only navigation) and it must
                    // land in-app: iOS apps may not terminate themselves.
                    OutlinePill(title: "Air kisses") { model.goHome() }
                        .frame(width: 200)
                        .padding(.top, 14)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)

            // The sign-off: one word of dog, closing the bottom of the frame
            // where a station ident would sit. Without it the single-pill
            // cards end mid-screen over a dead band.
            // Dressed like the analyzing screen's "BEGGING FOR THE ANSWER" —
            // Playfair's strokes carry at caption size where Italiana's
            // hairlines dissolve.
            Text(offAir.signOff)
                .font(.playfair(12, relativeTo: .caption))
                .kerning(5)
                .foregroundColor(.wmPink)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 58)
                .accessibilityHidden(true)
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
    }
}

/// The card's 168pt disc: gilded ring, deep border, clipped content — the
/// same chrome the twist screen's mugshot wears, so every no-result screen
/// hangs the same frame and only the picture inside changes.
private struct OffAirDisc<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: 168, height: 168)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.wmDeep, lineWidth: 3))
            .background(
                Circle()
                    .fill(LinearGradient(
                        stops: [.init(color: .wmIceLight, location: 0),
                                .init(color: .wmIce, location: 0.45),
                                .init(color: .wmIceDeep, location: 1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(-6)
            )
            .frame(width: 168, height: 168)
    }
}

/// The real SMPTE color bars — top bars at 75%, the castellation strip, and
/// the PLUGE row. The disc is diegetic (a television picture, not app
/// chrome), so it wears broadcast colors, not the show's palette.
private struct TestPatternBars: View {
    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }
    /// 75% white, yellow, cyan, green, magenta, red, blue.
    private static let top: [Color] = [
        c(0.75, 0.75, 0.75), c(0.75, 0.75, 0), c(0, 0.75, 0.75), c(0, 0.75, 0),
        c(0.75, 0, 0.75), c(0.75, 0, 0), c(0, 0, 0.75),
    ]
    /// Castellations: reverse-order fragments under the bars.
    private static let mid: [Color] = [
        c(0, 0, 0.75), .black, c(0.75, 0, 0.75), .black, c(0, 0.75, 0.75), .black,
        c(0.75, 0.75, 0.75),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / 7
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(Self.top.enumerated()), id: \.offset) { _, color in
                        color.frame(width: w)
                    }
                }
                .frame(height: geo.size.height * 0.67)
                HStack(spacing: 0) {
                    ForEach(Array(Self.mid.enumerated()), id: \.offset) { _, color in
                        color.frame(width: w)
                    }
                }
                .frame(height: geo.size.height * 0.08)
                // PLUGE: -I, white, +Q, black at 1¼ widths each, then the
                // black-step trio in bar six and black to the edge.
                HStack(spacing: 0) {
                    Self.c(0, 0.13, 0.30).frame(width: w * 1.25)
                    Color.white.frame(width: w * 1.25)
                    Self.c(0.20, 0, 0.42).frame(width: w * 1.25)
                    Color.black.frame(width: w * 1.25)
                    Self.c(0.02, 0.02, 0.02).frame(width: w / 3)
                    Color.black.frame(width: w / 3)
                    Self.c(0.05, 0.05, 0.05).frame(width: w / 3)
                    Color.black
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Analog snow for the lost-feed card: a handful of pre-rolled noise frames
/// cycled the way a CRT rolls static, under faint scanlines, with the whole
/// field breathing an uneven flicker. Frames are pre-generated because true
/// per-frame randomness costs a full image a tick and six frames of snow are
/// indistinguishable from infinite ones.
private struct StaticSnow: View {
    /// 336px grayscale noise in a 168pt disc (0.5pt grain), kept crisp by
    /// `.interpolation(.none)`. Not salt-and-pepper: analog snow is a black
    /// field with sparse horizontal streaks — bright dashes a beam smears
    /// sideways — so each row is run-length generated: mostly black, a few
    /// dim dust specks, and occasional 2–7px streaks of near-white.
    private static let frames: [UIImage] = (0..<6).compactMap { _ in noiseFrame(side: 336) }
    /// Uneven on purpose — a steady pulse reads as design, not damage. High
    /// because the field is black; the streaks carry the brightness.
    private static let flicker: [Double] = [0.92, 0.78, 0.95, 0.72, 0.88, 0.82]

    private static func noiseFrame(side: Int) -> UIImage? {
        var bytes = [UInt8](repeating: 0, count: side * side)
        var i = 0
        while i < bytes.count {
            let roll = Int.random(in: 0..<1000)
            if roll < 60 {
                // A streak, clipped at the row edge so it can't wrap.
                let len = min(2 + Int.random(in: 0...5), side - (i % side))
                for j in 0..<len {
                    bytes[i + j] = UInt8(max(110, 150 + Int.random(in: 0...105) - Int.random(in: 0...40)))
                }
                i += len
            } else {
                if roll < 210 { bytes[i] = UInt8(Int.random(in: 30...80)) }  // dim dust
                i += 1
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cg = CGImage(width: side, height: side,
                               bitsPerComponent: 8, bitsPerPixel: 8,
                               bytesPerRow: side,
                               space: CGColorSpaceCreateDeviceGray(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                               provider: provider, decode: nil,
                               shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return UIImage(cgImage: cg)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                // WCAG 2.2.2: the OS toggle is the stop mechanism — one
                // frozen frame, no re-roll, no flicker, band parked mid-sweep.
                snowFrame(tick: 0, sweep: 0.33)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // The band glides a full sweep every 3.4s — a slower tempo
                    // than the 15fps grain, sampled on the same clock, so its
                    // slight judder reads as tracking, not jank.
                    snowFrame(tick: Int(t * 15),
                              sweep: (t / 3.4).truncatingRemainder(dividingBy: 1))
                }
            }
        }
        .background(Color.black)
    }

    private func snowFrame(tick: Int, sweep: Double) -> some View {
        ZStack {
            still(tick: tick)
            TrackingBand(sweep: sweep)
        }
    }

    @ViewBuilder
    private func still(tick: Int) -> some View {
        if Self.frames.isEmpty {
            TestPatternBars()   // noise generation can't really fail, but never show a hole
        } else {
            Image(uiImage: Self.frames[tick % Self.frames.count])
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .opacity(Self.flicker[tick % Self.flicker.count])
        }
    }
}

/// The VHS tracking artifact: one soft band, slightly brighter than the
/// field, drifting down the disc and wrapping — the analog tell that shows
/// on a black field where dark scanlines couldn't.
private struct TrackingBand: View {
    /// 0…1 sweep position, top to bottom, wrapping off both edges.
    var sweep: Double

    var body: some View {
        GeometryReader { geo in
            let bandHeight: CGFloat = 30
            let travel = geo.size.height + bandHeight * 2
            LinearGradient(stops: [.init(color: .white.opacity(0), location: 0),
                                   .init(color: .white.opacity(0.18), location: 0.5),
                                   .init(color: .white.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: bandHeight)
                .offset(y: -bandHeight + travel * CGFloat(sweep))
        }
    }
}
