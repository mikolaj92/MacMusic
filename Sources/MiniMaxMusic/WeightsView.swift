import SwiftUI

struct WeightsView: View {
    @Bindable var model: ComposerModel

    var body: some View {
        Form {
            Section("MiniMax-Music3") {
                LabeledContent("Status") {
                    Label(
                        model.engineReady ? "Ready" : "Not loaded",
                        systemImage: model.engineReady ? "checkmark.circle.fill" : "circle.dashed"
                    )
                    .foregroundStyle(model.engineReady ? Theme.ultramarine : .secondary)
                }
                TextField("Converted MLX folder", text: $model.weightsPath)
                HStack {
                    Button("Choose Folder…", systemImage: "folder") {
                        model.showingFolderPicker = true
                    }
                    Button("Load", systemImage: "arrow.down.doc") {
                        Task { await model.loadWeightsButtonTapped() }
                    }
                    .disabled(model.isWorking || model.weightsPath.isEmpty)
                    Button("Download 4-bit", systemImage: "arrow.down.circle") {
                        Task { await model.downloadWeightsButtonTapped() }
                    }
                    .disabled(model.isWorking)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 220)
    }
}
