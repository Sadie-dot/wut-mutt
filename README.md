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

Live breed reveals call the Claude API with a bring-your-own-key flow: the
app prompts for an Anthropic API key on first reveal and stores it in the
device Keychain (`ClaudeKeyStore`). If the API is unreachable or returns
something unparseable, the app plays a canned fallback episode instead of an
error screen — the show must go on.

Dev shortcut: `SIMCTL_CHILD_WM_CLAUDE_KEY=sk-ant-… xcrun simctl launch <udid>
com.wutmutt.app` injects a key in Debug builds without touching the Keychain.

## How it's put together

- **One state machine, hard cuts** — `AppModel.screen` drives everything;
  no NavigationStack (which also sidesteps the iOS 26 width-proposal bug).
- **Camera** (`CameraController`) — AVFoundation capture plus a throttled
  Vision `VNRecognizeAnimalsRequest` pass over the live feed; the REVEAL
  button stays dimmed until a dog is actually in the frame. In the simulator
  a 2.2s timer stands in for detection and tonight's star stands in for the
  capture.
- **The scan** — five teasers × 1.6s set an 8-second minimum runtime while
  the Claude vision call (`BreedIdentifier`, `claude-sonnet-4-5`, strict-JSON
  prompt) runs concurrently; the screen advances when both finish.
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
