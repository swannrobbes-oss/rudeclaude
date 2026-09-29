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
    /// Wide layout, for the desktop widget: fixed-size blocks paired side by
    /// side, then the sessions across the full width, so that their number
    /// only changes the height and never leaves a hole.
    var landscape = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let o = store.overview {
                if let alert = o.alert ?? store.error {
                    Text(alert).font(.callout).foregroundStyle(Color.rudeRed)
                }
                if landscape {
                    band {
                        rings(o)
                    } right: {
                        today(o)
                        breakdown(o)
                    }
                    Divider()
                    band {
                        activity(o)
                    } right: {
                        if let r = o.rtk {
                            RtkSection(rtk: r)
                        }
                    }
                    Divider()
                    sessions(o)
                    footer(o)
                } else {
                    rings(o)
                    breakdown(o)
                    Divider()
                    today(o)
                    activity(o)
                    Divider()
                    sessions(o)
                    if let r = o.rtk {
                        Divider()
                        RtkSection(rtk: r)
                    }
                    footer(o)
                }
            } else if let error = store.error {
                Text(error).font(.callout).foregroundStyle(Color.rudeRed)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
            Signature()
        }
        .padding(18)
        .frame(width: landscape ? 800 : 400)
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
            DesktopToggle()
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

    /// Two blocks side by side, both vertically centred on the taller one.
    private func band<L: View, R: View>(
        @ViewBuilder _ left: () -> L, @ViewBuilder right: () -> R
    ) -> some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 16, content: left).frame(width: 330)
            Divider()
            VStack(alignment: .leading, spacing: 16, content: right)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func rings(_ o: Overview) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(o.limits.enumerated()), id: \.offset) { _, limit in
                Ring(limit: limit).frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func breakdown(_ o: Overview) -> some View {
        if let shares = o.breakdown, !shares.isEmpty {
            Breakdown(shares: shares)
        }
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
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("SESSIONS").padding(.bottom, 2)
            if o.sessions.isEmpty {
                Text("aucune session dans l'heure").font(.callout).foregroundStyle(.secondary)
            }
            // Two columns in landscape, aligned on the bands above.
            let columns = Array(repeating: GridItem(.flexible(), spacing: 45, alignment: .top), count: landscape ? 2 : 1)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(Array(o.sessions.enumerated()), id: \.offset) { _, s in
                    // The row's padding leaves room for its highlight while
                    // keeping the text aligned with the other sections.
                    SessionRow(session: s).padding(.horizontal, -8)
                }
            }
        }
    }

    @ViewBuilder
    private func footer(_ o: Overview) -> some View {
        if !o.tools.isEmpty || o.credits != nil {
            // One line in landscape, credits on the right.
            let layout = landscape
                ? AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            layout {
                if !o.tools.isEmpty {
                    (Text("outils · 1 h   ").foregroundStyle(.secondary)
                        + Text(o.tools.map { "\($0.name) \($0.count)" }.joined(separator: "   ")))
                        .font(.caption)
                }
                if landscape {
                    Spacer(minLength: 16)
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

/// One session, coloured like the terminal dashboard: green while Claude
/// works, yellow when it waits for an answer, dimmed once idle.
extension Color {
    /// Same product colours as the terminal (theme.ProductHex).
    static func product(_ key: String) -> Color {
        switch key {
        case "claude_code": .rudeYellow
        case "chat": Color(red: 0x60 / 255, green: 0xA5 / 255, blue: 0xFA / 255)
        case "cowork": Color(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xFA / 255)
        default: .secondary
        }
    }
}

/// The weekly usage split between products, chats on claude.ai included.
struct Breakdown: View {
    let shares: [Overview.Share]

    var body: some View {
        let total = max(shares.reduce(0) { $0 + $1.percent }, 1)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("SEMAINE PAR PRODUIT")
            GeometryReader { geo in
                let gap = 3.0
                let width = geo.size.width - gap * Double(shares.count - 1)
                HStack(spacing: gap) {
                    ForEach(Array(shares.enumerated()), id: \.offset) { _, s in
                        Capsule().fill(Color.product(s.key)).frame(width: max(2, width * s.percent / total))
                    }
                }
            }
            .frame(height: 6)
            HStack(spacing: 14) {
                ForEach(Array(shares.enumerated()), id: \.offset) { _, s in
                    HStack(spacing: 5) {
                        Circle().fill(Color.product(s.key)).frame(width: 7, height: 7)
                        Text(s.label).foregroundStyle(.secondary)
                        Text("\(Int(s.percent.rounded())) %").fontWeight(.medium)
                    }
                    .font(.caption)
                }
            }
        }
    }
}

/// Tokens kept out of the context by rtk: today and all time on the left,
/// the last seven days on the right.
struct RtkSection: View {
    let rtk: Overview.Rtk

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("RTK · 7 JOURS")
                Spacer()
                Text("\(rtk.savings) % en moyenne").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 16) {
                stat(rtk.savedToday, "économisés aujourd'hui")
                stat(rtk.savedTotal, "au total")
                Spacer(minLength: 0)
                DayBars(days: rtk.days).frame(maxWidth: 140).frame(height: 52)
            }
        }
        .help("\(rtk.commandsToday) commandes passées par rtk aujourd'hui")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 26, weight: .light)).fixedSize()
            Text(label).font(.caption).foregroundStyle(.secondary).fixedSize()
        }
    }
}

