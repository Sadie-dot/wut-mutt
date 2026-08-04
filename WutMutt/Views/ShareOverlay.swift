import SwiftUI
import UIKit
import Photos
import MessageUI

/// Share the drama: gossip-card preview over a blurred backdrop, with a row of
/// share targets. The circles are the design's share row; each one now does the
/// thing its label promises rather than all four opening the same sheet.
struct ShareOverlay: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false
    @State private var shareItem: ShareItem?
    @State private var messageItem: ShareItem?
    @State private var toast: String?
    @State private var toastToken = 0

    /// Messages is only offered on a device that can actually send one — a
    /// circle that opens the wrong thing is the bug this row is fixing. That
    /// is true of every iPhone with a line or an iMessage account, so the row
    /// is four circles in the user's hands and three in the simulator, which
    /// can't text at all.
    ///
    /// `SIMCTL_CHILD_WM_FORCE_MESSAGES=1` puts the circle back for design
    /// review; the composer it opens won't work, so it is Debug-only.
    private var canSendMessage: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["WM_FORCE_MESSAGES"] == "1" { return true }
        #endif
        return MFMessageComposeViewController.canSendText()
    }

    var body: some View {
        let W = WMScreen.width

        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.wmDeep.opacity(0.82))
                .ignoresSafeArea()
                .onTapGesture { model.shareOpen = false }

            VStack(spacing: 18) {
                // Lay the card out at its fixed width and *scale* it into the
                // space available, rather than laying it out to fit. Laying out
                // to fit gave the preview a different width from the export on
                // every device — 338 here, 376 on a Pro Max, 311 on an SE —
                // which let `minimumScaleFactor` and `lineLimit` resolve
                // differently in each. What you see is now what you send.
                let cardWidth = W - 64
                let cardScale = cardWidth / ShareCardView.layoutWidth

                ShareCardView.canvas(ShareCardView(model: model))
                    .scaleEffect(cardScale)
                    // `scaleEffect` draws bigger without claiming the space, so
                    // hand the layout the scaled footprint or the share row
                    // rides up underneath the card. 4:5 per ShareCardView.
                    .frame(width: cardWidth, height: cardWidth * 5 / 4)
                    // The lift belongs to the card sitting on the backdrop, not
                    // to the card itself — see ShareCardView.
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 24)
                    .scaleEffect(reduceMotion ? 1 : (popped ? 1 : 0.6))
                    .opacity(reduceMotion ? 1 : (popped ? 1 : 0))

                HStack(spacing: 18) {
                    if canSendMessage {
                        shareTarget(label: "MESSAGES", filled: true,
                                    hint: "Opens a new message with the card attached") {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 20, weight: .semibold))
                        } action: { withCard { messageItem = ShareItem(image: $0) } }
                    }
                    shareTarget(label: "SAVE", filled: true,
                                hint: "Saves the card to your photo library") {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 20, weight: .semibold))
                            .offset(y: -1)
                    } action: { withCard(saveToPhotos) }
                    shareTarget(label: "COPY", filled: true,
                                hint: "Copies the card so you can paste it anywhere") {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 19, weight: .semibold))
                    } action: { withCard(copyToPasteboard) }
                    shareTarget(label: "MORE", filled: false,
                                hint: "Opens the system share sheet") {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                    } action: { withCard { shareItem = ShareItem(image: $0) } }
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
        // The design centers the card on the screen, not inside the safe area.
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { toastView }
        .zIndex(30)
        .onAppear {
            if reduceMotion { popped = true }
            else { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { popped = true } }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.image])
        }
        .sheet(item: $messageItem) { item in
            MessageComposeView(image: item.image) { sent in
                messageItem = nil
                if sent { showToast("Off to the group chat") }
            }
        }
    }

    private func shareTarget<Icon: View>(label: String, filled: Bool, hint: String,
                                         @ViewBuilder icon: () -> Icon,
                                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .accessibilityLabel(label.capitalized)
        .accessibilityHint(hint)
    }

    // MARK: - Targets

    /// Renders the gossip card at 3× and hands it to whichever target asked.
    @MainActor private func withCard(_ use: (UIImage) -> Void) {
        let renderer = ImageRenderer(content: ShareCardView.canvas(ShareCardView(model: model)))
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            showToast("Couldn't make the card")
            return
        }
        use(image)
    }

    @MainActor private func copyToPasteboard(_ image: UIImage) {
        UIPasteboard.general.image = image
        showToast("Card copied")
    }

    @MainActor private func saveToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in showToast("Photos access is off") }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { saved, _ in
                Task { @MainActor in
                    showToast(saved ? "Saved to Photos" : "Couldn't save the card")
                }
            }
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        Group {
            if let toast {
                Text(toast)
                    .font(.nunito(14, weight: .bold))
                    .foregroundColor(.wmDeep)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.wmIce))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    .transition(reduceMotion ? .opacity
                                             : .opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .padding(.bottom, WMScreen.safeAreaInsets.bottom + 18)
    }

    /// Every target says what it did — a save that shows nothing looks broken.
    @MainActor private func showToast(_ text: String) {
        toastToken += 1
        let token = toastToken
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { toast = text }
        UIAccessibility.post(notification: .announcement, argument: text)
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard token == toastToken else { return }
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) { toast = nil }
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - The gossip card

