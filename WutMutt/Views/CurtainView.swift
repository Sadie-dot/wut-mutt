import SwiftUI

/// Opening / permission screen: the show's title card, tonight's star in a
/// gilded frame, and the Snap-a-pic / Album pair. "Snap a pic" triggers the
/// real iOS camera permission prompt; "Album" goes straight to the photo
/// picker (no camera permission needed).
struct CurtainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let W = WMScreen.width
        let H = WMScreen.height

        ZStack {
            PolkaBackground()
            GlowPulse()

            // Script logo — top 58
            VStack(spacing: 2) {
                Text("WUT MUTT")
                    .font(.italiana(40, relativeTo: .largeTitle))
                    .kerning(5)
                    .foregroundColor(.wmIce)
                    .shadow(color: Color.wmIce.opacity(0.6), radius: 11)
                    .shadow(color: Color.wmDeep.opacity(0.6), radius: 2, y: 2)
                    .accessibilityAddTraits(.isHeader)
                Text("THE BREEDS OF OUR LIVES")
                    .font(.playfair(14, italic: true, relativeTo: .subheadline))
                    .kerning(4)
                    .foregroundColor(.wmPink)
                    // The wordmark's own ground shadow: the tagline sits in
                    // the glow's brightest band and measured 4.29:1 bare —
                    // under the small-text floor its 14pt is held to.
                    .shadow(color: Color.wmDeep.opacity(0.75), radius: 2, y: 1)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(y: 58)
            .accessibilityElement(children: .combine)

            // Tonight's star — gilded frame, top 190 / sides 34 / bottom 230
            GildedFrame {
                ZStack(alignment: .bottom) {
                    StarPortrait(star: model.star)
                        .padding(8)
                    // Full-width scrim over the portrait's lower third
                    LinearGradient(stops: [
                        .init(color: Color.wmDeep.opacity(0), location: 0.48),
                        .init(color: Color.wmDeep.opacity(0.55), location: 0.70),
                        .init(color: Color.wmDeep.opacity(0.94), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                        .padding(8)
                    // Tabloid headline block
                    VStack(spacing: 10) {
                        Hairline()
                        Text(model.star.headline.uppercased())
                            .font(.italiana(40, relativeTo: .title))
                            .kerning(3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .scaleEffect(y: 1.18)
                            .rotationEffect(.degrees(-3))
                            .shadow(color: Color.wmDeep.opacity(0.9), radius: 9)
                            .shadow(color: Color.wmDeep.opacity(0.85), radius: 0, y: 2)
                        Text("The moment you've been waiting for…")
                            .font(.playfair(14, relativeTo: .subheadline))
                            .foregroundColor(.wmCream)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .shadow(color: Color.wmDeep.opacity(0.95), radius: 3, y: 1)
                        Hairline()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
            }
            .frame(width: StarFrame.width, height: StarFrame.height)
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(y: StarFrame.topInset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tonight's star: \(model.star.nickname). \(model.star.headline)")

            // Action block — bottom 72, side insets 30
            VStack(spacing: 12) {
                (Text("The camera ") + Text("almost").underline() + Text(" never lies."))
                    .font(.playfair(16, italic: true, relativeTo: .body))
                    .foregroundColor(.wmCream)
                    .padding(.bottom, 10)
                SnapUploadRow(width: W - 60,
                              onSnap: { model.requestCameraThenHome() },
                              onUpload: { model.openPicker() })
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 72)

            // Footer — pinned above the home indicator
            CreditsLinks(tint: Color.wmCream.opacity(0.92))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 24)
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
        // Five independently pinned layers on one stage: at accessibility
        // sizes they grow into each other (the AX5 audit had the tagline
        // over the curtain and the footer links stealing taps aimed at
        // "Snap a pic"), so the whole screen takes the staged cap.
        .stagedType()
    }
}

/// One of the five grayscale cast portraits, cropped to its art-directed
/// position (CSS object-position ported to an offset within the frame).
struct StarPortrait: View {
    let star: AppModel.Star
    var grayscale = true   // `starGrayscale` design prop, default on

    var body: some View {
        GeometryReader { geo in
            let frame = geo.size
            if let ui = UIImage(named: star.asset) {
                let scale = max(frame.width / ui.size.width, frame.height / ui.size.height)
                let display = CGSize(width: ui.size.width * scale, height: ui.size.height * scale)
                Image(uiImage: ui)
                    .resizable()
                    .frame(width: display.width, height: display.height)
                    .offset(x: (frame.width - display.width) * star.anchor.x,
                            y: (frame.height - display.height) * star.anchor.y)
                    .saturation(grayscale ? 0 : 1)
                    .contrast(grayscale ? 1.05 : 1)
            }
        }
        .clipped()
    }
}
