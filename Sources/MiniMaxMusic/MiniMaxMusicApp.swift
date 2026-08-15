import SwiftUI

@main
struct MiniMaxMusicApp: App {
    @State var model = ComposerModel()

    var body: some Scene {
        WindowGroup {
            ComposerView(model: model)
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") { model.newProjectButtonTapped() }
                    .keyboardShortcut("n")
                Button("Duplicate Project") { model.cloneProjectButtonTapped() }
                    .keyboardShortcut("d")
                    .disabled(model.selectedID == nil)
            }
            CommandGroup(after: .newItem) {
                Button("Delete Project") { model.deleteProjectButtonTapped() }
                    .keyboardShortcut(.delete, modifiers: [.command])
                    .disabled(model.selectedID == nil)
            }
        }

        Settings {
            WeightsView(model: model)
        }
    }
}
