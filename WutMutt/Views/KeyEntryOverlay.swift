import SwiftUI

/// Bring-your-own-key prompt, in the show's voice. The key lives only in the
/// device Keychain and is sent only to Anthropic.
struct KeyEntryOverlay: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    private var draftEmpty: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.wmDeep.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { model.keyEntryOpen = false }

            VStack(alignment: .leading, spacing: 14) {
                Text("Connect Claude")
                    .font(.italiana(26, relativeTo: .title2))
                    .kerning(2)
                    .foregroundColor(.wmIce)
                    .accessibilityAddTraits(.isHeader)

                Text("The big reveal is performed by Claude, and that takes your own Claude API key. It's stored only in this device's Keychain and sent only to Anthropic.")
                    .font(.playfair(14, relativeTo: .subheadline))
                    .foregroundColor(.wmCream)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("sk-ant-…", text: $draft)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.wmCream)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.wmDeep.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.wmIce.opacity(0.4), lineWidth: 1))

                HStack(spacing: 12) {
                    Button {
                        model.keyEntryOpen = false
                    } label: {
                        Text("Not now")
                            .font(.playfair(15, bold: true, relativeTo: .body))
                            .foregroundColor(.wmPink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Button {
                        ClaudeKeyStore.save(draft)
                        draft = ""
                        model.keyEntryOpen = false
                    } label: {
                        Text("Save key")
                            .font(.playfair(15, bold: true, relativeTo: .body))
                            .foregroundColor(.wmDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.wmIce)
                            .clipShape(Capsule())
                    }
                    .disabled(draftEmpty)
                    .opacity(draftEmpty ? 0.5 : 1)
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.wmRaspberryMid, .wmRaspberry],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.wmIce.opacity(0.35), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            .padding(.horizontal, 28)
        }
        .zIndex(50)
    }
}
