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

                // The test pattern — an off-air card needs something to look at
                // where the mugshot sits on the twist screen.
                TestPattern()
                    .frame(width: 168, height: 168)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                Text(offAir.message)
                    .font(.playfair(16, italic: true, relativeTo: .body))
                    .foregroundColor(.wmPink)
                    .lineSpacing(6.5)
                    .padding(.top, 4)

                Hairline(width: 80)

                if offAir.retryable {
                    Text("Roll it again.")
                        .font(.playfair(16, italic: true, relativeTo: .body))
                        .foregroundColor(.wmCream)
                    HStack(spacing: 12) {
                        SnapPill(title: "Try again") { model.retryScan() }
                            .frame(width: (W - 72 - 12) * 1.4 / 2.4)
                        OutlinePill(title: "Back to the set") { model.goHome() }
                    }
                    .frame(width: W - 72)
                    .padding(.top, 10)
                } else {
                    OutlinePill(title: "Back to the set") { model.goHome() }
                        .frame(width: W - 72)
                        .padding(.top, 14)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
    }
}

/// A hint of an SMPTE test card, in the show's palette — the visual shorthand
/// for "we're off the air".
private struct TestPattern: View {
    private static let bars: [Color] = [
        .wmIce, .wmIceLight, .wmPink, .wmIceDeep, .wmAccent, .wmDeep, .wmDimmedBase
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(Self.bars.count)
            HStack(spacing: 0) {
                ForEach(Array(Self.bars.enumerated()), id: \.offset) { _, color in
                    color.frame(width: w)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .saturation(0.55)
        .opacity(0.75)
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
    }
}
