import AppKit
import UniformTypeIdentifiers

enum Clipboard {
    /// Copies an image as PNG and TIFF, with its size in points so it pastes at screen size.
    static func copy(_ img: CGImage, size: CGSize) {
        let rep = NSBitmapImageRep(cgImage: img)
        rep.size = size
        let pb = NSPasteboard.general
        pb.clearContents()
        if let png = rep.representation(using: .png, properties: [:]) { pb.setData(png, forType: .png) }
        if let tiff = rep.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
    }
}

enum Saver {
    private static var lastDir: URL? {
        get { UserDefaults.standard.url(forKey: "saveDir") }
        set { UserDefaults.standard.set(newValue, forKey: "saveDir") }
    }

    static func save(_ img: CGImage, size: CGSize) {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "sniplite_\(f.string(from: Date())).png"
        panel.allowedContentTypes = [.png, .jpeg]
        panel.directoryURL = lastDir ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        lastDir = url.deletingLastPathComponent()
        let rep = NSBitmapImageRep(cgImage: img)
        rep.size = size
        let jpeg = ["jpg", "jpeg"].contains(url.pathExtension.lowercased())
        let data = rep.representation(using: jpeg ? .jpeg : .png, properties: jpeg ? [.compressionFactor: 0.92] : [:])
        do { try data?.write(to: url) } catch { NSAlert(error: error).runModal() }
    }
}

enum TextInput {
    /// Plain typing: no completion, spelling, substitutions, predictions or Writing Tools,
    /// so the system's AutoFill / text services have nothing to attach to.
    static func quiet(_ tv: NSTextView) {
        tv.isAutomaticTextCompletionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.inlinePredictionType = .no
        tv.smartInsertDeleteEnabled = false
        if #available(macOS 15.0, *) { tv.writingToolsBehavior = .none }
    }
}

/// Diagnostics in ~/Library/Logs/sniplite.log (kept small: started over above 256 KB).
enum Log {
    private static let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Logs/sniplite.log")
    fileprivate static let q = DispatchQueue(label: "sniplite.log")

    static func write(_ s: String) {
        guard let url else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) [\(getpid())] \(s)\n"
        q.async {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if size > 262_144 { try? FileManager.default.removeItem(at: url) }
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
            } else {
                try? line.data(using: .utf8)?.write(to: url)
            }
        }
    }
}

extension Log {
    /// Waits until what was written is on disk (before quitting).
    static func flush() { q.sync {} }
}

/// The capture screens cover every display: if sniplite stopped responding while they are up,
/// nothing on the Mac could be used. While a capture is open, a thread of its own checks every
/// second that the main thread still answers; after 6 s without an answer sniplite quits, which
/// takes the capture screens away (the system's own Force Quit would be under them), and opens
/// again.
final class Watchdog {
    static let shared = Watchdog()
    private let queue = DispatchQueue(label: "sniplite.watchdog")
    private var timer: DispatchSourceTimer?
    /// When the main thread last answered, in system uptime: it stops while the Mac sleeps and
    /// never jumps with the clock, so neither looks like a hang. Read and written on `queue` only.
    private var lastAnswer: TimeInterval = 0
    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// A capture opened (true) or closed (false). Nothing runs while no capture is open.
    func watch(_ on: Bool) {
        queue.async { [self] in
            timer?.cancel(); timer = nil
            guard on else { return }
            lastAnswer = Self.now
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(250))
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
        }
    }

    /// Once a second: a tiny task for the main thread, which notes when it ran. While the main
    /// thread is stuck these wait in its queue (at most about six before the end).
    private func tick() {
        if Self.now - lastAnswer > 6 { giveUp() }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.queue.async { self.lastAnswer = Self.now }
        }
    }

    /// Quits at once and opens sniplite again. Nothing here may wait on the stuck main thread:
    /// the new one is started with posix_spawn, and _exit skips the clean-up an exit would run.
    private func giveUp() -> Never {
        Log.write("watchdog: no answer from the main thread for 6 s during a capture, quitting")
        Log.flush()
        let script = "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\""
        let args = ["/bin/sh", "-c", script, Bundle.main.bundlePath, String(getpid())]
        var argv = args.map { strdup($0) } + [nil]
        var pid: pid_t = 0
        _ = posix_spawn(&pid, "/bin/sh", nil, nil, &argv, environ)
        _exit(3)
    }
}