struct ShareCardView: View {
    /// The card's layout width, shared by the preview and the export.
    ///
    /// Neither call site gets its own number. They diverged once — the preview
    /// laid out to the screen while the export was a hard 340 — and a card
    /// whose layout depends on the device stops predicting the file it makes.
    static let layoutWidth: CGFloat = 340

    /// Everything the card is rendered into, at both call sites. `ImageRenderer`
    /// builds a *fresh* environment rather than inheriting the enclosing one,
    /// so the export is already immune to the user's text size; pinning it here
    /// says so out loud, and stops a future SwiftUI that does inherit from
    /// silently reshaping the artifact.
    @MainActor static func canvas<V: View>(_ card: V) -> some View {
        card
            .frame(width: layoutWidth)
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(.large)
    }

    @ObservedObject var model: AppModel

    /// How much of the card the portrait takes. The field below it is flexible
    /// and the footer is intrinsic, so this is the number that sets whether the
    /// whole thing lands on 425 — see the note on `aspectRatio` below.
    ///
    /// The card is hard-pinned to 425 (see `body`), so anything over that clips
    /// instead of growing — this is the number that buys the field its slack.
    ///
    /// 206 → 252 when the masthead stopped being a headline: the field now
    /// holds only the cast line and the closer, and the height the 27pt
    /// masthead was renting goes back to the dog. 340×252 is 1.35:1 — still
    /// wider than a dog stands, but no longer the 1.65:1 letterbox that was
    /// trimming skull and body at once.
    private static let photoHeight: CGFloat = 252

    /// The billing's fixed vertical metrics, from the fonts themselves rather
    /// than measured constants: the script line never shrinks, so its height
    /// and the full-size name's are knowable up front, and they are what the
    /// seam anchor needs to find the name inside the unit's total height.
    /// The -2 is the billing VStack's own spacing.
    /// The script's tracking: 0.7pt of air between glyphs a connected script
    /// was never designed to have. Comped at 0 / 0.7 / 1.4 (and a 22pt size
    /// variant) over the light coat: 0.7 opens the "nneling" pile-up enough
    /// to parse without visibly snapping the joins, while 1.4 breaks the
    /// script into separate glyphs — each one then wears its own outline rim,
    /// and the seams read as damage. The 22pt route spreads by growing, which
    /// just moves the crowding up a size and leans on the name. Don't push
    /// tracking past ~1 here: the joins are the register.
    ///
    /// Both values take Debug-only launch overrides
    /// (`SIMCTL_CHILD_WM_SCRIPT_KERN` / `_SIZE`) so future comps don't need a
    /// rebuild per variant.
    private static var scriptKern: CGFloat {
        #if DEBUG
        ProcessInfo.processInfo.environment["WM_SCRIPT_KERN"]
            .flatMap(Double.init).map { CGFloat($0) } ?? 0.7
        #else
        0.7
        #endif
    }
    private static var scriptSize: CGFloat {
        #if DEBUG
        ProcessInfo.processInfo.environment["WM_SCRIPT_SIZE"]
            .flatMap(Double.init).map { CGFloat($0) } ?? 20
        #else
        20
        #endif
    }

