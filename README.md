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

Live breed reveals reach Claude one way only: deploy `proxy/` — a Cloudflare
Worker holding the Anthropic key server-side, with a per-IP daily cap — then
put its URL and app token in a git-ignored
`WutMutt/Config/Secrets.local.xcconfig`. The app ships no key, never stores
one, and never asks a viewer for one. See [proxy/README.md](proxy/README.md).

When a reveal can't happen, the app says so on an off-air card in the show's
voice — the daily cap ("It's intermission time."), a dropped connection
("We've lost the feed.") — rather than inventing a breed reading. A device
build with no proxy configured lands on the stand-by card the same honest
way. The one place a canned episode still plays is the simulator with nothing
configured, so the whole show stays demoable without credentials.

**Privacy:** with the proxy configured, photos transit your Worker on the way
to Anthropic. Say so in the app's privacy policy and App Store data
disclosures.

Dev shortcuts (Debug builds only) — `SIMCTL_CHILD_<VAR>=… xcrun simctl launch
<udid> com.wutmutt.app`:

- `WM_FORCE_VERDICT=nodog` forces the "not a mutt" twist screen — the
  prototype's teddy-bear shortcut.
- `WM_FORCE_VERDICT=offair` / `=offline` force two of the off-air cards (daily
  cap and lost feed). These need the proxy configured, since without one the
  simulator plays the demo episode instead.
- `WM_FORCE_OFFLINE=1` makes the retry precheck treat the device as offline,
  so the off-air cards' "still no feed" beat can be exercised in the
  simulator (whose network is the Mac's).

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
  both finish. The prompt and schema live in the Worker, and only there.
  Photos go up at ≤1024px on the long edge, above the handoff's 640px budget:
  that was a browser-base64 workaround, and breed calls need the coat and
  muzzle detail it discarded.
- **Results portrait** — Vision crops the captured photo toward the dog's
  face before it lands in the gilded circle.
- **Breed headshots** — 64 curated Wikimedia Commons photos bundled as
  asset-catalog imagesets (`breed-*.imageset`), sourced by
  `tools/photo-sourcing/` and generated into `PhotoCredits.swift` by
  `build_assets.py` — edit the pipeline, not the generated file. Every photo
  is CC0, public domain, or CC BY; **ShareAlike is excluded on purpose**,
  since the detail screen's crop is arguably an adaptation. `BreedPhotos`
  matches Claude's free-text breed name by rarity-weighted token score rather
  than substring — "Terrier" is worth almost nothing across a dozen entries,
  "Vizsla" alone is decisive — because a confidently wrong dog is worse than
  none. A miss is a normal outcome (the long tail outruns 64 photos): no
  image → the 2×2 trait grid, which is a complete design in its own right.
  Mountain Cur ships photo-less for exactly that reason — both of its Commons
  candidates are ShareAlike. Even "Guest Star" has a cast photo: a beach
  silhouette — a dog whose breed can't be read, which is the role.
- **Share** — the gossip card is a SwiftUI view rendered to an image
  (`ImageRenderer` at 3×). Each share-row target does its own thing with that
  image: Messages opens `MFMessageComposeViewController` with it attached (and
  the circle is hidden on a device that can't text), Save writes it to Photos
  with add-only authorisation, Copy puts it on the pasteboard, More opens the
  system share sheet. All four confirm themselves with a toast.
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
- Breed reference photos: 64 stills from
  [Wikimedia Commons](https://commons.wikimedia.org), each CC0, public domain,
  or CC BY (2.0–4.0) — never ShareAlike. Every photographer is credited in the
  app's own Image Credits screen, including the CC0 and public-domain ones
  whose licence compels nothing.

© 2026
