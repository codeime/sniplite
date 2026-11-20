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

/// A short message at the bottom of the screen under the mouse.
enum Toast {
    private static var panel: NSPanel?
    private static var work: DispatchWorkItem?

    static func hide() {
        work?.cancel()
        panel?.orderOut(nil)
    }

    static func show(_ s: String) {
        work?.cancel()
        panel?.orderOut(nil)
        let label = NSTextField(labelWithString: s)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 32, height: 34)
        let m = NSEvent.mouseLocation
        let scr = (NSScreen.screens.first { NSMouseInRect(m, $0.frame, false) } ?? NSScreen.main)?.visibleFrame ?? .zero
        let p = NSPanel(contentRect: NSRect(x: scr.midX - size.width / 2, y: scr.minY + 80, width: size.width, height: size.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = NSView(frame: NSRect(origin: .zero, size: size))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        v.layer?.cornerRadius = 10
        label.frame.origin = NSPoint(x: 16, y: (size.height - label.frame.height) / 2)
        v.addSubview(label)
        p.contentView = v
        p.orderFrontRegardless()
        panel = p
        let w = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; p.animator().alphaValue = 0 }) { p.orderOut(nil) }
        }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: w)
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
    private var lastAnswer = Date()            // read and written on `queue` only
    private var lastTick = Date()

    /// A capture opened (true) or closed (false).
    func watch(_ on: Bool) {
        queue.async { [self] in
            timer?.cancel(); timer = nil
            guard on else { return }
            lastAnswer = Date(); lastTick = Date()
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + 1, repeating: 1)
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
        }
    }

    private func tick() {
        // a long gap between two checks: the Mac slept (the timer stops with it), not a hang
        if Date().timeIntervalSince(lastTick) > 3 { lastAnswer = Date() }
        lastTick = Date()
        if Date().timeIntervalSince(lastAnswer) > 6 {
            Log.write("watchdog: no answer from the main thread for 6 s during a capture, quitting")
            Log.flush()
            // opens again once this one is gone
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
                           Bundle.main.bundlePath, String(getpid())]
            try? p.run()
            exit(3)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.queue.async { self.lastAnswer = Date() }
        }
    }
}
