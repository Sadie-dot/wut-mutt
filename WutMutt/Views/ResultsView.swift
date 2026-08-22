import SwiftUI

/// The DNA-test reveal: gilded portrait, dramatic certainty meter, and the
/// cast of breeds. Sections enter with staggered fade-ups.
struct ResultsView: View {
    @EnvironmentObject private var model: AppModel

    /// `celebrate` design prop — shows the "a very good dog" badge.
    var celebrate = true

    var body: some View {
        ZStack {
            Color.wmCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                        .fadeUp(delay: 0)
                    portrait
                        .fadeUp(delay: 0.1)
                    twistQuote
                        .fadeUp(delay: 0.2)
                    // Breeds first, then the dial. The cast is the answer; how
                    // sure we are about it is the footnote, and a gauge reads
                    // as a verdict on what precedes it rather than a preamble.
                    castCard
                        .fadeUp(delay: 0.25)
                    certaintyCard
                        .fadeUp(delay: 0.3)
                    actions
                        .fadeUp(delay: 0.35)

                    VStack(spacing: 10) {
                        Text("Juicy guess powered by Claude. Not a DNA test.")
                            .font(.nunito(12, weight: .bold))
                            .foregroundColor(.wmFinePrint)
                            .padding(.horizontal, 20)
                        // The disclosure belongs on the sentence that makes the
                        // claim — and this is the only other place it can live,
                        // since nothing ever returns to the curtain.
                        CreditsLinks(tint: .wmFinePrint)
                    }
                    .padding(.top, 4)
                }
                .padding(EdgeInsets(top: 64, leading: 24, bottom: 44, trailing: 24))
            }
            // The design's 64pt top and 44pt bottom paddings measure to the
            // physical screen edges, so don't stack the safe-area insets.
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("IT'S TIME FOR AN ANSWER")
                .font(.playfair(12, relativeTo: .caption))
                .kerning(5)
                .foregroundColor(.wmLabel)
            Text("The mutt is…")
                .font(.greatVibes(52))
                .foregroundColor(.wmAccent)
                // Great Vibes carries a ~1.23em line box; the design sets
                // line-height 1, so trim the half-leading off both ends —
                // the top pull seats the script against the kicker, the
                // bottom one keeps the hairline and portrait on their marks.
                .padding(.vertical, -6)
                .accessibilityAddTraits(.isHeader)
            Hairline(width: 80)
        }
        .padding(.top, 10)
    }

    private var portrait: some View {
        // 210pt photo + 7pt ring each side, per the prototype's box model
        GildedCircle(diameter: 224) {
            if let image = model.portraitImage ?? model.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.wmTrack
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if celebrate {
                // The badge keeps the handoff's placement — a tabloid sticker
                // over the portrait is the right instinct for this app. The
                // pennant's notched ends already give it a silhouette the ring
                // can't be confused with, so it carries no outline: an edge on
                // top of the notches was one contour too many.
                //
                // The horizontal padding clears the notch, not the edge. The V
                // bites ~21pt in at the midline, where the text sits, so 22pt
                // left the outer glyphs a point shy of the point.
                Text(model.shareBadge)
                    .font(.playfair(15, bold: true, italic: true, relativeTo: .subheadline))
                    .foregroundColor(.wmCream)
                    .lineLimit(1)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 7)
                    .background(RibbonBadge().fill(Color.wmAccent))
                    .shadow(color: Color(hex: "#6E1E33").opacity(0.4), radius: 7, y: 4)
                    .rotationEffect(.degrees(-6))
                    .offset(x: 17, y: 1)
                    // The pennant's fold geometry assumes one modest line —
                    // at AX5 the notches ballooned into a bowtie covering the
                    // whole portrait (2026-08-22 audit). Decorative sticker,
                    // staged cap.
                    .stagedType()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your mutt's portrait\(celebrate ? " — \(model.shareBadge)" : "")")
    }

    private var twistQuote: some View {
        // A cast of one gets its own twist — "1 breeds all along" is the
        // grammar the accuracy-first prompt would otherwise produce. The
        // word is "fancy", not "purebred": the user keeps registry language
        // out of the storyline — the show's voice does not do kennel clubs.
        (model.breeds.count == 1
         ? (Text("“In a twist no one saw coming…\nfur baby was ")
            + Text("fancy").bold().foregroundColor(.wmAccent)
            + Text(" all along.”"))
         : (Text("“In a twist no one saw coming…\nfur baby was ")
            + Text("\(model.breedCountWord) breeds").bold().foregroundColor(.wmAccent)
            + Text(" all along.”")))
            .font(.playfair(16, italic: true, relativeTo: .body))
            .foregroundColor(.wmBodyText2)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.horizontal, 10)
    }

    private var certaintyCard: some View {
        VStack(spacing: 4) {
            Text("HOW SURE ARE WE?")
                .font(.playfair(12, relativeTo: .caption))
                .kerning(3)
                .foregroundColor(.wmLabel)
            CertaintyGauge(value: model.certainty)
            // The dial has no numerals: the reading has always been the
            // adjective, not the figure, and putting "87" on a face labelled
            // "how sure" would invite a precision the guess doesn't have.
            Text(model.certaintyLabel)
                .font(.playfair(20, bold: true, italic: true, relativeTo: .title3))
                .foregroundColor(.wmAccent)
                .multilineTextAlignment(.center)
                // One line by design, and the line must win over the type
                // size: SwiftUI wraps before it scales, so without the
                // lineLimit the AX sizes broke the adjective mid-word
                // ("Devastatingl / y sure") and the scale factor never
                // engaged. The floor covers "Life-altering epiphany", the
                // widest label in the set, at AX5.
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18))
        .background(card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("How sure are we? \(model.certaintyLabel)")
        .accessibilityValue("\(model.certainty) percent")
    }

    private var castCard: some View {
        VStack(spacing: 0) {
            Text(model.castHeadline)
                .font(.playfair(12, bold: true, relativeTo: .caption))
                .kerning(3)
                .foregroundColor(.wmLabel)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(Array(model.breeds.enumerated()), id: \.element.id) { index, breed in
                BreedRow(breed: breed, isLead: index == 0) {
                    model.screen = .detail(index)
                }
            }

            // What the numbers mean, said where the numbers are. A percent
            // sign borrows DNA-test authority the figure doesn't have —
            // Claude reports how much of each breed is VISIBLE, not
            // ancestry. The user's line: "swapped baby" is the soap trope
            // for mystery parentage, so the gag itself carries the
            // ancestry-unknown subtext while the footer's "Not a DNA test"
            // keeps the literal job.
            Text("How much of each breed our swapped baby manifests.")
                .font(.playfair(12, italic: true, relativeTo: .caption))
                .foregroundColor(.wmLabel)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(card)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                model.shareOpen = true
            } label: {
                Text("Share the drama")
                    .font(.playfair(16, bold: true, relativeTo: .body))
                    .kerning(1)
                    .foregroundColor(.wmCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color.wmAccent))
                    .shadow(color: Color(hex: "#6E1E33").opacity(0.35), radius: 11, y: 8)
            }
            Button {
                model.requestCameraThenHome()
            } label: {
                Text("New diva")
                    .font(.playfair(16, bold: true, relativeTo: .body))
                    .kerning(1)
                    .foregroundColor(.wmAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(Capsule().strokeBorder(Color.wmAccent, lineWidth: 2))
                    .contentShape(Capsule())
            }
        }
        .padding(.top, 4)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.wmCard)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.wmBorder, lineWidth: 1))
            .shadow(color: Color(hex: "#6E1E33").opacity(0.08), radius: 12, y: 8)
    }
}

