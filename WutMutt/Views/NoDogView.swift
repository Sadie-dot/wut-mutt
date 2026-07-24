import SwiftUI

/// The shocking twist: Claude says that's not a dog. Dimmed set, grayscale
/// mugshot of the offending photo, three-beat story, then back to the plot.
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
                Text("Wut?")
                    .font(.greatVibes(60))
                    .foregroundColor(.wmIce)
                    .shadow(color: Color.wmIce.opacity(0.45), radius: 12)
                    .accessibilityAddTraits(.isHeader)

                Text("UNHINGED BETRAYAL")
                    .font(.playfair(14, italic: true, relativeTo: .subheadline))
                    .kerning(4)
                    .foregroundColor(.wmPink)

                Hairline()

                // Mugshot of the imposter
                // 156pt photo + 6pt ring each side
                GildedCircle(diameter: 168, ringWidth: 6) {
                    if let image = model.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .saturation(0)
                            .contrast(1.05)
                    } else {
                        Color.wmDeep
                    }
                }
                .overlay(Circle().strokeBorder(Color.wmDeep, lineWidth: 3).padding(6))
                .padding(.top, -6)
                .accessibilityLabel("Mugshot of our mystery guest")

                VStack(spacing: 12) {
                    Text("OUR MYSTERY GUEST…")
                        .font(.playfair(12, relativeTo: .caption))
                        .kerning(4)
                        .foregroundColor(.wmPink)
                    Text("May be a ghost… perhaps a crime lord…\nor even an interior decorator\nwho is also a heart surgeon.")
                        .font(.playfair(16, italic: true, relativeTo: .body))
                        .foregroundColor(.wmPink)
                        .lineSpacing(5)
                    Text("The story is out, and this imposter\nis not a mutt.")
                        .font(.playfair(19, bold: true, italic: true, relativeTo: .title3))
                        .foregroundColor(.wmCream)
                        .lineSpacing(4)
                        .padding(.bottom, -4)
                }

                Hairline(width: 80)

                Text("Try a new plot.")
                    .font(.playfair(16, italic: true, relativeTo: .body))
                    .foregroundColor(.wmCream)

                SnapUploadRow(width: W - 72,
                              onSnap: { model.requestCameraThenHome() },
                              onUpload: { model.openPicker() })
                    .padding(.top, 10)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
    }
}
