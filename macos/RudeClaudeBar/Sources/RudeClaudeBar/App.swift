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

/// "42 % · 12 %" for the 5-hour window and the week, with a question mark
/// when a session is waiting for an answer.
struct MenuLabel: View {
    let overview: Overview?
    let failed: Bool

    var body: some View {
        if let o = overview, o.limits.count == 2 {
            let asking = o.sessions.contains { $0.state == "asking" }
            let symbol = asking ? "questionmark.bubble.fill" : "gauge.with.dots.needle.33percent"
            Text("\(Image(systemName: symbol)) \(percent(o.limits[0].used)) · \(percent(o.limits[1].used))")
        } else {
            Image(systemName: failed ? "exclamationmark.triangle" : "gauge.with.dots.needle.33percent")
        }
    }

    private func percent(_ v: Double) -> String { "\(Int(v.rounded())) %" }
}
