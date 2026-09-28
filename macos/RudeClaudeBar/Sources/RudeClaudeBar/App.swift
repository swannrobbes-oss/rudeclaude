import SwiftUI

@main
struct RudeClaudeBar: App {
    @StateObject private var store = Store()

    init() {
        // The panel is designed for a dark background, like the terminal
        // dashboard, whatever the system appearance.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        MenuBarExtra {
            Panel(store: store)
                .environment(\.colorScheme, .dark)
        } label: {
            MenuLabel(overview: store.overview, failed: store.error != nil)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Only the 5-hour window, drawn by MenuIcon.
struct MenuLabel: View {
    let overview: Overview?
    let failed: Bool

    var body: some View {
        if let five = overview?.limits.first {
            let asking = overview?.sessions.contains { $0.state == "asking" } ?? false
            Image(nsImage: MenuIcon.image(used: five.used, asking: asking))
        } else {
            Image(systemName: failed ? "exclamationmark.triangle" : "gauge.with.dots.needle.33percent")
        }
    }
}
