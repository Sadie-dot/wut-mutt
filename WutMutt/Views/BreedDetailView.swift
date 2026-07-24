import SwiftUI

/// Character dossier for one breed: raspberry hero, Polaroid headshot with a
/// trait rail (when a reference photo exists), photo clues, and a real fact.
struct BreedDetailView: View {
    @EnvironmentObject private var model: AppModel
    let breedIndex: Int

    private var breed: Breed {
        model.breeds.indices.contains(breedIndex) ? model.breeds[breedIndex] : model.breeds[0]
    }
    private var headshot: UIImage? { model.breedPhotos[breed.name] }

    var body: some View {
        ZStack {
            Color.wmCream.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(spacing: 16) {
                        traitsSection
                        typecastingCard
                        insideStoryCard
                    }
                    .padding(EdgeInsets(top: 22, leading: 22, bottom: 44, trailing: 22))
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear { model.loadBreedPhoto(for: breed) }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                model.screen = .results
            } label: {
                Text("‹")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.wmIce)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.wmIce.opacity(0.7), lineWidth: 1.5))
                    .contentShape(Circle())
            }
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 6) {
                Text("WUT A MUTT")
                    .font(.playfair(12, bold: true, relativeTo: .caption))
                    .kerning(4)
                    .foregroundColor(.wmCream)
                // Trailing no-break space gives Great Vibes' swashes (the
                // 'd' curl) room before the fit-to-width bounds clip them.
                Text(breed.name + "\u{00A0}")
                    .font(.greatVibes(breed.heroNameSize))
                    .foregroundColor(.wmIce)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(color: Color.wmIce.opacity(0.45), radius: 12)
                    .accessibilityAddTraits(.isHeader)
                Text(breed.tagline)
                    .font(.playfair(15, italic: true, relativeTo: .subheadline))
                    .foregroundColor(.wmCream)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 64, leading: 26, bottom: 32, trailing: 26))
        .background(
            ZStack(alignment: .topTrailing) {
                LinearGradient.wmHero
                // Falloff runs past the frame (CSS farthest-corner ≈ 155) so
                // the glow fades out with no visible disk edge.
                RadialGradient(colors: [Color.wmPink.opacity(0.25), Color.wmPink.opacity(0)],
                               center: .center, startRadius: 0, endRadius: 155)
                    .frame(width: 220, height: 220)
                    .clipShape(Circle())   // the prototype's border-radius: 50%
                    .offset(x: 60, y: -60)
                    .glowPulseOpacity()
            }
            .clipped()
        )
    }

    // MARK: Traits

    @ViewBuilder
    private var traitsSection: some View {
        if let headshot {
            // Polaroid headshot (2/3) + stacked trait rail (1/3)
            let contentW = WMScreen.width - 44
            let railW = (contentW - 10) / 3
            HStack(alignment: .top, spacing: 10) {
                polaroid(headshot, paperWidth: contentW - railW - 10)
                VStack(spacing: 10) {
                    traitCard("SIZE", breed.size, compact: true)
                    traitCard("ENERGY", breed.energy, compact: true)
                    traitCard("DROOL", breed.drool, compact: true)
                    traitCard("FLOOF", breed.floof, compact: true)
                }
                .frame(width: railW)
            }
        } else {
            // No reference image — original 2×2 grid with full labels
            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                traitCard("SIZE", breed.size, compact: false)
                traitCard("ENERGY", breed.energy, compact: false)
                traitCard("DROOL LEVEL", breed.drool, compact: false)
                traitCard("FLOOF FACTOR", breed.floof, compact: false)
            }
        }
    }

    private func polaroid(_ image: UIImage, paperWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // cover / center top, hard-sized to the paper's inner width so a
            // landscape photo can't inflate the layout; height keeps the
            // paper level with the four-card trait rail (≈294pt tall)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: paperWidth - 14, height: 253, alignment: .top)
                .clipped()
                .accessibilityLabel("Reference photo of \(breed.name)")
            // Blank Polaroid flap
            Color.clear.frame(height: 34)
        }
        .padding(EdgeInsets(top: 7, leading: 7, bottom: 0, trailing: 7))
        .background(Color.wmCard)
        .rotationEffect(.degrees(-2))
        .shadow(color: Color(hex: "#6E1E33").opacity(0.22), radius: 10, y: 8)
    }

    private func traitCard(_ label: String, _ value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.playfair(12, relativeTo: .caption))
                .kerning(2)
                .foregroundColor(.wmLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.playfair(compact ? 17 : 19, bold: true, relativeTo: .body))
                .foregroundColor(.wmHeading)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 14, leading: compact ? 14 : 16, bottom: 14, trailing: compact ? 14 : 16))
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.wmCard)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.wmBorder, lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: Cards

    private var typecastingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TYPECASTING")
                .font(.playfair(11, relativeTo: .caption2))
                .kerning(3)
                .foregroundColor(.wmLabel)
            ForEach(breed.clues, id: \.self) { clue in
                HStack(spacing: 12) {
                    Circle().fill(Color.wmIceDeep).frame(width: 7, height: 7)
                    Text(clue)
                        .font(.playfair(16, italic: true, relativeTo: .body))
                        .foregroundColor(.wmBodyText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.wmCard)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.wmBorder, lineWidth: 1))
        )
    }

    private var insideStoryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THE INSIDE STORY…")
                .font(.playfair(11, relativeTo: .caption2))
                .kerning(3)
                .foregroundColor(.wmMintText)
            Text(breed.fact)
                .font(.playfair(15, relativeTo: .body))
                .foregroundColor(.wmHeading)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [.wmMintTop, .wmMintBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.wmMintBorder, lineWidth: 1))
        )
        .padding(.bottom, 24)
    }
}
