import SwiftUI

/// Covers Claude latency with a soap beat: the captured photo pushes in
/// slowly while five teasers play (1.6s apiece — the 8s minimum), holding on
/// the last until the API answers.
struct AnalyzingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoomed = false

    var body: some View {
        let W = WMScreen.width
        let H = WMScreen.height

        ZStack {
            Color.wmRaspberry

            if let image = model.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H)
                    .clipped()
                    .scaleEffect(zoomed && !reduceMotion ? 1.12 : 1,
                                 anchor: .init(x: 0.55, y: 0.28))
                    .animation(.easeOut(duration: 14), value: zoomed)
                    .saturation(0.85)
                    .contrast(1.05)
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

                Text(model.teasers[model.teaserIdx])
                    .font(.playfair(24, bold: true, italic: true, relativeTo: .title2))
                    .foregroundColor(.wmCream)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .shadow(color: Color.wmNearBlack.opacity(0.95), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                    // Fixed-height pool prevents layout jumps between 1- and
                    // 2-line teasers.
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .shadowPool(opacity: 0.6)
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
        .onAppear { zoomed = true }
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
