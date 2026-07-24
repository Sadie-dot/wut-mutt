import SwiftUI

// Shared soap-opera set dressing: polka-dot curtain, gilded frames,
// hairlines, glow pulses, pill buttons, staggered fade-ups.

// MARK: - Backgrounds

/// Radial polka dots (3pt radius on a 34pt grid) over a vertical gradient.
struct PolkaBackground: View {
    var dotOpacity: Double = 0.20
    var colors: [Color] = [.wmRaspberryTop, .wmRaspberryMid, .wmRaspberry]
    var stops: [CGFloat] = [0, 0.55, 1]

    var body: some View {
        ZStack {
            LinearGradient(stops: zip(colors, stops).map { Gradient.Stop(color: $0.0, location: $0.1) },
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                let dot = Color(hex: "#FFF4EF").opacity(dotOpacity)
                var y: CGFloat = 0
                while y < size.height + 34 {
                    var x: CGFloat = 0
                    while x < size.width + 34 {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                                 with: .color(dot))
                        x += 34
                    }
                    y += 34
                }
            }
        }
    }
}

/// The pulsing pink glow overlay (4s ease-in-out loop on the set, 2.5s while analyzing).
struct GlowPulse: View {
    var duration: Double = 4
    var center: UnitPoint = .init(x: 0.5, y: 0.32)
    var opacity: Double = 0.14
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bright = false

    var body: some View {
        RadialGradient(colors: [Color.wmPink.opacity(opacity), Color.wmPink.opacity(0)],
                       center: center, startRadius: 0, endRadius: 320)
            .opacity(reduceMotion ? 0.72 : (bright ? 0.9 : 0.55))
            .animation(reduceMotion ? nil :
                        .easeInOut(duration: duration / 2).repeatForever(autoreverses: true),
                       value: bright)
            .onAppear { if !reduceMotion { bright = true } }
            .allowsHitTesting(false)
    }
}

// MARK: - Gilded frame

/// The star-frame treatment: 2pt ice border, deep-raspberry and ice inner
/// rings, outer glow. Content is clipped inside.
struct GildedFrame<Content: View>: View {
    var cornerRadius: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.wmIce.opacity(0.5), lineWidth: 8)
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.wmDeep.opacity(0.35), lineWidth: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color.wmIce.opacity(0.85), lineWidth: 2))
        .shadow(color: Color.wmIce.opacity(0.25), radius: 15)
    }
}