/// One bar per day, oldest first, today in full colour.
struct DayBars: View {
    let days: [Overview.Rtk.Day]

    var body: some View {
        let top = max(days.map(\.saved).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let today = i == days.count - 1
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(day.saved > 0
                                ? Color.rudeYellow.opacity(today ? 1 : 0.5)
                                : Color.secondary.opacity(0.25))
                            .frame(height: day.saved > 0 ? max(2, geo.size.height * day.saved / top) : 1)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    Text(day.label)
                        .font(.caption2.weight(today ? .semibold : .regular))
                        .foregroundStyle(today ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: Overview.Session

    private var working: Bool { session.state == "working" }
    private var asking: Bool { session.state == "asking" }
    private var idle: Bool { session.state == "idle" }

    private var dot: Color {
        working ? .rudeGreen : asking ? .rudeYellow : .secondary
    }

    private var doing: AnyShapeStyle {
        asking ? AnyShapeStyle(Color.rudeYellow) : working ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StateDot(color: dot, pulsing: working)
                .frame(width: 10, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(session.project).fontWeight(.medium).lineLimit(1).layoutPriority(1)
                    Text(session.detail).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(session.age).font(.caption).foregroundStyle(.tertiary).fixedSize()
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(session.doing).font(.callout).foregroundStyle(doing).lineLimit(1)
                    Spacer(minLength: 8)
                    ContextGauge(frac: session.contextFrac, label: session.context)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background {
            if asking {
                RoundedRectangle(cornerRadius: 8).fill(Color.rudeYellow.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.rudeYellow.opacity(0.25)))
            }
        }
        .opacity(idle ? 0.55 : 1)
        .help("\(session.project) · \(session.detail)\n\(session.doing) · contexte \(session.context)")
    }
}

/// The session state, with a halo that pulses while Claude works.
struct StateDot: View {
    let color: Color
    let pulsing: Bool
    @State private var expanded = false

    var body: some View {
        ZStack {
            if pulsing {
                Circle().fill(color.opacity(expanded ? 0 : 0.35))
                    .frame(width: expanded ? 18 : 8, height: expanded ? 18 : 8)
            }
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .onAppear {
            guard pulsing else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { expanded = true }
        }
    }
}

/// Context window fill, grey until it gets close to the limit. The label
/// has a fixed width so the gauges line up from one session to the next.
struct ContextGauge: View {
    let frac: Double
    let label: String

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(frac >= 0.7 ? Color.fill(frac * 100) : Color.secondary)
                        .frame(width: max(3, 56 * min(frac, 1)))
                }
                .frame(width: 56, height: 3)
            Text(label).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
    }
}

struct DesktopToggle: View {
    @ObservedObject private var widget = DesktopWidget.shared

    var body: some View {
        Toggle("Widget sur le bureau", isOn: $widget.visible)
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
