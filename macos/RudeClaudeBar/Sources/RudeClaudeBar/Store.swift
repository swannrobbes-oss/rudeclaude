import AppKit

struct Overview: Decodable {
    struct Limit: Decodable {
        let label: String
        let used: Double
        let elapsed: Double
        let reset: String
    }

    struct Stat: Decodable {
        let value: String
        let unit: String?
        let label: String
    }

    struct Session: Decodable {
        let project: String
        let detail: String
        let state: String
        let doing: String
        let context: String
        let contextFrac: Double
        let age: String
    }

    /// One product's part of the weekly usage (Claude Code, chats…), in %.
    struct Share: Decodable {
        let key: String
        let label: String
        let percent: Double
    }

    struct Tool: Decodable {
        let name: String
        let count: Int
    }

    let updated: String
    let alert: String?
    let limits: [Limit]
    let today: [Stat]
    let activity: [Double]
    let activityNow: String
    let sessions: [Session]
    /// Token savings from rtk, the CLI proxy; nil when it is not installed.
    struct Rtk: Decodable {
        struct Day: Decodable {
            let label: String
            let saved: Double
        }

        let savedToday: String
        let commandsToday: Int
        let savedTotal: String
        let savings: Int
        let days: [Day]
    }

    let tools: [Tool]
    let breakdown: [Share]?
    let credits: String?
    let rtk: Rtk?
}

/// Runs the bundled rudeclaude binary with --json on a timer. The binary's
/// shared cache keeps the usage API at one call per minute at most, whatever
/// the number of open windows or apps.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var overview: Overview?
    @Published private(set) var error: String?
    /// Only for refreshes asked by the user: the background ones are too
    /// frequent to show a spinner.
    @Published private(set) var loading = false

    /// Sessions waiting for an answer, by project and branch.
    private(set) var asking: [Overview.Session] = []
    private var running = false
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh(force: Bool = false) {
        guard !running else { return }
        guard let binary = Self.binary() else {
            error = "binaire rudeclaude introuvable"
            return
        }
        running = true
        loading = force
        let args = ["--json", "--interval", force ? "30s" : "1m"]
        Task {
            defer { running = false; loading = false }
            do {
                let data = try await Self.run(binary, args)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let o = try decoder.decode(Overview.self, from: data)
                chimeIfNewlyAsking(o)
                overview = o
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    /// Plays a discreet sound when a session starts waiting for an answer,
    /// once, and not for the sessions already waiting at launch.
    private func chimeIfNewlyAsking(_ o: Overview) {
        let now = o.sessions.filter { $0.state == "asking" }
        let key = { (s: Overview.Session) in "\(s.project)|\(s.detail)" }
        let before = Set(asking.map(key))
        let fresh = now.contains { !before.contains(key($0)) }
        if fresh, overview != nil, Chime.enabled {
            Chime.play()
        }
        asking = now
    }

    /// The copy inside the app bundle first, then the usual install paths
    /// (useful with `swift run`).
    private static func binary() -> URL? {
        if let url = Bundle.main.url(forAuxiliaryExecutable: "rudeclaude") {
            return url
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/go/bin/rudeclaude", "/opt/homebrew/bin/rudeclaude", "/usr/local/bin/rudeclaude"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    private static func run(_ binary: URL, _ args: [String]) async throws -> Data {
        try await Task.detached {
            let process = Process()
            process.executableURL = binary
            process.arguments = args
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            try process.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let message = err.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let text = String(decoding: message, as: UTF8.self)
                    .replacingOccurrences(of: "rudeclaude : ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw RunError(message: text.isEmpty ? "rudeclaude a échoué" : text)
            }
            return data
        }.value
    }
}

struct RunError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// The sound played when Claude waits for an answer: the system's Tink, at
/// low volume.
enum Chime {
    static let key = "askSound"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    @MainActor private static let sound: NSSound? = {
        let sound = NSSound(named: "Tink")
        sound?.volume = 0.35
        return sound
    }()

    @MainActor static func play() {
        sound?.stop()
        sound?.play()
    }
}
