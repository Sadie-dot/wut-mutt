import SwiftUI

/// The camera set: full-bleed feed, gilded viewfinder, and the
/// ALBUM / REVEAL / FLIP control row. REVEAL stays dim until Vision spots a
/// dog in the frame.
struct CameraScreen: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var camera = CameraController()

    var body: some View {
        let W = WMScreen.width
        let H = WMScreen.height

        ZStack {
            // Feed
            Color.wmNearBlack
            #if !targetEnvironment(simulator)
            CameraPreviewView(session: camera.session)
                .frame(width: W, height: H)
                .clipped()
                .saturation(0.95)
                .contrast(0.98)
                .brightness(0.04)
            #endif

            // Single consolidated overlay: top fade + raspberry vaseline vignette
            LinearGradient(stops: [
                .init(color: Color.wmNearBlack.opacity(0.9), location: 0),
                .init(color: Color.wmNearBlack.opacity(0.45), location: 0.08),
                .init(color: .clear, location: 0.2)
            ], startPoint: .top, endPoint: .bottom)
            RadialGradient(stops: [
                .init(color: .clear, location: 0.45),
                .init(color: Color.wmDeep.opacity(0.4), location: 0.78),
                .init(color: Color.wmDeep.opacity(0.85), location: 1)
            ], center: .init(x: 0.5, y: 0.42), startRadius: 0, endRadius: H * 0.62)
            GlowPulse(center: .init(x: 0.5, y: 0.3))

            // Gilded viewfinder — top 176 / sides 50 / bottom 248
            GildedFrame { Color.clear }
                .frame(width: W - 100, height: H - 176 - 248)
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(y: 176)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // Caption on a feathered shadow pool, below the frame
            VStack(spacing: 5) {
                Text(model.dogDetected ? "Every pup has a story to tell…" : "Cue dramatic entrance")
                    .font(.playfair(18, italic: true, relativeTo: .body))
                    .foregroundColor(.wmCream)
                    .shadow(color: Color.wmNearBlack.opacity(0.95), radius: 5, y: 2)
                Hairline()
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .shadowPool()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 268)
            .accessibilityAddTraits(.updatesFrequently)

            // Bottom controls — ALBUM / REVEAL / FLIP
            HStack(alignment: .center) {
                albumButton
                Spacer()
                revealButton
                Spacer()
                flipButton
            }
            .padding(.horizontal, 36)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 42)
        }
        .frame(width: W, height: H)
        .ignoresSafeArea()
        .onAppear {
            #if !targetEnvironment(simulator)
            camera.start()
            #endif
        }
        .onDisappear { camera.stop() }
        .onReceive(camera.$dogInFrame) { seen in
            if seen { model.dogDetected = true }
        }
    }

    // MARK: Controls

    /// Mini Polaroid opening the photo library. The grayscale Chinese-crested
    /// print is part of the button's design (the app can't know the upload in
    /// advance).
    private var albumButton: some View {
        Button {
            model.openPicker()
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    StarPortrait(star: AppModel.Star(
                        asset: "star-chinese-crested", anchor: .init(x: 0.5, y: 0.2),
                        headline: "", nickname: ""))
                        .brightness(0.08)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.wmDeep))
                }
                .padding(EdgeInsets(top: 4, leading: 4, bottom: 12, trailing: 4))
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.wmCream))
                .rotationEffect(.degrees(-5))
                .shadow(color: Color.wmDeep.opacity(0.55), radius: 4, y: 3)

                Text("ALBUM")
                    .font(.nunito(12, weight: .extraBold))
                    .kerning(2)
                    .foregroundColor(.wmPink)
                    .shadow(color: Color.wmDeep.opacity(0.9), radius: 2, y: 1)
            }
        }
        .accessibilityLabel("Album — pick a photo from your library")
    }

    private var revealButton: some View {
        Button {
            guard model.dogDetected else { return }
            capture()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.wmIce)
                    .frame(width: 92, height: 92)
                Text("REVEAL")
                    .font(.playfair(15, bold: true))
                    .kerning(2)
                    .foregroundColor(.wmDeep)
            }
            .overlay(Circle().stroke(Color.wmDeep.opacity(0.6), lineWidth: 3).frame(width: 95, height: 95))
            .overlay(Circle().stroke(Color.wmIce.opacity(0.75), lineWidth: 2).frame(width: 100, height: 100))
            .shadow(color: Color.wmIce.opacity(model.dogDetected ? 0.5 : 0), radius: 17)
        }
        .modifier(ButtonPulse(active: model.dogDetected))
        .opacity(model.dogDetected ? 1 : 0.3)
        .saturation(model.dogDetected ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.5), value: model.dogDetected)
        .accessibilityLabel(model.dogDetected
                            ? "Reveal — capture and analyze"
                            : "Reveal, disabled — waiting for a dog in frame")

    }

    private var flipButton: some View {
        Button {
            camera.flip()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.wmCream.opacity(0.12))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().strokeBorder(Color.wmCream.opacity(0.7), lineWidth: 2))
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundColor(.wmCream)
                }
                Text("FLIP")
                    .font(.nunito(12, weight: .extraBold))
                    .kerning(2)
                    .foregroundColor(.wmPink)
                    .shadow(color: Color.wmDeep.opacity(0.9), radius: 2, y: 1)
            }
        }
        .accessibilityLabel("Flip camera")
    }

    private func capture() {
        #if targetEnvironment(simulator)
        // No camera in the simulator — use tonight's star as the stand-in shot.
        if let stand = UIImage(named: model.star.asset) {
            model.startScan(with: stand)
        }
        #else
        camera.capture { image in
            if let image {
                model.startScan(with: image)
            }
        }
        #endif
    }
}
