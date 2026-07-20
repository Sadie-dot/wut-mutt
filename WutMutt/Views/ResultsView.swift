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
                    certaintyCard
                        .fadeUp(delay: 0.25)
                    castCard
                        .fadeUp(delay: 0.3)
                    actions
                        .fadeUp(delay: 0.35)

                    Text("Juicy guess powered by Claude. Not a DNA test.")
                        .font(.nunito(12, weight: .bold))
                        .foregroundColor(.wmFinePrint)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
                .padding(EdgeInsets(top: 64, leading: 24, bottom: 44, trailing: 24))
            }
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
                .accessibilityAddTraits(.isHeader)
            Hairline(width: 80)
        }
        .padding(.top, 10)
    }

    private var portrait: some View {
        GildedCircle(diameter: 210) {
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
                Text("a very good dog")
                    .font(.playfair(15, bold: true, italic: true, relativeTo: .subheadline))
                    .foregroundColor(.wmCream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.wmAccent))
                    .shadow(color: Color(hex: "#6E1E33").opacity(0.4), radius: 7, y: 4)
                    .rotationEffect(.degrees(-6))
                    .offset(x: 14, y: -2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your mutt's portrait\(celebrate ? " — a very good dog" : "")")
    }

    private var twistQuote: some View {
        (Text("“In a twist no one saw coming…\nfur baby was ")
         + Text("\(model.breedCountWord) breeds").bold().foregroundColor(.wmAccent)
         + Text(" all along.”"))
            .font(.playfair(16, italic: true, relativeTo: .body))
            .foregroundColor(.wmBodyText2)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.horizontal, 10)
    }

    private var certaintyCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("HOW SURE ARE WE?")
                    .font(.playfair(12, relativeTo: .caption))
                    .kerning(3)
                    .foregroundColor(.wmLabel)
                Spacer()
                Text(model.certaintyLabel)
                    .font(.playfair(16, bold: true, italic: true, relativeTo: .subheadline))
                    .foregroundColor(.wmAccent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.wmTrack)
                    // Blue → raspberry: hotter = more certain
                    Capsule()
                        .fill(LinearGradient(colors: [.wmIceDeep, .wmAccent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(model.certainty) / 100)
                }
            }
            .frame(height: 10)
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
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
                BreedRow(breed: breed, isLead: index == 0,
                         isLast: index == model.breeds.count - 1) {
                    model.loadBreedPhoto(for: breed)
                    model.screen = .detail(index)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
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
    let isLast: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(breed.name)
                        .font(.playfair(isLead ? 26 : 20, bold: true,
                                        relativeTo: isLead ? .title2 : .body))
                        .foregroundColor(.wmHeading)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(breed.pct)%")
                        .font(.playfair(isLead ? 24 : 18, bold: true,
                                        relativeTo: isLead ? .title3 : .body))
                        .foregroundColor(.wmLabel)
                    Text("›")
                        .font(.nunito(16, weight: .extraBold))
                        .foregroundColor(.wmChevron)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.wmTrack)
                        Capsule()
                            .fill(breed.color)
                            .frame(width: geo.size.width * CGFloat(breed.pct) / 100)
                    }
                }
                .frame(height: 6)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.wmTrack).frame(height: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(breed.name), \(breed.pct) percent")
        .accessibilityHint("Opens the character dossier")
    }
}

struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.wmRowPressed : .clear)
    }
}
