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
    /// 271 → 206 when the masthead moved down onto the field. The portrait
    /// gives up ~65pt and gets rid of a 132pt scrim in the trade, so there is
    /// more dog visible on the smaller photo than there was on the larger one.
    private static let photoHeight: CGFloat = 206

    // The scrim went with the masthead. It existed only to carry cream type
    // over an unknown photo, and it was costing 132pt of dog — a third of the
    // portrait under a 78% wash on a card whose whole premise is that the photo
    // carries it. Nothing is drawn on the picture now, so nothing has to be
    // rescued, and every point of it is the dog.

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
            // Slung across the seam, where a cover captions its inset —
            // breaking the edge is what makes a callout look pasted on rather
            // than parked.
            // 10 and not 14: the badge still breaks the seam, but at 14 its
            // bottom corner came down past the top of CHANNELING and the two
            // crowded each other in the same corner of the field.
            .overlay(alignment: .bottomLeading) {
                verdictBadge.offset(x: 10, y: 10)
            }
            // Above the field, so the badge's shadow falls onto it.
            .zIndex(1)

            VStack(spacing: 2) {
                masthead.padding(.bottom, 6)

                channelingLabel
                // Yellow on the pink field is how a cover bills its featured
                // couple — 4.0:1 at the top of the gradient, which large type
                // clears.
                Text(model.shareStar)
                    .font(.playfair(29, bold: true, italic: true, relativeTo: .title))
                    .foregroundColor(.wmSpoilerYellow)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    // "American Staffordshire Terrier" is 30 characters and
                    // still has to look like a headline.
                    .minimumScaleFactor(0.7)

                castStrip.padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 6)
            // The field absorbs whatever slack the 4:5 frame leaves.
            .frame(maxHeight: .infinity)
            .background(PolkaBackground())

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

    /// The script announces, and what lands is the kind thing.
    ///
    /// The verdict held this slot for one round and it was the wrong tenant.
    /// Putting "NOT A PUG" in the biggest type made the card's loudest claim a
    /// joke about a breed the dog *isn't* — funny to someone who knows the app,
    /// and to a stranger scrolling past, the headline news about a dog they've
    /// never met. The negation went back to the tilted sticker it came from,
    /// where a cover keeps its spoilers, and the warm line took the headline.
    ///
    /// It also fixes the hierarchy underneath: with this at 27pt, the breed at
    /// 29pt is finally the largest thing on the card, which is what anyone
    /// sharing it actually wants to say.
    ///
    /// It stands on the field, not on the photo. For one round it sat over the
    /// picture under a 132pt scrim, and there was no arrangement of it that
    /// worked: in a full-bleed portrait the animal *is* the top of the frame,
    /// so type up there is always on the dog, and raising it only finds more
    /// dog. Aiming the crop to duck the head under it helped photos that had
    /// headroom to spare and did nothing for a tight headshot. Moving it down
    /// here costs the portrait ~65pt and gives back the whole scrim, which was
    /// darkening more than that — so the photo is smaller and more of it is
    /// actually visible.
    private var masthead: some View {
        VStack(spacing: 0) {
            Text("The mutt is…")
                .font(.greatVibes(21))
                .foregroundColor(.wmIce)
                // Great Vibes' line box runs ~1.23em; the design sets
                // line-height 1, so trim the half-leading off both ends.
                .padding(.vertical, -3)
            Text(model.shareBadge)
                .font(.playfair(27, bold: true, relativeTo: .title2))
                .kerning(1)
                .foregroundColor(.wmCream)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 14)
        }
    }

    /// A standing head, not a stray line of text.
    ///
    /// Unruled, this word floats between the yellow badge above it and the
    /// yellow star name below and reads as noise. Rules on *both* sides is the
    /// obvious fix and it fails: the badge overhangs the seam on the left at
    /// exactly this height, so the left rule comes out from under it looking
    /// like a tail on the badge. One rule to the right balances instead —
    /// yellow mass on the left, a thin line on the right, which is how the
    /// covers balance anyway.
    ///
    /// Setting it in `wmIce` was the other candidate and it solves the wrong
    /// half: hue separates it from the two yellows, but *value* was what was
    /// missing, and ice renders at 3.9:1 here against cream's 4.5:1.
    ///
    /// Both rules, symmetrically — which is what this wanted in the first place.
    /// One-sided was a workaround for the badge hanging into this corner of the
    /// field at exactly this height; with the masthead moved down, the badge
    /// went up to the seam and the corner is free. A lone rule with nothing left
    /// to balance is just a stray line.
    ///
    /// `fixedSize` on the word is load-bearing: a flexible `Rectangle` in an
    /// `HStack` is greedy, and without it the rules starve the text and
    /// truncate it to "CHANN…".
    private var channelingLabel: some View {
        HStack(spacing: 10) {
            rule
            Text("CHANNELING")
                .font(.playfair(11, relativeTo: .caption))
                .kerning(5)
                .foregroundColor(.wmCream)
                .fixedSize()
            rule
        }
        .padding(.horizontal, 40)
    }

    private var rule: some View {
        Rectangle()
            .fill(Color.wmCream.opacity(0.55))
            .frame(height: 1)
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
        // 12pt italic rather than the row's 11pt bold caps, because it is prose
        // under a headline now and not a key.
        Text(model.shareOthers)
            .font(.playfair(12, italic: true, relativeTo: .footnote))
            .foregroundColor(.wmCream)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 18)
            // Two lines reserved whether they're used or not, so the card's
            // height doesn't depend on where a breed name happens to break.
            .frame(height: 34)
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
            .rotationEffect(.degrees(-4))
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
