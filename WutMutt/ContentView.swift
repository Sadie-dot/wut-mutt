import SwiftUI
import PhotosUI

/// The whole show is one state machine with hard cuts between screens —
/// no NavigationStack (which also sidesteps the iOS 26 width bug).
struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ZStack {
            switch model.screen {
            case .curtain:          CurtainView()
            case .home:             CameraScreen()
            case .analyzing:        AnalyzingView()
            case .results:          ResultsView()
            case .detail(let idx):  BreedDetailView(breedIndex: idx)
            case .nodog:            NoDogView()
            }

            if model.shareOpen { ShareOverlay() }
            if model.keyEntryOpen { KeyEntryOverlay() }
        }
        .environmentObject(model)
        .photosPicker(isPresented: $model.pickerPresented,
                      selection: $model.pickedItem, matching: .images)
        .onChange(of: model.pickedItem) { _, _ in model.handlePickedItem() }
        .preferredColorScheme(model.screen.isDarkSet ? .dark : .light)
        .alert("Camera access is off", isPresented: $model.cameraDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Wut Mutt can't see your mutt. Allow camera access in Settings, or use Upload instead.")
        }
    }
}
