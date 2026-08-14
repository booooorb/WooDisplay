import AppKit
import Foundation

@MainActor
final class WooDisplayUpdater: ObservableObject {
    static let shared = WooDisplayUpdater()

    @Published var availableCommit: String?
    @Published var isChecking = false
    @Published var message: String?

    private let repository = "booooorb/WooDisplay"
    private let defaults = UserDefaults.standard

    var shortAvailableCommit: String {
        String((availableCommit ?? "").prefix(7))
    }

    func checkAutomatically() {
        guard defaults.bool(forKey: "WooDisplayAutomaticUpdatesEnabled") ||
                defaults.object(forKey: "WooDisplayAutomaticUpdatesEnabled") == nil else { return }
        checkForUpdates(showUpToDateMessage: false)
    }

    func checkForUpdates(showUpToDateMessage: Bool = true) {
        guard !isChecking else { return }
        isChecking = true

        Task {
            do {
                let latest = try await latestCommit()
                isChecking = false
                if latest == bundledCommit {
                    availableCommit = nil
                    if showUpToDateMessage { message = "WooDisplay is up to date." }
                } else {
                    availableCommit = latest
                }
            } catch {
                isChecking = false
                if showUpToDateMessage {
                    message = "WooDisplay couldn't check for updates. \(error.localizedDescription)"
                }
            }
        }
    }

    func downloadAndInstall() {
        guard availableCommit != nil else { return }
        isChecking = true

        Task {
            do {
                let replacement = try await downloadReplacement()
                try installAndRelaunch(replacement)
            } catch {
                isChecking = false
                message = "The update couldn't be installed. \(error.localizedDescription)"
            }
        }
    }

    private var bundledCommit: String? {
        defaults.string(forKey: "WooDisplayInstalledCommit") ??
            Bundle.main.object(forInfoDictionaryKey: "WooDisplayCommit") as? String
    }

    private func latestCommit() async throws -> String {
        let url = URL(string: "https://api.github.com/repos/\(repository)/commits/main")!
        var request = URLRequest(url: url)
        request.setValue("WooDisplay-Updater", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(CommitResponse.self, from: data).sha
    }

    private func downloadReplacement() async throws -> URL {
        let url = URL(string: "https://github.com/\(repository)/raw/refs/heads/main/dist/WooDisplay-macOS-universal.zip")!
        let (temporaryDownload, response) = try await URLSession.shared.download(from: url)
        try validate(response)

        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WooDisplayUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        let archive = workingDirectory.appendingPathComponent("update.zip")
        try FileManager.default.moveItem(at: temporaryDownload, to: archive)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", archive.path, workingDirectory.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else { throw UpdateError.invalidArchive }

        let app = workingDirectory.appendingPathComponent("WooDisplay.app", isDirectory: true)
        let bundle = Bundle(url: app)
        guard bundle?.bundleIdentifier == Bundle.main.bundleIdentifier,
              FileManager.default.isExecutableFile(atPath: app.appendingPathComponent("Contents/MacOS/WooDisplay").path) else {
            throw UpdateError.invalidArchive
        }
        return app
    }

    private func installAndRelaunch(_ replacement: URL) throws {
        let currentApp = Bundle.main.bundleURL
        guard currentApp.pathExtension == "app" else { throw UpdateError.notApplicationBundle }
        guard let availableCommit else { return }

        let script = """
        pid="$1"; target="$2"; replacement="$3"; staged="${target}.updating"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
        rm -rf "$staged"
        /usr/bin/ditto "$replacement" "$staged"
        rm -rf "$target"
        /bin/mv "$staged" "$target"
        /usr/bin/open "$target"
        """

        let installer = Process()
        let arguments = ["-c", script, "woodisplay-updater", "\(ProcessInfo.processInfo.processIdentifier)", currentApp.path, replacement.path]

        if FileManager.default.isWritableFile(atPath: currentApp.deletingLastPathComponent().path) {
            // User-owned installs (for example ~/Applications) can update without an
            // administrator prompt. The helper waits until this process exits.
            installer.executableURL = URL(fileURLWithPath: "/bin/sh")
            installer.arguments = arguments
        } else {
            // A system-owned /Applications folder requires macOS authorization.
            let command = (["/bin/sh"] + arguments).map(shellQuoted).joined(separator: " ")
            installer.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            installer.arguments = ["-e", "do shell script \(appleScriptQuoted(command)) with administrator privileges"]
        }
        try installer.run()
        defaults.set(availableCommit, forKey: "WooDisplayInstalledCommit")
        NSApp.terminate(nil)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdateError.badServerResponse
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptQuoted(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

private struct CommitResponse: Decodable { let sha: String }

private enum UpdateError: LocalizedError {
    case badServerResponse
    case invalidArchive
    case notApplicationBundle

    var errorDescription: String? {
        switch self {
        case .badServerResponse: "GitHub returned an unexpected response."
        case .invalidArchive: "The downloaded archive isn't a valid WooDisplay application."
        case .notApplicationBundle: "Updates are available only when WooDisplay is running as an app."
        }
    }
}
