import SwiftUI
import UIKit

/// Share the drama: gossip-card preview over a blurred backdrop, with four
/// share targets. Every target invokes the iOS share sheet with the rendered
/// card image, per the handoff (the circles are the design's share row).
struct ShareOverlay: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false
    @State private var shareItem: ShareItem?

    var body: some View {
        let W = WMScreen.width

        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.wmDeep.opacity(0.82))
                .ignoresSafeArea()
                .onTapGesture { model.shareOpen = false }

            VStack(spacing: 18) {
                ShareCardView(model: model)
                    .frame(width: W - 64)
                    .scaleEffect(reduceMotion ? 1 : (popped ? 1 : 0.6))
                    .opacity(reduceMotion ? 1 : (popped ? 1 : 0))

                HStack(spacing: 18) {
                    shareTarget(label: "MESSAGES", filled: true) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    shareTarget(label: "STORIES", filled: true) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).strokeBorder(lineWidth: 2)
                                .frame(width: 20, height: 20)
                            Circle().strokeBorder(lineWidth: 2)
                                .frame(width: 10, height: 10)
                        }
                    }
                    shareTarget(label: "SAVE", filled: true) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .offset(y: -1)
                    }
                    shareTarget(label: "MORE", filled: false) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                    }
                }

                Button {
                    model.shareOpen = false
                } label: {
                    Text("Close")
                        .font(.playfair(15, bold: true, relativeTo: .body))
                        .foregroundColor(.wmCream)
                        .padding(.horizontal, 54)
                        .padding(.vertical, 12)
                        .overlay(Capsule().strokeBorder(Color.wmCream.opacity(0.75), lineWidth: 2))
                        .contentShape(Capsule())
                }
            }
            .padding(.horizontal, 32)
        }
        .zIndex(30)
        .onAppear {
            if reduceMotion { popped = true }
            else { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { popped = true } }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.image])
        }
    }

    private func shareTarget<Icon: View>(label: String, filled: Bool,
                                         @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            share()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if filled {
                        Circle().fill(Color.wmIce).frame(width: 52, height: 52)
                    } else {
                        Circle().strokeBorder(Color.wmIce.opacity(0.7), lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                    icon().foregroundColor(filled ? .wmDeep : .wmIce)
                }
                Text(label)
                    .font(.nunito(12, weight: .extraBold))
                    .kerning(1)
                    .foregroundColor(.wmPink)
            }
        }
        .accessibilityLabel("Share via \(label.capitalized)")
    }

    /// Renders the gossip card at 3× and hands it to the system share sheet.
    @MainActor private func share() {
        let renderer = ImageRenderer(content:
            ShareCardView(model: model)
                .frame(width: 340)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareItem = ShareItem(image: image)
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - The gossip card

struct ShareCardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            // Raspberry header
            VStack(spacing: 2) {
                Text("The mutt is…")
                    .font(.greatVibes(30))
                    .foregroundColor(.wmIce)
                Text(model.shareKicker)
                    .font(.playfair(12, relativeTo: .caption))
                    .kerning(4)
                    .foregroundColor(.wmCream)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(LinearGradient.wmHero)

            if let image = model.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }

            VStack(spacing: 12) {
                Text(model.shareTitle)
                    .font(.playfair(20, bold: true, italic: true, relativeTo: .title3))
                    .foregroundColor(.wmHeading)
                    .multilineTextAlignment(.center)

                // Stacked mix bar — one segment per breed, in its data color
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(model.breeds) { breed in
                            Rectangle()
                                .fill(breed.color)
                                .frame(width: geo.size.width * CGFloat(breed.pct) / 100)
                        }
                    }
                }
                .frame(height: 14)
                .clipShape(Capsule())
                .accessibilityLabel("Breed mix: " + model.breeds.map { "\($0.name) \($0.pct) percent" }.joined(separator: ", "))

                Text(model.shareOthers)
                    .font(.playfair(13, italic: true, relativeTo: .footnote))
                    .foregroundColor(.wmBodyText2)
                    .multilineTextAlignment(.center)

                Text("WUTMUTT.APP")
                    .font(.nunito(12, weight: .extraBold))
                    .kerning(2)
                    .foregroundColor(.wmFinePrint)
            }
            .padding(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
        }
        .background(Color.wmCream)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.wmGold, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
    }
}

// MARK: - Share sheet

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
