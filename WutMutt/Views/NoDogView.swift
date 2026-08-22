import SwiftUI

/// The shocking twist: Claude says that's not a dog. Dimmed set, grayscale
/// mugshot of the offending photo in the results ring, the verdict in bold
/// cream, a note of forgiveness, then back to the plot.
struct NoDogView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let W = WMScreen.width
        let H = WMScreen.height

        ZStack {
            PolkaBackground(dotOpacity: 0.08,
                            colors: [.wmRaspberry, .wmDeep, .wmDimmedBase],
                            stops: [0, 0.5, 1])
            GlowPulse()

            VStack(spacing: 16) {
                // Balanced no-break spaces give the '?' swash room before the
                // text bounds clip it, without shifting the optical center.
                Text("\u{00A0}Wut?\u{00A0}")
                    .font(.greatVibes(60))
                    .foregroundColor(.wmIce)
                    .shadow(color: Color.wmIce.opacity(0.45), radius: 12)
                    // Great Vibes' ~1.23em line box against the design's
                    // line-height 1 — without this the mugshot rides ~14pt low.
                    .padding(.vertical, -7)
                    .accessibilityAddTraits(.isHeader)

                Text("UNHINGED BETRAYAL")
                    .font(.playfair(14, italic: true, relativeTo: .subheadline))
                    .kerning(4)
                    .foregroundColor(.wmPink)

                Hairline()

                // Mugshot of the imposter, in the results portrait's own ring
                // (the user's call after the prototype's tapering offset ring
                // kept reading as a mistake). Grayscale stays on the photo
                // alone so the ring keeps its ice.
                GildedCircle(diameter: 168) {
                    Group {
                        if let image = model.capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.wmDeep
                        }
                    }
                    .saturation(0)
                    .contrast(1.05)
                }
                .padding(.top, -6)
                .accessibilityLabel("Your photo, framed as the imposter's mugshot")

                // The verdict, in the old closer's bold cream — the one line
                // of news on the screen keeps the loudest body dress.
                Text("Clearly not a mutt")
                    .font(.playfair(19, bold: true, italic: true, relativeTo: .title3))
                    .foregroundColor(.wmCream)

                // The underline carries the instruction's whole point — the
                // photo the viewer just tried was, pointedly, not of a dog.
                (Text("Please use a new photo ")
                    + Text("of a dog").underline()
                    + Text(".\nThen repress this memory."))
                    .font(.playfair(16, italic: true, relativeTo: .body))
                    .foregroundColor(.wmPink)
                    .lineSpacing(6.5)

                Hairline(width: 80)

                SnapUploadRow(width: W - 72,
                              onSnap: { model.requestCameraThenHome() },
                              onUpload: { model.openPicker() })
                    .padding(.top, 10)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)

            // The sign-off: one word of dog closing the frame, same dress as
            // the off-air cards' — this was the last card-style ending left
            // over a dead band.
            Text("BOOP")
                .font(.playfair(12, relativeTo: .caption))
                .kerning(5)
                .foregroundColor(.wmPink)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 58)
                .accessibilityHidden(true)
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
        // Same fixed stage as OffAirView, same AX5 failure (BOOP over the
        // pills, truncated copy) — staged cap, per the policy on stagedType().
        .stagedType()
    }
}