// MARK: - Breed row

struct BreedRow: View {
    let breed: Breed
    let isLead: Bool
    let open: () -> Void
    // Content surface: rows keep scaling into the accessibility range, but
    // the side-by-side name/percent line runs out of room there — the name
    // column gets too narrow for single words and broke them mid-word
    // ("Plott Houn / d", 2026-08-22 audit). At AX sizes the name takes the
    // full width and the percent moves to its own line beneath.
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: open) {
            VStack(spacing: 8) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        name.frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 16) {
                            pct
                            Spacer()
                            chevron
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        name.frame(maxWidth: .infinity, alignment: .leading)
                        pct
                        chevron
                    }
                }
                // Outlined like the covers' headline type, and for the same
                // reason: three of the four data colours are pale enough to
                // vanish against cream (yellow reads 1.3:1), so the edge is
                // what makes the bar a shape. It measures 12.8:1 on the track
                // and at least 3.2:1 against every fill.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.wmTrack)
                        Capsule()
                            .fill(breed.color)
                            .overlay(Capsule().strokeBorder(Color.wmHeading, lineWidth: 1))
                            .frame(width: geo.size.width * CGFloat(breed.pct) / 100)
                    }
                }
                .frame(height: 8)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        // Every row carries a separator in the design, last one included —
        // it lands on the card's 6pt bottom padding.
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.wmTrack).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(breed.name), \(breed.pct) percent")
        .accessibilityHint("Opens the character dossier")
    }

    private var name: some View {
        Text(breed.name)
            .font(.playfair(isLead ? 26 : 20, bold: true,
                            relativeTo: isLead ? .title2 : .body))
            .foregroundColor(.wmHeading)
            .multilineTextAlignment(.leading)
    }

    private var pct: some View {
        Text("\(breed.pct)%")
            .font(.playfair(isLead ? 24 : 18, bold: true,
                            relativeTo: isLead ? .title3 : .body))
            .foregroundColor(.wmLabel)
    }

    private var chevron: some View {
        Text("›")
            .font(.nunito(16, weight: .extraBold))
            .foregroundColor(.wmChevron)
    }
}

struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.wmRowPressed : .clear)
    }
}
