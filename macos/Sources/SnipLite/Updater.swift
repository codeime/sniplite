import AppKit

/// Checks GitHub for a newer sniplite for Mac and puts it in place of this one.
///
/// The check asks the GitHub API for the latest release of this repository: only the version
/// number and the download address come back, nothing is sent. Updating downloads the release's
/// zip, checks that it holds sniplite (its id and the version expected) with an intact signature,
/// then, once sniplite has quit, a small script swaps the apps and opens the new one.
@MainActor
final class Updater {
    static let shared = Updater()
    static let repo = "codeime/sniplite"

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)            // the new version
        case downloading(Double)          // 0…1
        case installing
        case failed(String)
    }

    struct Release { let version: String; let zip: URL; let page: URL }

    private(set) var state: State = .idle { didSet { onChange.forEach { $0.value(state) } } }
    private(set) var latest: Release?
    /// Who shows the state (the About page, the menu); keyed so a closed page can leave.
    var onChange: [ObjectIdentifier: (State) -> Void] = [:]

    private var download: URLSessionDownloadTask?
    private var progress: NSKeyValueObservation?

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    /// a > b, comparing the numbers between the dots.
    static func newer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    // MARK: checking

    /// At start-up and every few hours: once a day at most, when automatic checks are on.
    func startAutomaticChecks() {
        Timer.scheduledTimer(withTimeInterval: 3 * 3600, repeats: true) { _ in Task { @MainActor in Updater.shared.checkIfDue() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { self.checkIfDue() }
    }

    private func checkIfDue() {
        guard Prefs.shared.autoCheckUpdates,
              Date().timeIntervalSince(Prefs.shared.lastUpdateCheck) > 20 * 3600 else { return }
        check(quiet: true)
    }

    /// `quiet`: an automatic check, which shows nothing unless a new version is found.
    func check(quiet: Bool = false) {
        switch state { case .checking, .downloading, .installing: return; default: break }
        if !quiet { state = .checking }
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Updater.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("sniplite", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req) { data, response, error in
            let result: Result<Release, Error> = Result {
                if let error { throw error }
                guard (response as? HTTPURLResponse)?.statusCode == 200, let data,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let page = (json["html_url"] as? String).flatMap(URL.init(string:)),
                      let assets = json["assets"] as? [[String: Any]],
                      let zip = assets.first(where: { ($0["name"] as? String)?.hasSuffix("_macos.zip") == true })?["browser_download_url"] as? String,
                      let zipURL = URL(string: zip)
                else { throw UpdateError.message(L.t("updNoRelease")) }
                let version = tag.replacingOccurrences(of: "macos-v", with: "").replacingOccurrences(of: "v", with: "")
                return Release(version: version, zip: zipURL, page: page)
            }
            Task { @MainActor in
                let u = Updater.shared
                switch result {
                case .success(let r):
                    Prefs.shared.lastUpdateCheck = Date()
                    u.latest = r
                    Log.write("update check: latest \(r.version), this \(Updater.current)")
                    if Updater.newer(r.version, than: Updater.current) { u.state = .available(r.version) }
                    else if !quiet { u.state = .upToDate }
                case .failure(let e):
                    Log.write("update check failed: \(e.localizedDescription)")
                    if !quiet { u.state = .failed(String(format: L.t("updCheckFailed"), e.localizedDescription)) }
                }
            }
        }.resume()
    }

    // MARK: updating

    enum UpdateError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
    }

    func install() {
        guard let r = latest else { return }
        let app = URL(fileURLWithPath: Bundle.main.bundlePath)
        // the app can only be replaced where it can be written: else, the release page
        guard FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path),
              FileManager.default.isWritableFile(atPath: app.path) else {
            NSWorkspace.shared.open(r.page)
            return
        }
        state = .downloading(0)
        let task = URLSession.shared.downloadTask(with: r.zip) { file, response, error in
            // the file is gone when this returns: move it first
            var kept: URL?
            if let file, (response as? HTTPURLResponse)?.statusCode == 200 {
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("sniplite-update-\(UUID().uuidString).zip")
                if (try? FileManager.default.moveItem(at: file, to: dest)) != nil { kept = dest }
            }
            let message = error?.localizedDescription ?? L.t("updDownloadFailed")
            Task { @MainActor in
                let u = Updater.shared
                u.progress = nil
                guard let kept else { u.state = .failed(String(format: L.t("updFailed"), message)); return }
                u.state = .installing
                u.unpackAndSwap(kept, release: r, replacing: app)
            }
        }
        progress = task.progress.observe(\.fractionCompleted) { p, _ in
            let f = p.fractionCompleted
            Task { @MainActor in if case .downloading = Updater.shared.state { Updater.shared.state = .downloading(f) } }
        }
        download = task
        task.resume()
    }

    private func unpackAndSwap(_ zip: URL, release r: Release, replacing app: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<URL, Error> = Result {
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sniplite-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: zip) }
                guard Updater.run("/usr/bin/ditto", ["-x", "-k", zip.path, dir.path]) == 0 else { throw UpdateError.message(L.t("updUnzipFailed")) }
                let new = dir.appendingPathComponent("sniplite.app")
                // sniplite, the version expected, signed and unchanged since
                guard let info = Bundle(url: new)?.infoDictionary,
                      info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                      info["CFBundleShortVersionString"] as? String == r.version,
                      Updater.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", new.path]) == 0
                else { throw UpdateError.message(L.t("updNotValid")) }
                _ = Updater.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", new.path])
                return new
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let new): Updater.swapAndRelaunch(new, replacing: app)
                case .failure(let e): Updater.shared.state = .failed(String(format: L.t("updFailed"), e.localizedDescription))
                }
            }
        }
    }

    /// After this sniplite has quit: the old app aside, the new one in its place (the old one back
    /// if that fails), then the new one opens.
    private static func swapAndRelaunch(_ new: URL, replacing app: URL) {
        Log.write("updating \(app.path) from \(new.path)")
        let script = """
        while kill -0 "$0" 2>/dev/null; do sleep 0.2; done
        old="$1.old-$$"
        if mv "$1" "$old" && mv "$2" "$1"; then rm -rf "$old"; else [ -d "$old" ] && mv "$old" "$1"; fi
        open "$1"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, String(ProcessInfo.processInfo.processIdentifier), app.path, new.path]
        try? p.run()
        NSApp.terminate(nil)
    }

    @discardableResult
    nonisolated private static func run(_ tool: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
