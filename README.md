# Wut Mutt 🐶📺

*The Breeds of Our Lives.* A playful iOS app that guesses the breed mix of a
dog from a photo — staged as a 1980s TV soap opera / supermarket tabloid.
Snap or upload a photo; Claude returns a breed breakdown presented as a
melodramatic episode: dramatic entrance → cliffhanger analysis → DNA-test
reveal → shareable gossip card. A "not a dog" verdict gets its own
shocking-twist screen.

> Built with Claude (Anthropic) from a Claude Design handoff
> (`design_handoff_wut_mutt`), under the developer's creative direction.
> Breed guesses are AI-generated entertainment — not veterinary, genetic,
> or dramatic advice.

## Building

Open `WutMutt.xcodeproj` in Xcode and run on an iOS simulator or device
(iOS 17+, portrait iPhone only).

Live breed reveals need Claude, and there are two ways to reach it:

- **Proxy (shipping setup).** Deploy `proxy/` — a Cloudflare Worker holding
  the Anthropic key server-side, with a per-IP daily cap — then put its URL
  and app token in a git-ignored `WutMutt/Config/Secrets.local.xcconfig`.
  The app ships no key and users never see a prompt. See
  [proxy/README.md](proxy/README.md).
- **Bring your own key (default on a fresh clone).** With no proxy
  configured, the app prompts for an Anthropic API key on first reveal and
  stores it in the device Keychain (`ClaudeKeyStore`).

When a reveal can't happen, the app says so on an off-air card in the show's
voice — the daily cap ("That's a wrap."), a dropped connection ("We've lost
the feed."), a rejected key — rather than inventing a breed reading. The one
place a canned episode still plays is the simulator with nothing configured
at all, so the whole show stays demoable without credentials.

**Privacy:** with the proxy configured, photos transit your Worker on the way
to Anthropic. Say so in the app's privacy policy and App Store data
disclosures.

Dev shortcuts (Debug builds only) — `SIMCTL_CHILD_<VAR>=… xcrun simctl launch
<udid> com.wutmutt.app`:

- `WM_CLAUDE_KEY=sk-ant-…` injects a key without touching the Keychain.
- `WM_FORCE_VERDICT=nodog` forces the "not a mutt" twist screen — the
  prototype's teddy-bear shortcut.
- `WM_FORCE_VERDICT=offair` / `=offline` force the two off-air cards (daily
  cap and lost feed). These need a backend configured, since without one the
  simulator plays the demo episode instead.

## How it's put together

- **One state machine, hard cuts** — `AppModel.screen` drives everything;
  no NavigationStack (which also sidesteps the iOS 26 width-proposal bug).
- **Camera** (`CameraController`) — AVFoundation capture plus a throttled
  Vision `VNRecognizeAnimalsRequest` pass over the live feed; the REVEAL
  button stays dimmed until a dog is actually in the frame. In the simulator
  a 2.2s timer stands in for detection and tonight's star stands in for the
  capture.
- **The scan** — five teasers × 1.6s set an 8-second minimum runtime while
  the Claude vision call (`BreedIdentifier`, `claude-sonnet-5`, thinking off,
  constrained with a JSON schema) runs concurrently; the screen advances when
  both finish. The prompt and schema live in the Worker; `BreedIdentifier`
  mirrors them for the bring-your-own-key path — keep the two in sync.
  Photos go up at ≤1024px on the long edge, above the handoff's 640px budget:
  that was a browser-base64 workaround, and breed calls need the coat and
  muzzle detail it discarded.
- **Results portrait** — Vision crops the captured photo toward the dog's
  face before it lands in the gilded circle.
- **Breed headshots** — placeholder behavior per the handoff: a fuzzy-matched
  random photo from the public dog.ceo API (production should ship one curated
  photo per breed). No image → the 2×2 trait grid fallback.
- **Share** — the gossip card is a SwiftUI view rendered to an image
  (`ImageRenderer` at 3×); every share-row target hands it to the system
  share sheet.
- **Accessibility** — Dynamic Type via `relativeTo`, Reduce Motion disables
  every pulse/bob/zoom/pop, VoiceOver announcements on screen changes, the
  certainty meter exposes its percentage as an accessibility value, and the
  disabled REVEAL explains itself.

## Credits & licenses

- Star portraits are AI-generated artwork, art-directed in Figma
  (from the design handoff). No real dogs were dramatized.
- Fonts: Italiana, Playfair Display, Great Vibes, Nunito — all under the
  [SIL Open Font License 1.1](https://openfontlicense.org), bundled as
  static TTFs from Google Fonts.
- Breed reference photos at runtime: [dog.ceo](https://dog.ceo/dog-api/)
  (Stanford Dogs dataset).

© 2026 Wut Mutt Productions. All rights reserved. All dogs good.