    private static let scriptHeight: CGFloat =
        UIFont(name: "GreatVibes-Regular", size: scriptSize)?.lineHeight ?? 29
    /// Where the name's midline sits below the seam when nothing shrinks —
    /// the approved layout's own geometry (top edge 44 above the seam),
    /// restated as the invariant to hold when something does.
    private static let nameDropBelowSeam: CGFloat = scriptHeight - 2
        + (UIFont(name: "PlayfairDisplay-BoldItalic", size: 40)?.lineHeight ?? 55) / 2 - 44

    // There is still no scrim. The two things that sit on the photo — the
    // spoiler sticker and the billing's top half — carry their own contrast,
    // one on a solid plate and one in an outline, so no wash has to darken
    // the dog on their behalf.

    var body: some View {
        // Three zones: the set, the field, the social bar. Everything else is
        // layered onto them the way a cover layers its photo and callouts onto
        // one polka field — an earlier version stacked a red band on a
        // raspberry band on a photo band on a pink band, and a stack of
        // stripes is what reads as unintentional.
        VStack(spacing: 0) {
            // The photo runs full-bleed and the type sits on it. The card used
            // to inset a 144pt circle in the field, which spent its best asset
            // on a margin; here the portrait is the card and the field is what
            // the billing stands on.
            Group {
                // The uncropped shot, not the Vision face crop: a 4:5 card has
                // room the circle never did, and the crop throws away the body.
                // But uncropped is not the same as unaimed — see `aimed(_:)`.
                if let image = model.capturedImage ?? model.portraitImage {
                    aimed(image)
                } else {
                    Color.wmDimmedBase
                }
            }
            .frame(width: Self.layoutWidth, height: Self.photoHeight)
            .clipped()
            // The spoiler goes in a top corner of the photo, where a cover
            // pastes its nastiest sticker — and above the reveal, so the card
            // reads spoiler first, answer at the seam. It left the seam
            // because the billing lives there now.
            .overlay(alignment: .topTrailing) {
                verdictBadge.offset(x: -10, y: 12)
            }

            VStack(spacing: 0) {
                // The billing is an overlay, not a row — a row would sit *in*
                // the field, and the whole point is that it crosses out of it.
                // This padding is the room its lower half lands in.
                castStrip.padding(.top, 36)
                // The slack gathers here on purpose: billing and cast hold
                // together at the seam, the closer sits down by the footer,
                // and the field stops being an evenly spaced stack.
                Spacer(minLength: 6)
                closingLine.padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            // The field absorbs whatever slack the 4:5 frame leaves.
            .frame(maxHeight: .infinity)
            .background(PolkaBackground())
            // Anchored by the name, not by the unit's top edge. A fixed -44
            // held the *top* still while `minimumScaleFactor` let the name's
            // height vary, so a shrunk long name rode up with its baseline at
            // the seam — mostly on the photo, weakening the seam-crossing on
            // exactly the names that shrink. The guide solves for the point
            // that keeps the name's midline at the same drop below the seam
            // whatever height the name resolved to; at full size it comes out
            // to the old 44 exactly, so short names land pixel-identical.
            .overlay(alignment: .top) {
                seamBilling.alignmentGuide(.top) { d in
                    (d.height + Self.scriptHeight - 2) / 2 - Self.nameDropBelowSeam
                }
            }
            // Above the photo, so the billing can cross onto it and its
            // shadow falls on both sides of the seam.
            .zIndex(1)

            // The covers' social bar. It also carries the one line this app
            // owes anyone who meets it here: the card travels without the
            // results screen's disclaimer, so it says it itself. This used to
            // be a red alert strip across the top, which the user read as one
            // band too many — but the line has to live *somewhere* on the
            // artifact, and the fine print at the foot of a cover is where a
            // reader already looks for it.
            VStack(spacing: 2) {
                Text("WUTMUTT.APP")
                    .font(.nunito(11, weight: .extraBold))
                    .kerning(3)
                    .foregroundColor(.wmCream)
                // 10pt at 0.85, up from 9 at 0.75, paid for out of the
                // portrait. This is the only sentence on the card that has a
                // job beyond delight, and it was set like a legal footer —
                // technically present, easy not to read. It still won't survive
                // a feed thumbnail; nothing this size would. It now reads
                // easily at the size someone actually opens the card at.
                Text("A JUICY GUESS — NOT A DNA TEST")
                    .font(.nunito(10, weight: .bold))
                    .kerning(1)
                    .foregroundColor(.wmCream.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.wmBarBlack)
        }
        // Pinned to 4:5 — the tallest a feed post can be before Instagram
        // crops it — as an explicit size rather than a ratio, because
        // `.aspectRatio` *proposes* and this needs to *clamp*.
        //
        // As a ratio it resolved to 425.333pt, and `ImageRenderer` rounds up to
        // whole pixels, so every export came out 1020×1276 instead of 1275.
        // That third of a point is not the contents pushing: it survived a 31pt
        // shorter photo unchanged. 340 × 5/4 is exactly 425 in binary, so
        // stating the size gets the round number the ratio couldn't.
        //
        // The trade is that content over budget now clips rather than growing
        // the card. That is the better failure: growing changes the ratio, and
        // a card that is no longer 4:5 gets cropped by the feed — which is how
        // the footer disclaimer would go missing.
        .frame(width: Self.layoutWidth, height: Self.layoutWidth * 5 / 4)
        .background(Color.wmDeep)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.wmGold, lineWidth: 1))
        // No drop shadow here: ImageRenderer draws it inside the exported
        // bounds, and flattening that half-black blur onto a JPEG washed the
        // whole card gray. The overlay adds the shadow to its own preview,
        // where there is a backdrop for the card to lift off.
    }

