import Foundation

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
    let tools: [Tool]
    let credits: String?
}

/// Runs the bundled rudeclaude binary with --json on a timer. The binary's
/// shared cache keeps the usage API at one call per minute at most, whatever
/// the number of open windows or apps.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var overview: Overview?
    @Published private(set) var error: String?
    @Published private(set) var loading = false

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh(force: Bool = false) {
        guard !loading else { return }
        guard let binary = Self.binary() else {
            error = "binaire rudeclaude introuvable"
            return
        }
        loading = true
        let args = ["--json", "--interval", force ? "30s" : "1m"]
        Task {
            defer { loading = false }
            do {
                let data = try await Self.run(binary, args)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                overview = try decoder.decode(Overview.self, from: data)
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
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