/// The gilded circular ring used for the results portrait and no-dog mugshot.
struct GildedCircle<Content: View>: View {
    var diameter: CGFloat
    var ringWidth: CGFloat = 7
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: diameter - ringWidth * 2, height: diameter - ringWidth * 2)
            .clipShape(Circle())
            .frame(width: diameter, height: diameter)
            .background(
                // Stops pulled forward so the ring hits full deep teal by its
                // right side — the reference's ring visibly recedes into the
                // set there instead of staying bright all the way around.
                Circle().fill(LinearGradient(
                    stops: [.init(color: .wmIceLight, location: 0),
                            .init(color: .wmIce, location: 0.35),
                            .init(color: .wmIceDeep, location: 0.72)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            )
    }
}

// MARK: - Small dressing

/// Ice-blue hairline: transparent → ice → transparent.
struct Hairline: View {
    var width: CGFloat = 54
    var body: some View {
        LinearGradient(colors: [.clear, .wmIce, .clear], startPoint: .leading, endPoint: .trailing)
            .frame(width: width, height: 1)
    }
}

/// Feathered "shadow pool" backing for text over photos — never a solid chip.
/// An oversized ellipse gradient clipped to the box, so it fills the banner's
/// full width and keeps fairly square vertical edges, per the prototype's
/// `radial-gradient(ellipse 90-100% …)` treatment.
struct ShadowPool: ViewModifier {
    var opacity: Double = 0.72
    var midOpacity: Double = 0.6
    var radiusFraction: CGFloat = 1.0

    func body(content: Content) -> some View {
        content.background(
            EllipticalGradient(stops: [
                .init(color: Color.wmNearBlack.opacity(opacity), location: 0),
                .init(color: Color.wmNearBlack.opacity(midOpacity), location: 0.55),
                .init(color: Color.wmNearBlack.opacity(0), location: 1)
            ], center: .center, startRadiusFraction: 0, endRadiusFraction: radiusFraction)
        )
    }
}

extension View {
    func shadowPool(opacity: Double = 0.72, midOpacity: Double = 0.6,
                    radiusFraction: CGFloat = 1.0) -> some View {
        modifier(ShadowPool(opacity: opacity, midOpacity: midOpacity,
                            radiusFraction: radiusFraction))
    }
}

/// The raspberry hero gradient (`linear-gradient(160deg, #D91F5C, #A3134A)`),
/// shared by the breed-detail hero and the share-card header.
extension LinearGradient {
    static let wmHero = LinearGradient(
        colors: [.wmAccent, .wmHeroGradEnd],
        startPoint: UnitPoint(x: 0.33, y: 0.03),
        endPoint: UnitPoint(x: 0.67, y: 0.97))
}

// MARK: - Motion

/// The set's 4s glow pulse applied to an existing view's opacity
/// (0.55 ↔ 0.9), steady under Reduce Motion.
struct PulsingOpacity: ViewModifier {
    var duration: Double = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bright = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 0.72 : (bright ? 0.9 : 0.55))
            .animation(reduceMotion ? nil :
                        .easeInOut(duration: duration / 2).repeatForever(autoreverses: true),
                       value: bright)
            .onAppear { if !reduceMotion { bright = true } }
    }
}

extension View {
    func glowPulseOpacity(duration: Double = 4) -> some View {
        modifier(PulsingOpacity(duration: duration))
    }
}

/// Gentle 3s scale pulse for primary buttons (1 → 1.06), off under Reduce Motion.
struct ButtonPulse: ViewModifier {
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(up ? 1.06 : 1)
            .animation(reduceMotion || !active ? nil :
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                       value: up)
            .onAppear { if !reduceMotion && active { up = true } }
            .onChange(of: active) { _, now in up = now && !reduceMotion }
    }
}

/// Staggered fade-up entrance (0.6s ease-out, translateY 14 → 0).
struct FadeUp: ViewModifier {
    var delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.easeOut(duration: 0.6).delay(delay)) { shown = true }
                }
            }
    }
}

extension View {
    func fadeUp(delay: Double) -> some View { modifier(FadeUp(delay: delay)) }
}

// MARK: - Pill buttons

/// Filled ice pill ("Snap a pic") with glow and gentle pulse.
struct SnapPill: View {
    var title: String
    var pulses: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.playfair(15, bold: true))
                .kerning(1)
                .foregroundColor(.wmDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14.5)
                .background(Color.wmIce)
                .clipShape(Capsule())
                .shadow(color: Color.wmIce.opacity(0.5), radius: 13)
        }
        .modifier(ButtonPulse(active: pulses))
    }
}

/// Outlined ice pill ("Upload" / "Close").
struct OutlinePill: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.playfair(15, bold: true))
                .kerning(1)
                .foregroundColor(.wmIce)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay(Capsule().strokeBorder(Color.wmIce.opacity(0.7), lineWidth: 1.5))
                .contentShape(Capsule())
        }
    }
}

/// The Snap-a-pic / Upload row (flex 1.4 : 1) shared by curtain and no-dog.
struct SnapUploadRow: View {
    var width: CGFloat
    var onSnap: () -> Void
    var onUpload: () -> Void

    var body: some View {
        let gap: CGFloat = 12
        let snapW = (width - gap) * 1.4 / 2.4
        HStack(spacing: gap) {
            SnapPill(title: "Snap a pic", action: onSnap)
                .frame(width: snapW)
            OutlinePill(title: "Upload", action: onUpload)
        }
        .frame(width: width)
    }
}
