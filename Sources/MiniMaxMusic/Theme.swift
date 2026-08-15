import AppKit
import SwiftUI

enum Theme {
    static let ultramarine = Color(red: 0.18, green: 0.32, blue: 0.86)
    static let dusk = Color(red: 0.07, green: 0.08, blue: 0.16)
    static let mist = Color.white.opacity(0.72)

    static var backdrop: some View {
        ZStack {
            Theme.dusk
            LinearGradient(
                colors: [
                    Theme.ultramarine.opacity(0.42),
                    Color(red: 0.22, green: 0.16, blue: 0.46).opacity(0.28),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Theme.ultramarine.opacity(0.28), Color.clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassEffect(.regular, in: .rect(cornerRadius: 24, style: .continuous))
    }
}

struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
