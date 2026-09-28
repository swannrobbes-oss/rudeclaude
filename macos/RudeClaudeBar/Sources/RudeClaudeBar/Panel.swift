import ServiceManagement
import SwiftUI

// Same palette as the terminal dashboard (internal/gfx/draw.go).
extension Color {
    static let rudeYellow = Color(red: 0xFE / 255, green: 0xC8 / 255, blue: 0x24 / 255)
    static let rudeOrange = Color(red: 0xFF / 255, green: 0x8C / 255, blue: 0x28 / 255)
    static let rudeRed = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    static let rudeGreen = Color(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255)
    static let rudeBackground = Color(red: 0x18 / 255, green: 0x18 / 255, blue: 0x18 / 255)

    static func fill(_ used: Double) -> Color {
        used >= 90 ? .rudeRed : used >= 70 ? .rudeOrange : .rudeYellow
    }
}

struct Panel: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let o = store.overview {
                if let alert = o.alert ?? store.error {
                    Text(alert).font(.callout).foregroundStyle(Color.rudeRed)
                }
                HStack(spacing: 0) {
                    ForEach(Array(o.limits.enumerated()), id: \.offset) { _, limit in
                        Ring(limit: limit).frame(maxWidth: .infinity)
                    }
                }
                Divider()
                today(o)
                activity(o)
                Divider()
                sessions(o)
                footer(o)
            } else if let error = store.error {
                Text(error).font(.callout).foregroundStyle(Color.rudeRed)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
            Signature()
        }
        .padding(18)
        .frame(width: 400)
        .background(Color.rudeBackground)
        .background(shortcuts)
        .onAppear { store.refresh() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("rudeclaude").font(.headline)
            Text("Claude Code").font(.headline.weight(.light)).foregroundStyle(.secondary)
            Spacer()
            if store.loading {
                ProgressView().controlSize(.mini)
            }
            Text(store.overview?.updated ?? "").font(.caption).foregroundStyle(.secondary)
            actions
        }
    }

    private var actions: some View {
        Menu {
            Button("Rafraîchir") { store.refresh(force: true) }
                .keyboardShortcut("r")
                .disabled(store.loading)
            LaunchAtLogin()
            Divider()
            Button("Quitter rudeclaude") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
    }

    /// Keeps ⌘R and ⌘Q working while the menu is closed.
    private var shortcuts: some View {
        ZStack {
            Button("") { store.refresh(force: true) }.keyboardShortcut("r")
            Button("") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    private func today(_ o: Overview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("AUJOURD'HUI")
            HStack(alignment: .top) {
                ForEach(Array(o.today.enumerated()), id: \.offset) { _, stat in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(stat.value).font(.system(size: 26, weight: .light))
                            if let unit = stat.unit {
                                Text(unit).font(.callout.weight(.light)).foregroundStyle(.secondary)
                            }
                        }
                        Text(stat.label).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func activity(_ o: Overview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("ACTIVITÉ · 60 MIN")
                Spacer()
                Text(o.activityNow).font(.caption).foregroundStyle(.secondary)
            }
            Bars(values: o.activity).frame(height: 36)
        }
    }

    @ViewBuilder
    private func sessions(_ o: Overview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("SESSIONS")
            if o.sessions.isEmpty {
                Text("aucune session dans l'heure").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(o.sessions.enumerated()), id: \.offset) { _, s in
                SessionRow(session: s)
            }
        }
    }

    @ViewBuilder
    private func footer(_ o: Overview) -> some View {
        if !o.tools.isEmpty || o.credits != nil {
            VStack(alignment: .leading, spacing: 4) {
                if !o.tools.isEmpty {
                    (Text("outils · 1 h   ").foregroundStyle(.secondary)
                        + Text(o.tools.map { "\($0.name) \($0.count)" }.joined(separator: "   ")))
                        .font(.caption)
                }
                if let credits = o.credits {
                    Text(credits).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Same signature as the terminal dashboard, linking to the newsletter.
struct Signature: View {
    var body: some View {
        Link(destination: URL(string: "https://www.rudeops.com")!) {
            (Text("propulsé par ").fontWeight(.light).foregroundStyle(.secondary)
                + Text("RudeOps").fontWeight(.medium).foregroundStyle(Color.rudeYellow)
                + Text("   ·   rudeops.com").foregroundStyle(.secondary))
                .font(.caption)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.caption2.weight(.medium)).kerning(1.6).foregroundStyle(.secondary)
    }
}

/// Usage ring: the arc is the share used, the dot the time elapsed in the
/// window. An arc ahead of the dot means usage runs faster than time.
struct Ring: View {
    let limit: Overview.Limit

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(limit.used, 100) / 100)
                    .stroke(Color.fill(limit.used), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if limit.elapsed >= 0 {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 5, height: 5)
                        .offset(y: -56)
                        .rotationEffect(.degrees(360 * limit.elapsed))
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(limit.used.rounded()))").font(.system(size: 30, weight: .light))
                    Text("%").font(.callout.weight(.light)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            .padding(8)
            Text(limit.label).font(.caption2.weight(.medium)).kerning(1.6)
            Text(limit.reset).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Generated tokens per minute over the last hour, oldest first.
struct Bars: View {
    let values: [Double]

    var body: some View {
        let top = max(values.max() ?? 0, 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(v > 0 ? Color.rudeYellow : Color.secondary.opacity(0.25))
                        .frame(height: v > 0 ? max(2, geo.size.height * v / top) : 1)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct SessionRow: View {
    let session: Overview.Session

    private var dot: Color {
        switch session.state {
        case "working": .rudeGreen
        case "asking": .rudeYellow
        default: .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(dot).frame(width: 7, height: 7)
                Text(session.project).fontWeight(.medium).lineLimit(1)
                Text(session.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(session.age).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(session.doing).font(.callout).lineLimit(1)
                Spacer()
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.fill(session.contextFrac * 100))
                            .frame(width: max(3, 60 * min(session.contextFrac, 1)))
                    }
                    .frame(width: 60, height: 3)
                Text(session.context).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.leading, 13)
        }
    }
}

struct LaunchAtLogin: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Ouvrir au démarrage", isOn: $enabled)
            .onChange(of: enabled) { _, on in
                do {
                    if on {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    enabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}
