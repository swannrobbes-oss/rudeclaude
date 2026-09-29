import AppKit
import SwiftUI

/// The dashboard pinned to the desktop: above the wallpaper and the icons,
/// below every other window, on all spaces. Drag it anywhere; its position
/// and visibility are kept across launches.
@MainActor
final class DesktopWidget: ObservableObject {
    static let shared = DesktopWidget()

    @Published var visible = UserDefaults.standard.bool(forKey: "desktopWidget") {
        didSet {
            UserDefaults.standard.set(visible, forKey: "desktopWidget")
            update()
        }
    }

    private var window: NSPanel?
    private weak var store: Store?

    func attach(_ store: Store) {
        self.store = store
        update()
    }

    private func update() {
        guard visible, let store else {
            window?.orderOut(nil)
            return
        }
        let window = self.window ?? make(store)
        self.window = window
        window.orderFront(nil)
    }

    private func make(_ store: Store) -> NSPanel {
        let card = WidgetCard(store: store) { [weak self] size in
            Task { @MainActor in self?.resize(to: size) }
        }
        let host = NSHostingView(rootView: card)
        host.sizingOptions = []

        let window = WidgetWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 450),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.hidesOnDeactivate = false
        // First launch: top right corner of the main screen.
        let saved = UserDefaults.standard.string(forKey: "NSWindow Frame DesktopWidget") != nil
        window.setFrameAutosaveName("DesktopWidget")
        if !saved, let screen = NSScreen.screens.first?.visibleFrame {
            window.setFrameTopLeftPoint(NSPoint(x: screen.maxX - window.frame.width - 24, y: screen.maxY - 24))
        }
        return window
    }

    /// Follows the card's size, keeping the top edge in place and the card
    /// on screen. Called after layout, never during it, so the two do not
    /// feed each other.
    private func resize(to size: CGSize) {
        guard let window, size.height > 0, window.frame.size != size else { return }
        var frame = NSRect(x: window.frame.minX, y: window.frame.maxY - size.height, width: size.width, height: size.height)
        if let screen = window.screen?.visibleFrame {
            frame.origin.x = max(screen.minX, min(frame.minX, screen.maxX - frame.width))
            frame.origin.y = max(screen.minY, min(frame.minY, screen.maxY - frame.height))
        }
        window.setFrame(frame, display: true)
    }
}

/// Accepts key status so the ⌘R and ⌘Q shortcuts work once clicked.
private final class WidgetWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct WidgetCard: View {
    @ObservedObject var store: Store
    let sized: (CGSize) -> Void

    var body: some View {
        Panel(store: store, landscape: true)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08)))
            .environment(\.colorScheme, .dark)
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: \.size, action: sized)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
