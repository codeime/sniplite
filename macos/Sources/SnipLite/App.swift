import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    fileprivate(set) var status: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        AppDelegate.moveFromOldID()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = status.button {
            let img = NSImage(systemSymbolName: "scissors", accessibilityDescription: "sniplite")
            img?.isTemplate = true
            b.image = img
            b.toolTip = "sniplite"
        }
        let menu = NSMenu()
        menu.delegate = self
        status.menu = menu

        Log.write("start \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "") screen recording \(Capture.hasPermission) accessibility \(AXIsProcessTrusted())")
        // an entry left by an earlier build (another signature) shows as switched on but does not
        // apply to this one: remove it, so the list never shows a sniplite that is not really allowed
        for p in Permission.allCases where !p.granted { p.resetStaleEntry() }
        HotKeyCenter.shared.handler = { a in AppDelegate.run(a) }
        HotKeyCenter.shared.registerAll()
        TopRowKeys.shared.update(prompt: false)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in Capture.invalidate(); Capture.prewarm() }
        Capture.prewarm()

        if CommandLine.arguments.contains("--capture") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { CaptureSession.start() }
        } else {
            PermissionsWindow.showIfNeeded()
        }
    }

    private static var last: (HotAction, Date)?

    static func run(_ a: HotAction) {
        // the event tap and the Carbon hotkey can both see one press: act once
        if let (la, t) = last, la == a, Date().timeIntervalSince(t) < 0.35 { return }
        last = (a, Date())
        Log.write("run \(a.rawValue)")
        if !HotAction.active.contains(a) { return }   // switched off (text recognition, quick capture)
        switch a {
        case .capture: CaptureSession.start(.normal)
        case .quickCapture: QuickCapture.run()
        case .ocr: CaptureSession.start(.ocr)
        case .ocrCopy: CaptureSession.start(.ocrCopy)
        case .pinClipboard: PinWindow.pinClipboard()
        case .togglePins: PinWindow.toggleAll()
        }
    }

    /// The menu is rebuilt each time it opens, so shortcut changes show at once.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for a in HotAction.active {
            let i = ClosureMenuItem(title: a.title, key: "") { AppDelegate.last = nil; AppDelegate.run(a) }
            if let k = Prefs.shared.hotkey(a) {
                // shown as text: a real key equivalent would only work while the menu is open
                i.title = a.title + "\t" + k.display
            }
            menu.addItem(i)
            if a == .togglePins { menu.addItem(.separator()) }
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: L.t("settings"), key: ",") { SettingsWindow.show() })
        let perm = ClosureMenuItem(title: L.t("permissions") + "…", key: "") { PermissionsWindow.show() }
        if !Permission.allRequiredGranted { perm.title = "⚠︎ " + perm.title }
        menu.addItem(perm)
        menu.addItem(ClosureMenuItem(title: L.t("about"), key: "") {
            NSApp.activate()
            // this repository, then the original it comes from
            let credits = NSMutableAttributedString()
            let center = NSMutableParagraphStyle()
            center.alignment = .center
            func line(_ text: String, link: String?, color: NSColor = .labelColor) {
                var a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .paragraphStyle: center,
                                                        .foregroundColor: color]
                if let link { a[.link] = URL(string: link) }
                credits.append(NSAttributedString(string: text, attributes: a))
            }
            line("github.com/codeime/sniplite", link: "https://github.com/codeime/sniplite")
            line("\n" + L.t("basedOn") + " ", link: nil, color: .secondaryLabelColor)
            line("MrTangLuyao/sniplite", link: "https://github.com/MrTangLuyao/sniplite")
            NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: L.t("quit"), key: "q") { NSApp.terminate(nil) })
    }

    static func askForPermission() { PermissionsWindow.show() }

    /// sniplite's app id was io.github.mrtangluyao.sniplite until 1.0.1. The first start under
    /// the new one takes the settings over and removes the old id's permission entries, which
    /// would otherwise stay in System Settings' lists, switched on but applying to nothing.
    static let oldID = "io.github.mrtangluyao.sniplite"
    private static func moveFromOldID() {
        let d = UserDefaults.standard
        guard Bundle.main.bundleIdentifier != oldID, !d.bool(forKey: "movedFromOldID") else { return }
        if let old = d.persistentDomain(forName: oldID) {
            for (k, v) in old where d.object(forKey: k) == nil { d.set(v, forKey: k) }
            Log.write("settings taken over from \(oldID): \(old.count) values")
        }
        for p in Permission.allCases { p.resetEntry(for: oldID) }
        d.set(true, forKey: "movedFromOldID")
    }

    /// The menu bar scissors snip twice: a quick capture was saved (when its banner is off).
    static func snip() {
        guard let b = (NSApp.delegate as? AppDelegate)?.status.button else { return }
        b.wantsLayer = true
        guard let layer = b.layer else { return }
        // turn about the icon's middle
        let f = layer.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.frame = f
        let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        a.values = [0, 0.32, -0.12, 0.32, -0.12, 0]
        a.keyTimes = [0, 0.18, 0.36, 0.54, 0.72, 1]
        a.duration = 0.55
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(a, forKey: "snip")
    }

    /// Starts a new sniplite and quits this one (a new Screen Recording permission needs it).
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? p.run()
        NSApp.terminate(nil)
    }
}
