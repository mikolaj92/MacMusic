import SwiftUI

@main
struct MiniMaxMusicApp: App {
    @State var model = ComposerModel()

    var body: some Scene {
        WindowGroup {
            ComposerView(model: model)
        }
        .defaultSize(width: 980, height: 720)
        .windowResizability(.contentMinSize)
    }
}
