import SwiftUI

// Design tokens from the Wut Mutt handoff (design_handoff_wut_mutt/README.md).

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst(hex.hasPrefix("#") ? 1 : 0))).scanHexInt64(&value)
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    // Raspberry
    static let wmRaspberryTop  = Color(hex: "#C22258")
    static let wmRaspberryMid  = Color(hex: "#A31C48")
    static let wmRaspberry     = Color(hex: "#8C1238")
    static let wmDeep          = Color(hex: "#6E0C2A")
    static let wmDimmedBase    = Color(hex: "#43081D")
    static let wmNearBlack     = Color(hex: "#14060D")
    static let wmAccent        = Color(hex: "#D91F5C")
    static let wmLabel         = Color(hex: "#B01E53")
    static let wmHeroGradEnd   = Color(hex: "#A3134A")

    // Ice-blue
    static let wmIce      = Color(hex: "#A9F2FF")
    static let wmIceDeep  = Color(hex: "#59C2D6")
    static let wmIceLight = Color(hex: "#DFF9FF")

    /// Waypoints for the certainty dial's ice → raspberry ramp, and the only
    /// place either colour appears.
    ///
    /// Blended straight, those two ends average to #997099 — a dead gray-purple
    /// that sat across the middle of the arc, bottoming out at 21% saturation.
    /// These carry the ramp around the hue wheel instead of through the
    /// desaturated middle of it, holding the floor at 30%. They lean warm on
    /// purpose: routing through a true violet scores better still, but paints a
    /// third hue across the top of a dial in an app that only owns two.
    static let wmDialCool = Color(hex: "#7FA2DA")
    static let wmDialWarm = Color(hex: "#C258A6")

    // Cream / pink
    static let wmCream  = Color(hex: "#FFF4EF")
    static let wmCard   = Color(hex: "#FFFDF9")
    static let wmPink   = Color(hex: "#FFD3E3")
    static let wmTrack  = Color(hex: "#FBE3EC")
    static let wmBorder = Color(hex: "#F5C9D8")

    // Text on cream
    static let wmHeading   = Color(hex: "#43112B")
    static let wmBodyText  = Color(hex: "#6E2E4C")
    static let wmBodyText2 = Color(hex: "#8C3557")
    static let wmFinePrint = Color(hex: "#7E6152")

    // Mint fact card — deliberately the app's one single-use hue, kept by
    // the user's call (2026-08-08). The dossier's inside-story card is the
    // one piece of non-fiction in the whole show (the prompt forbids
    // invented facts), and the register shift wears its own color — the
    // same logic as the off-air cards' one literal zone. From the design
    // handoff's spec; a pastel cousin of spoiler green, the covers' fourth
    // data color. Don't re-flag it as an unintentional one-off.
    static let wmMintTop    = Color(hex: "#E9FBF5")
    static let wmMintBottom = Color(hex: "#CFF5E9")
    static let wmMintBorder = Color(hex: "#8FD8C4")
    static let wmMintText   = Color(hex: "#0F6B58")

    // Share card gold border
    static let wmGold = Color(hex: "#E0C88E")

    /// Two colours lifted off the Soap Opera Magazine spoiler covers this app
    /// is styled after — the yellow their featured couple's name is always set
    /// in, and the green of a show title. (The third cover colour, a pale
    /// headline blue, the app already owns as `wmIceDeep`.)
    ///
    /// Both are far too light to read as a shape on cream — 1.3:1 and 1.5:1 —
    /// which is exactly the problem the covers solve by outlining their type.
    /// The breed bars do the same, so these stay as loud as they are on the
    /// magazine instead of being darkened into mud.
    ///
    /// The green is the one departure: the covers' lime sits at the same
    /// lightness as the yellow and the two collapse into one colour for
    /// red-blind viewers (ΔE 2.6). Deepening it to here restores the gap.
    static let wmSpoilerYellow = Color(hex: "#FFD400")
    static let wmSpoilerGreen  = Color(hex: "#5FAE30")

    /// The red every cover runs its standing alert strip in, and the near-black
    /// of the social bar under it. The cover red is a shade lighter; this one
    /// is darkened just far enough to carry white type at 4.7:1.
    static let wmAlertRed = Color(hex: "#DE1019")
    static let wmBarBlack = Color(hex: "#141014")

    // Row press state
    static let wmRowPressed = Color(hex: "#FFF0F6")
    // The breed rows' only standing "tap me" signal, so it has to be visible.
    // The handoff's #D3B8A0 came out at 1.9:1 on the card — below the 3:1 WCAG
    // asks of a non-text control, and a disclosure arrow nobody sees is a
    // detail screen nobody opens. This muted raspberry measures 4.3:1 while
    // staying quieter than the percentage it sits beside.
    static let wmChevron    = Color(hex: "#B75C7E")
}

// Type ramp: Italiana (marquee), Playfair Display (workhorse),
// Great Vibes (script reveals), Nunito (UI fine print).
// Sizes are the 100% Dynamic Type baseline and scale via relativeTo.
extension Font {
    static func italiana(_ size: CGFloat, relativeTo style: TextStyle = .title) -> Font {
        .custom("Italiana-Regular", size: size, relativeTo: style)
    }
    static func greatVibes(_ size: CGFloat, relativeTo style: TextStyle = .largeTitle) -> Font {
        .custom("GreatVibes-Regular", size: size, relativeTo: style)
    }
    static func playfair(_ size: CGFloat, bold: Bool = false, italic: Bool = false,
                         relativeTo style: TextStyle = .body) -> Font {
        let name: String
        switch (bold, italic) {
        case (false, false): name = "PlayfairDisplay-Medium"
        case (true, false):  name = "PlayfairDisplay-Bold"
        case (false, true):  name = "PlayfairDisplay-MediumItalic"
        case (true, true):   name = "PlayfairDisplay-BoldItalic"
        }
        return .custom(name, size: size, relativeTo: style)
    }
    static func nunito(_ size: CGFloat, weight: NunitoWeight = .bold,
                       relativeTo style: TextStyle = .footnote) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    enum NunitoWeight {
        case semiBold, bold, extraBold
        // Instanced from Nunito's variable font; the family root keeps the
        // "ExtraLight" master name, so these are the real PostScript names.
        var postScriptName: String {
            switch self {
            case .semiBold:  return "NunitoExtraLight-SemiBold"
            case .bold:      return "NunitoExtraLight-Bold"
            case .extraBold: return "NunitoExtraLight-ExtraBold"
            }
        }
    }
}

// UIKit window metrics — sidesteps the iOS 26 NavigationStack width bug and
// gives full-bleed screens exact dimensions (see LemonPig CameraView notes).
enum WMScreen {
    static var width: CGFloat { UIScreen.main.bounds.width }
    static var height: CGFloat { UIScreen.main.bounds.height }
    static var safeAreaInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets ?? .zero
    }
}