    /// The photo, filled into the card's slot and *aimed* at the dog.
    ///
    /// `scaledToFill` crops from the centre, which is only the right answer when
    /// the dog happens to be in the middle. It is on the tight portraits this
    /// card was designed against, and it is not on an ordinary wide snapshot of
    /// a dog lying on the floor — that gives the card half its area of empty
    /// room with the animal sliced off at the seam.
    ///
    /// So shift the overflow instead of splitting it evenly: put the dog's box
    /// in the middle of the slot, clamped so the image never pulls away from an
    /// edge and exposes background. With no box — Vision found nothing, or this
    /// is the simulator, where it cannot run at all — the clamp collapses to the
    /// centred crop this replaces, so the fallback is exactly the old behaviour.
    @ViewBuilder
    private func aimed(_ image: UIImage) -> some View {
        let slot = CGSize(width: Self.layoutWidth, height: Self.photoHeight)
        let source = image.size
        // What `scaledToFill` does, worked out rather than left implicit.
        let scale = max(slot.width / source.width, slot.height / source.height)
        let filled = CGSize(width: source.width * scale, height: source.height * scale)
        let slack = CGSize(width: filled.width - slot.width,
                           height: filled.height - slot.height)

        // Centring spends half the slack on each side; aiming spends whatever
        // it takes to bring the subject to the middle, and no more.
        //
        // This used to aim *below* a reserved band, because the masthead stood
        // on the photo and the dog had to duck under it. That was a workaround
        // with a hole in it — a tight headshot has no room above the dog, so
        // the clamp pinned to the top edge and the type landed on the skull
        // anyway. The masthead moved off the photo instead, which fixes it for
        // every photo rather than the ones with headroom to spare, and lets
        // this go back to simply centring the dog.
        let box = model.dogBox
        let wanted = CGPoint(
            x: (box?.midX ?? 0.5) * filled.width - slot.width / 2,
            y: (box?.midY ?? 0.5) * filled.height - slot.height / 2)
        let window = CGPoint(x: min(max(wanted.x, 0), slack.width),
                             y: min(max(wanted.y, 0), slack.height))

        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: slot.width, height: slot.height)
            // `offset` moves what is drawn without moving the layout, so the
            // slot stays put and the picture slides inside it.
            .offset(x: slack.width / 2 - window.x, y: slack.height / 2 - window.y)
    }

    /// The billing, slung across the seam the way a cover pastes its featured
    /// couple's name across the photo's edge.
    ///
    /// This is the card's headline now, and it earns the slot by being the
    /// thing that varies: "a very good dog" held it for one round and it was a
    /// constant — the biggest type on the card identical on every card the app
    /// will ever make, with the two things that differ from dog to dog sitting
    /// subordinate under it. Ten shared cards looked the same above the fold,
    /// which is exactly where the "what did *yours* get" curiosity lives.
    ///
    /// Crossing the seam is not decoration either. With everything pulled off
    /// the photo the card had quietly re-banded — photo strip, field strip,
    /// footer strip — and the covers this card imitates are not bands, they
    /// are one field with things pasted onto it. Pasting the headline over the
    /// edge is what stitches the zones back into a single surface.
    ///
    /// The script lead-in absorbs CHANNELING, which retires the caps label and
    /// both of its rules — two more horizontals gone from a card whose failure
    /// mode is horizontals. And the type can sit on the photo without a scrim
    /// because it wears the app icon's own treatment: ice script and yellow
    /// headline over a dark outline, which reads over a white coat and a dark
    /// brindle alike where a naked fill needs a 132pt wash behind it.
    private var seamBilling: some View {
        VStack(spacing: -2) {
            outlined(Text("Channeling…").font(.greatVibes(Self.scriptSize))
                        .kerning(Self.scriptKern),
                     fill: .wmIce, stroke: .wmHeading, width: 1.65, core: 0.45)
            outlined(Text(model.shareStar)
                        .font(.playfair(40, bold: true, italic: true, relativeTo: .largeTitle)),
                     fill: .wmSpoilerYellow, stroke: .wmHeading, width: 1.5)
                // One line, however long the breed: a second line would land
                // deep in the field and take the cast's room with it.
                // "American Staffordshire Terrier" bottoms out at ~22pt —
                // no longer huge, but still the largest thing on the card.
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 12)
        }
        // A paste-up tilt, opposite the spoiler sticker's, so the two read as
        // separately thrown rather than laid out on a grid.
        .rotationEffect(.degrees(-2.5))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    /// Cover type doesn't trust its background — it wears an outline. SwiftUI
    /// has no text stroke, so this is the text drawn under itself eight ways
    /// around the compass. Offsets rather than a blur shadow because a blur is
    /// a halo, not an edge, and because this card renders twice — the copies
    /// land identically in the preview and the export.
    ///
    /// `core` is the app icon's synthetic weight, borrowed at the icon's own
    /// numbers: eight more copies in the *fill* colour dilate the glyph core,
    /// faking a heavier Great Vibes. Thickness is what lets the ice read over
    /// a light coat — its value sits at the fur's (1.9:1), so at hairline
    /// width the cyan vanishes and only the dark rim survives, the hollow
    /// look; at a fattened width the hue carries what the value can't. 0.45
    /// is the ceiling the icon found at this same 20-per-tile scale — more
    /// clogs the W's loops — and the outline width grows by the same amount,
    /// because the rim is measured from the original glyph edge and the
    /// dilated core would eat it otherwise.
    private func outlined(_ text: Text, fill: Color, stroke: Color, width w: CGFloat,
                          core: CGFloat = 0) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = CGFloat(i) * .pi / 4
                text.foregroundColor(stroke)
                    .offset(x: cos(angle) * w, y: sin(angle) * w)
            }
            if core > 0 {
                ForEach(0..<8, id: \.self) { i in
                    let angle = CGFloat(i) * .pi / 4
                    text.foregroundColor(fill)
                        .offset(x: cos(angle) * core, y: sin(angle) * core)
                }
            }
            text.foregroundColor(fill)
        }
    }

    /// The old headline, kept whole and demoted to the sign-off.
    ///
    /// "The mutt is… a very good dog" is the app's warmest sentence and it is
    /// the same on every card, which is precisely why it closes instead of
    /// opens: a constant makes a rotten headline and a fine motto. Sitting low
    /// by the footer it also breaks the field's even stacking — billing and
    /// cast hold together at the seam, this hangs back with the wordmark.
    private var closingLine: some View {
        (Text("The mutt is… ")
            .font(.greatVibes(16))
            .foregroundColor(.wmIce)
         + Text(model.shareBadge)
            .font(.playfair(14, bold: true, italic: true, relativeTo: .footnote))
            .foregroundColor(.wmCream))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
    }

    /// The cast, as a row of stars in the results screen's own data colours.
    ///
    /// Each star's **area** tracks its share of the mix, not its width:
    /// scaling the width by percentage makes a 41% lead look like four times
    /// a 20% supporting player rather than twice. So it reads as proportion
    /// without printing a figure, which is the line the rest of the card holds.
    ///
    /// Stars rather than breed headshots, and not only because this app calls
    /// its wildcard a Guest Star: photos would have carried 39 CC BY stills
    /// out of the app and away from the Image Credits screen that attributes
    /// them. Nothing here leaves the app but the app's own shapes.
    ///
    /// Each star carries its breed's name beneath it, which is what ties the
    /// colours to the results screen's rows. The name and the star together
    /// replaced a separate "with A, B, and C" line: the two said the same
    /// thing, and the sentence was costing 40pt of a card that owes its
    /// height to the portrait.
    ///
    /// Fixed tilts and drops rather than a random scatter, and fixed on
    /// purpose: this card is rendered twice — once for the preview, once at 3×
    /// for export — so anything random would place the stars differently in
    /// the picture you see and the file you send.
    private var castStrip: some View {
        // The stars are gone. Their *area* tracked each breed's share, which
        // was careful and undecodable: there is no legend on a card that
        // deliberately carries no figures, so three shapes of different sizes
        // read as decoration, and the ordering already said everything the
        // sizing did. What is left is the part that was doing the work — the
        // names, in share order, which is the whole supporting cast.
        //
        // `billedName`, not `name`: the wildcard is "Guest Star", which beside
        // Mountain Cur and Boxer in identical treatment reads as a breed to
        // anyone who hasn't met the app. The article is what marks it as a
        // placeholder, and this card travels without the app to explain itself.
        //
        // 11pt is the floor Apple's guidance puts on legible text, and three
        // labels get ~92pt of width each to sit in.
        // "with" is back. Once the stars came out, the three names were a bare
        // row under a headline with nothing joining them to it — a caption
        // missing its sentence. `shareOthers` is that sentence, it already
        // builds from `billedName`, and it costs almost nothing now: the row
        // reserved two lines anyway, so the connector is the only new ink.
        //
        // Italic rather than the row's 11pt bold caps, because it is prose
        // under a headline now and not a key. 14pt, up from 12: the redesign
        // grew the lead and left this line behind — 3.3:1 lead-to-cast on a
        // card whose twist *is* the four-breed cast, with the best joke
        // ("and a Guest Star") set as the quietest thing on it. Two points
        // buys it back a billing's presence without joining the headline's
        // register; the extra line height comes out of the field's slack,
        // not the portrait.
        Text(model.shareOthers)
            .font(.playfair(14, italic: true, relativeTo: .footnote))
            .foregroundColor(.wmCream)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 18)
            // Two lines reserved whether they're used or not, so the card's
            // height doesn't depend on where a breed name happens to break.
            .frame(height: 40)
            .accessibilityElement(children: .combine)
    }

    /// The tilted yellow callout a cover pastes over its photo — dark type on
    /// spoiler-yellow, kept off-square so it reads as stuck on rather than
    /// laid out, and edged so it holds up over a light coat.
    ///
    /// It carries the verdict. A spoiler pasted at an angle over the photo is
    /// exactly the register the joke wants — the covers put their nastiest
    /// callouts in one of these, not in the masthead — and the verdicts are
    /// drawn from a short fixed list of small breeds (Pug, Yorkie, Chihuahua,
    /// Whippet), so this never has to hold a long name.
    private var verdictBadge: some View {
        Text(model.shareKicker)
            .font(.playfair(11, bold: true, relativeTo: .footnote))
            .kerning(1.2)
            .foregroundColor(.wmHeading)
            .multilineTextAlignment(.leading)
            // One line, shrinking if it has to: a long verdict wrapping to two
            // turned the callout into a placard covering half the portrait.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.wmSpoilerYellow)
            .overlay(Rectangle().strokeBorder(Color.wmHeading, lineWidth: 1.5))
            // Tilted against the billing's -2.5 so the two pastes scatter
            // instead of agreeing on a grid.
            .rotationEffect(.degrees(3))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
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

// MARK: - Messages

struct MessageComposeView: UIViewControllerRepresentable {
    let image: UIImage
    /// `true` when the message actually went out, so only a real send is
    /// congratulated.
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = context.coordinator
        if let data = image.pngData() {
            composer.addAttachmentData(data, typeIdentifier: "public.png",
                                       filename: "wut-mutt.png")
        }
        return composer
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void
        init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish(result == .sent)
        }
    }
}
