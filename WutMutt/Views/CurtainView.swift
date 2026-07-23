import SwiftUI

/// Opening / permission screen: the show's title card, tonight's star in a
/// gilded frame, and the Snap-a-pic / Upload pair. "Snap a pic" triggers the
/// real iOS camera permission prompt; "Upload" goes straight to the photo
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
            .frame(width: W - 68, height: H - 190 - 230)
            .frame(maxHeight: .infinity, alignment: .top)
            .offset(y: 190)
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
            HStack(spacing: 6) {
                Text("© 2026")
                Text("·")
                Button {
                    model.creditsOpen = true
                } label: {
                    Text("Credits & disclosures")
                        .underline()
                        .padding(.vertical, 6)
                }
                .foregroundColor(Color.wmCream.opacity(0.9))
            }
            .font(.nunito(12, weight: .bold))
            .foregroundColor(Color.wmCream.opacity(0.92))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 24)

            if model.creditsOpen {
                CreditsOverlay()
            }
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
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

/// End Credits: cast, AI disclosure, copyright.
struct CreditsOverlay: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Color(hex: "#2B0616").opacity(0.94)
            ScrollView {
                VStack(spacing: 26) {
                    Text("END CREDITS")
                        .font(.italiana(30, relativeTo: .title))
                        .kerning(5)
                        .foregroundColor(.wmIce)
                        .shadow(color: Color.wmIce.opacity(0.5), radius: 9)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 8) {
                        Text("CAST — TONIGHT'S STARS")
                            .font(.nunito(12, weight: .extraBold))
                            .kerning(3)
                            .foregroundColor(.wmPink)
                        Text("The Weeping Golden · The Aussie with a Secret\nThe Basset Who Knew Too Much\nThe Crested Heiress · The Brooding Staffie")
                            .font(.playfair(15, relativeTo: .body))
                            .foregroundColor(.wmCream)
                            .lineSpacing(6)
                        Text("Star portraits are AI-generated artwork,\nart-directed in Figma. No real dogs were dramatized.")
                            .font(.nunito(12, weight: .bold))
                            .foregroundColor(Color.wmCream.opacity(0.75))
                            .lineSpacing(3)
                    }

                    VStack(spacing: 8) {
                        Text("AI DISCLOSURE")
                            .font(.nunito(12, weight: .extraBold))
                            .kerning(3)
                            .foregroundColor(.wmPink)
                        Text("Breed guesses are generated by Claude, an AI model by Anthropic, from your photo. Results are an educated guess for entertainment — not veterinary, genetic, or dramatic advice. For real answers, ask a vet or a DNA test.")
                            .font(.nunito(13, weight: .bold))
                            .foregroundColor(.wmCream)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 8) {
                        Text("COPYRIGHT")
                            .font(.nunito(12, weight: .extraBold))
                            .kerning(3)
                            .foregroundColor(.wmPink)
                        Text("© 2026 Wut Mutt Productions.\nAll rights reserved. All dogs good.")
                            .font(.nunito(13, weight: .bold))
                            .foregroundColor(.wmCream)
                            .lineSpacing(4)
                    }

                    OutlinePill(title: "Close") { model.creditsOpen = false }
                        .frame(width: 150)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .padding(.top, 80)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea()
        .zIndex(45)
    }
}
