import SwiftUI

// The two credit surfaces, split out of the old single "End Credits" overlay.
//
// They live here rather than inside CurtainView because they must be reachable
// from anywhere: nothing in the app ever returns to `.curtain`, so an overlay
// presented only from that screen becomes unreachable the moment someone taps
// "Snap a pic". The AI disclosure in particular has to stay findable.

/// Shared chrome: full-bleed dimmed set, a fixed header whose close control
/// can't scroll away, and Close at the end of the scroll for good measure.
private struct CreditsScaffold<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            // Solid, not dimmed-through: at any transparency the curtain's
            // bright marks ghost into the content — its cream pills and footer
            // links landed right in the credits' Close zone, one real pill
            // among three phantoms.
            Color(hex: "#2B0616")

            VStack(spacing: 0) {
                // No backdrop-tap dismissal: this overlay is full-bleed, so
                // there is no "outside" to tap — every tap lands on content.
                ZStack {
                    Text(title)
                        .font(.italiana(28, relativeTo: .title))
                        .kerning(4)
                        .foregroundColor(.wmIce)
                        .shadow(color: Color.wmIce.opacity(0.5), radius: 9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        // Keep the centered title out of the close button's
                        // corner: at AX sizes it ran beneath the X
                        // (2026-08-22 audit), which also makes the X harder
                        // to hit. The fit-to-width shrink now happens inside
                        // this reservation.
                        .padding(.horizontal, 44)
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.wmIce)
                                .frame(width: 44, height: 44)
                                .overlay(Circle()
                                    .strokeBorder(Color.wmIce.opacity(0.7), lineWidth: 1.5))
                                .contentShape(Circle())
                        }
                        .accessibilityLabel("Close")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 30)
                // Pinned header chrome over a scrolling body: the body keeps
                // scaling into the AX range, the header takes the staged cap.
                .stagedType()

                ScrollView {
                    VStack(spacing: 26) {
                        content

                        OutlinePill(title: "Close", action: onClose)
                            .frame(width: 150)
                            .padding(.top, 8)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 60)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
        .zIndex(45)
    }
}

/// One section: a pink kicker over body copy.
private struct CreditsSection<Content: View>: View {
    let heading: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) {
            Text(heading)
                .font(.nunito(12, weight: .extraBold))
                .kerning(3)
                .foregroundColor(.wmPink)
            content
        }
    }
}

private func creditsBody(_ text: String) -> some View {
    Text(text)
        .font(.nunito(13, weight: .bold))
        .foregroundColor(.wmCream)
        .lineSpacing(4.4)
}

// MARK: - AI Disclosure

// Modeled on Lemon Pig's disclosure: how the app was made, where AI runs
// live, the AI-made artwork, the accessibility auditing, and who answers
// for all of it — each in its own section so nothing hides in a paragraph.
struct AIDisclosureOverlay: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        CreditsScaffold(title: "AI DISCLOSURE") { model.aiDisclosureOpen = false } content: {
            CreditsSection(heading: "THE PRODUCTION") {
                creditsBody("This app's look was designed with Claude Design, and it was built with Claude, Anthropic's AI assistant, via Claude Code. The script is a collaboration: Claude drafted copy throughout, and the developer wrote or heavily edited much of it — including the episode copy, the teasers, and the off-air cards. Breed reference photography comes from Wikimedia Commons contributors — see Image Credits.")
            }

            CreditsSection(heading: "THE BREED RESULTS") {
                creditsBody("Wut Mutt uses Claude live, in the app, to guess breeds from your photo and write everything on each breed's card — the tagline, clues, and fun fact — on the fly. The percentages describe how much of each breed shows in the photo, not ancestry — no photo can tell you that. Results are an educated guess for entertainment — not veterinary, genetic, or dramatic advice. Breed facts have not been independently fact-checked.")
            }

            // Deliberately repeated from Image Credits. Someone auditing what is
            // AI in this app shouldn't have to also read the cast list to find
            // out the portraits are generated.
            CreditsSection(heading: "THE CAST") {
                creditsBody("Tonight's star — the dog pictured on the opening screen — is AI-generated artwork, art-directed in Figma. A different star headlines each launch.")
            }

            CreditsSection(heading: "ACCESSIBILITY") {
                creditsBody("Claude Code was also used to audit and improve the app's accessibility, including VoiceOver support, text scaling, Reduce Motion, and tap target sizing.")
            }

            CreditsSection(heading: "THE DEVELOPER") {
                creditsBody("The developer directed the concept, design, and feature set, and reviewed the app's design and code before shipping. The developer is responsible for what's in this app, AI-assisted or not.")
            }
        }
    }
}

// MARK: - Image Credits

struct ImageCreditsOverlay: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        CreditsScaffold(title: "IMAGE CREDITS") { model.imageCreditsOpen = false } content: {
            CreditsSection(heading: "CAST — TONIGHT'S STARS") {
                Text("The Weeping Golden · The Aussie with a Secret\nThe Basset Who Knew Too Much\nThe Crested Heiress · The Brooding Staffie")
                    .font(.playfair(15, relativeTo: .body))
                    .foregroundColor(.wmCream)
                    .lineSpacing(12.75)
                Text("The dogs pictured on the opening screen.\nStar portraits are AI-generated artwork,\nart-directed in Figma. No real dogs were dramatized.")
                    .font(.nunito(12, weight: .bold))
                    .foregroundColor(Color.wmCream.opacity(0.75))
                    .lineSpacing(4)
            }

            CreditsSection(heading: "BREED PHOTOGRAPHY") {
                creditsBody("Reference photos are bundled with the app from Wikimedia Commons, under Creative Commons and public-domain licences. Tap any entry to open the original.")

                VStack(spacing: 0) {
                    // Alphabetical at display time — the data keeps the
                    // pipeline's catalog order, but a reader hunting one
                    // breed among 63 needs a predictable shelf.
                    ForEach(photoCredits.sorted {
                        $0.breed.localizedCaseInsensitiveCompare($1.breed) == .orderedAscending
                    }) { credit in
                        if let url = URL(string: credit.sourceURL) {
                            Link(destination: url) { creditRow(credit, linked: true) }
                                .accessibilityHint("Opens the original photo on Wikimedia Commons")
                        } else {
                            creditRow(credit, linked: false)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    /// Breed over photographer and licence. Every entry is credited, including
    /// the public-domain ones — see the note in PhotoCredits.swift.
    private func creditRow(_ credit: PhotoCredit, linked: Bool) -> some View {
        VStack(spacing: 1) {
            Text(credit.breed)
                .font(.nunito(13, weight: .bold))
                .foregroundColor(.wmCream)
            HStack(spacing: 4) {
                Text("\(credit.author) · \(credit.license)")
                    .font(.nunito(11, weight: .semiBold))
                    .foregroundColor(Color.wmCream.opacity(0.62))
                if linked {
                    // The tappability hint the intro sentence can't carry 63
                    // rows deep. VoiceOver already has the per-row hint.
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.wmCream.opacity(0.4))
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.wmCream.opacity(0.12))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
