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

    // Mint fact card
    static let wmMintTop    = Color(hex: "#E9FBF5")
    static let wmMintBottom = Color(hex: "#CFF5E9")
    static let wmMintBorder = Color(hex: "#8FD8C4")
    static let wmMintText   = Color(hex: "#0F6B58")

    // Share card gold border
    static let wmGold = Color(hex: "#E0C88E")

    // Row press state
    static let wmRowPressed = Color(hex: "#FFF0F6")
    static let wmChevron    = Color(hex: "#D3B8A0")
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
