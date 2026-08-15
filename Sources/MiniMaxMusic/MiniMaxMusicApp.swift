import SwiftUI

@main
struct MiniMaxMusicApp: App {
    @State var model = ComposerModel()

    var body: some Scene {
        WindowGroup {
            ComposerView(model: model)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
    }
}
