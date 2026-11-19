import AppKit
import ServiceManagement

/// The settings, kept in UserDefaults (~/Library/Preferences/<bundle id>.plist).
final class Prefs {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    var language: String {
        get { d.string(forKey: "language") ?? "system" }
        set { d.set(newValue, forKey: "language") }
    }
    var pinOnTop: Bool {
        get { d.object(forKey: "pinOnTop") as? Bool ?? true }
        set { d.set(newValue, forKey: "pinOnTop") }
    }
    /// The F1–F12 shortcuts on Mac keyboards (an event tap; needs the Accessibility permission).
    var topRowKeys: Bool { true }   // always: F1 should just work, as on Windows
    /// Text recognition: its buttons, menu items and F4 / ⇧F4. Off until turned on.
    var ocrEnabled: Bool {
        get { d.object(forKey: "ocrEnabled") as? Bool ?? false }
        set { d.set(newValue, forKey: "ocrEnabled") }
    }
    /// Index into Palette.colors and Palette.sizes, remembered between captures.
    var colorIndex: Int {
        get { d.object(forKey: "colorIndex") as? Int ?? 0 }
        set { d.set(newValue, forKey: "colorIndex") }
    }
    /// The width of the drawing tools (also sets text size, number size and mosaic squares).
    /// Where ⇧F1 (quick capture) saves: the Desktop unless chosen.
    var quickFolder: URL {
        get {
            if let p = d.string(forKey: "quickFolder") { return URL(fileURLWithPath: p, isDirectory: true) }
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
        }
        set { d.set(newValue.path, forKey: "quickFolder") }
    }
    /// ⇧F1 quick capture (and its menu item): off until turned on.
    var quickEnabled: Bool {
        get { d.object(forKey: "quickEnabled") as? Bool ?? false }
        set { d.set(newValue, forKey: "quickEnabled") }
    }
    /// After a quick capture: a banner (with the path), or only the menu bar scissors snipping.
    var quickNotice: Bool {
        get { d.object(forKey: "quickNotice") as? Bool ?? false }
        set { d.set(newValue, forKey: "quickNotice") }
    }
    /// Where that banner shows: "topRight", "bottomRight", "topCenter" or "center".
    var noticePosition: String {
        get { d.string(forKey: "noticePosition") ?? "topRight" }
        set { d.set(newValue, forKey: "noticePosition") }
    }
    /// Ask before leaving a capture that has drawings (Esc, ✕, right-click back).
    var askBeforeLeaving: Bool {
        get { d.object(forKey: "askBeforeLeaving") as? Bool ?? true }
        set { d.set(newValue, forKey: "askBeforeLeaving") }
    }
    /// The capture toolbar: "system" (follows macOS), "light" or "dark".
    var toolbarTheme: String {
        get { d.string(forKey: "toolbarTheme") ?? "system" }
        set { d.set(newValue, forKey: "toolbarTheme") }
    }

    /// Each tool has its own size, remembered between captures; one does not change another.
    /// The defaults are on the small side: lines 3 px, text about 17 pt, numbers about 19 pt across.
    static let defaultWidths: [Tool: CGFloat] = [.rect: 3, .ellipse: 3, .line: 3, .arrow: 3, .pen: 3,
                                                  .marker: 3, .mosaic: 4, .text: 3, .number: 3]
    private var widths: [Tool: CGFloat] = [:]

    func width(for t: Tool) -> CGFloat {
        if let w = widths[t] { return w }
        let w = (d.object(forKey: "width.\(t)") as? Double).map { CGFloat($0) } ?? Self.defaultWidths[t] ?? 3
        widths[t] = w
        return w
    }

    /// Each tool's opacity too (1 = opaque), remembered between captures.
    private var opacities: [Tool: CGFloat] = [:]
    func opacity(for t: Tool) -> CGFloat {
        if let o = opacities[t] { return o }
        let o = (d.object(forKey: "opacity.\(t)") as? Double).map { CGFloat($0) } ?? 1
        opacities[t] = o
        return o
    }
    func setOpacity(_ o: CGFloat, for t: Tool) {
        opacities[t] = o
        d.set(Double(o), forKey: "opacity.\(t)")
    }

    func setWidth(_ w: CGFloat, for t: Tool) {
        widths[t] = w
        d.set(Double(w), forKey: "width.\(t)")
    }
    var mosaicMode: MosaicMode {
        get { MosaicMode(rawValue: d.string(forKey: "mosaicMode") ?? "") ?? .rect }   // "fill" from before: a box
        set { d.set(newValue.rawValue, forKey: "mosaicMode") }
    }
    /// The hide tool covers with the color instead of mosaic.
    var mosaicSolid: Bool {
        get { d.bool(forKey: "mosaicSolid") }
        set { d.set(newValue, forKey: "mosaicSolid") }
    }

    /// nil: no shortcut for that action.
    func hotkey(_ a: HotAction) -> HotKey? {
        let key = "hotkey." + a.rawValue
        guard let data = d.data(forKey: key) else { return a.defaultKey }
        if data.isEmpty { return nil }
        return (try? JSONDecoder().decode(HotKey.self, from: data)) ?? a.defaultKey
    }
    func setHotkey(_ a: HotAction, _ k: HotKey?) {
        let key = "hotkey." + a.rawValue
        if let k, let data = try? JSONEncoder().encode(k) { d.set(data, forKey: key) } else { d.set(Data(), forKey: key) }
    }
}

/// A field that records a shortcut: click it, then press the keys. Delete or Backspace clears it.
final class HotKeyField: NSButton {
    var hotkey: HotKey? { didSet { refresh() } }
    var onChange: ((HotKey?) -> Void)?
    private var recording = false { didSet { refresh(); HotKeyField.active = recording ? self : nil } }

    /// The field recording now: the event tap hands it the F keys (it would run their shortcuts
    /// otherwise, since on a Mac keyboard F1 without fn never reaches a key-down here).
    static weak var active: HotKeyField?

    /// An F key seen by the event tap while recording.
    func takeFKey(_ code: Int, mods: UInt32) {
        guard recording, let label = HotKey.fKeys[code] else { return }
        hotkey = HotKey(keyCode: UInt32(code), mods: mods, label: label)
        onChange?(hotkey)
        window?.makeFirstResponder(nil)
    }

    init(_ k: HotKey?) {
        hotkey = k
        super.init(frame: .zero)
        bezelStyle = .push
        controlSize = .small
        font = .monospacedSystemFont(ofSize: 11.5, weight: .medium)
        setButtonType(.momentaryPushIn)
        target = self; action = #selector(start)
        widthAnchor.constraint(equalToConstant: 120).isActive = true
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func refresh() {
        title = recording ? L.t("recordHint") : (hotkey?.display ?? L.t("none"))
    }

    @objc private func start() {
        recording = true
        HotKeyCenter.shared.unregisterAll()   // so the old shortcut can be pressed again
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }
    override func resignFirstResponder() -> Bool {
        if recording { recording = false; HotKeyCenter.shared.registerAll() }
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with e: NSEvent) -> Bool {
        if recording { keyDown(with: e); return true }
        return super.performKeyEquivalent(with: e)
    }

    override func keyDown(with e: NSEvent) {
        guard recording else { super.keyDown(with: e); return }
        let code = Int(e.keyCode)
        if code == 0x35 { window?.makeFirstResponder(nil); return }                // Esc: keep the old one
        if (code == 0x33 || code == 0x75) && e.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            hotkey = nil                                                           // Backspace / Delete
        } else {
            guard let label = HotKey.label(for: e) else { return }
            let mods = HotKey.carbonMods(e.modifierFlags)
            let isF = HotKey.fKeys[code] != nil
            if mods == 0 && !isF { NSSound.beep(); return }   // a plain letter would block typing everywhere
            hotkey = HotKey(keyCode: UInt32(code), mods: mods, label: label)
        }
        onChange?(hotkey)
        window?.makeFirstResponder(nil)
    }
}

/// Settings, in the style of System Settings: grouped cards, a switch at the end of each row.
final class SettingsWindow: NSWindowController, NSWindowDelegate {
    static var shared: SettingsWindow?

    static func show() {
        if shared == nil { shared = SettingsWindow() }
        NSApp.activate(ignoringOtherApps: true)
        shared?.window?.center()
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        shared?.refreshPermissions()
    }

    private let status = NSTextField(wrappingLabelWithString: "")
    private let permState = NSTextField(labelWithString: "")
    private let permIcon = NSImageView()
    private let width: CGFloat = 500

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]   // opens on the current desktop
        w.title = L.t("settings").replacingOccurrences(of: "…", with: "")
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.delegate = self
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: building blocks

    private func header(_ s: String) -> NSView {
        let l = NSTextField(labelWithString: s)
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .secondaryLabelColor
        let v = NSStackView(views: [l])
        v.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        return v
    }

    /// A row: title (and a smaller line under it), then the control at the end.
    private func row(_ title: String, _ detail: String? = nil, _ control: NSView) -> NSView {
        let t = NSTextField(labelWithString: title)
        t.font = .systemFont(ofSize: 13)
        var texts: [NSView] = [t]
        if let detail {
            let d = NSTextField(wrappingLabelWithString: detail)
            d.font = .systemFont(ofSize: 11)
            d.textColor = .secondaryLabelColor
            d.preferredMaxLayoutWidth = 300
            texts.append(d)
        }
        let text = NSStackView(views: texts)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        text.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let r = NSStackView(views: [text, spacer, control])
        r.alignment = .centerY
        r.spacing = 12
        r.edgeInsets = NSEdgeInsets(top: 9, left: 14, bottom: 9, right: 14)
        r.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        return r
    }

    /// Rows in one card, with hairlines between them.
    private func group(_ rows: [NSView]) -> NSView {
        var views: [NSView] = []
        for (i, r) in rows.enumerated() {
            if i > 0 {
                let line = NSBox()
                line.boxType = .separator
                let inset = NSStackView(views: [line])
                inset.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 0)
                views.append(inset)
            }
            views.append(r)
        }
        let st = NSStackView(views: views)
        st.orientation = .vertical
        st.spacing = 0
        for v in views { v.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true }
        return card(st, inset: 0)
    }

    private func toggle(_ on: Bool, _ action: Selector) -> NSSwitch {
        let s = NSSwitch()
        s.controlSize = .small
        s.state = on ? .on : .off
        s.target = self
        s.action = action
        return s
    }

    // MARK: the page

    private func build() {
        let bg = NSVisualEffectView()
        bg.material = .underWindowBackground
        bg.blendingMode = .behindWindow
        bg.state = .active

        // shortcuts
        var keyRows: [NSView] = []
        for a in HotAction.allCases {
            let f = HotKeyField(Prefs.shared.hotkey(a))
            f.onChange = { [weak self] k in
                Prefs.shared.setHotkey(a, k)
                let failed = HotKeyCenter.shared.registerAll()
                self?.status.stringValue = failed.contains(a) ? L.t("hkConflict") : ""
                self?.status.textColor = failed.contains(a) ? .systemRed : .secondaryLabelColor
            }
            keyRows.append(row(a.title, nil, f))
        }

        // general
        let lang = NSPopUpButton()
        lang.controlSize = .small
        let names: [(L.Lang, String)] = [(.system, L.t("langSystem")), (.en, "English"),
                                         (.zhHans, "简体中文"), (.zhHant, "繁體中文")]
        for (code, name) in names {
            lang.addItem(withTitle: name); lang.lastItem?.representedObject = code.rawValue
            if Prefs.shared.language == code.rawValue { lang.select(lang.lastItem) }
        }
        lang.target = self; lang.action = #selector(pickLang(_:))
        folderButton.controlSize = .small
        folderButton.bezelStyle = .push
        folderButton.target = self
        folderButton.action = #selector(chooseFolder)
        folderButton.title = folderTitle()
        let theme = NSPopUpButton()
        theme.controlSize = .small
        for (code, key) in [("system", "themeSystem"), ("light", "themeLight"), ("dark", "themeDark")] {
            theme.addItem(withTitle: L.t(key)); theme.lastItem?.representedObject = code
            if Prefs.shared.toolbarTheme == code { theme.select(theme.lastItem) }
        }
        theme.target = self; theme.action = #selector(pickTheme(_:))
        let noticePlace = NSPopUpButton()
        noticePlace.controlSize = .small
        for (code, key) in [("topRight", "posTopRight"), ("bottomRight", "posBottomRight"), ("topCenter", "posTopCenter"), ("center", "posCenter")] {
            noticePlace.addItem(withTitle: L.t(key)); noticePlace.lastItem?.representedObject = code
            if Prefs.shared.noticePosition == code { noticePlace.select(noticePlace.lastItem) }
        }
        noticePlace.target = self; noticePlace.action = #selector(pickNoticePlace(_:))
        let general = group([
            row(L.t("launchAtLogin"), nil, toggle(SMAppService.mainApp.status == .enabled, #selector(toggleLogin(_:)))),
            row(L.t("ocrTitle2"), L.t("ocrDetail"), toggle(Prefs.shared.ocrEnabled, #selector(toggleOCR(_:)))),
            row(L.t("pinTop"), nil, toggle(Prefs.shared.pinOnTop, #selector(togglePinTop(_:)))),
            row(L.t("askLeave"), nil, toggle(Prefs.shared.askBeforeLeaving, #selector(toggleAskLeave(_:)))),
            row(L.t("toolbarTheme"), nil, theme),
            row(L.t("language"), nil, lang),
        ])
        let quick = group([
            row(L.t("quickEnable"), L.t("quickFolderDetail"), toggle(Prefs.shared.quickEnabled, #selector(toggleQuick(_:)))),
            row(L.t("quickFolder"), nil, folderButton),
            row(L.t("quickNotice"), L.t("quickNoticeDetail"), toggle(Prefs.shared.quickNotice, #selector(toggleQuickNotice(_:)))),
            row(L.t("noticePosition"), nil, noticePlace),
        ])

        // permissions: their state and the button to the permissions page
        permIcon.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
        permState.font = .systemFont(ofSize: 12)
        let manage = NSButton(title: L.t("manage"), target: self, action: #selector(openPermissions))
        manage.controlSize = .small
        manage.bezelStyle = .push
        let permRight = NSStackView(views: [permIcon, permState, manage])
        permRight.spacing = 6
        permRight.alignment = .centerY
        permRight.setCustomSpacing(12, after: permState)
        let perms = group([row(L.t("permStatus"), nil, permRight)])

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.stringValue = ""
        status.preferredMaxLayoutWidth = width - 60
        let foot = NSStackView(views: [status])
        foot.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)

        // pages behind tabs at the top: one at a time, the window as tall as it
        pages = [group(keyRows), general, quick, perms]
        let tabs = SettingsTabs(items: [("keyboard", L.t("hotkeys")), ("gearshape", L.t("general")),
                                        ("camera.viewfinder", L.t("quickTab")), ("lock.shield", L.t("permissions"))]) { [weak self] i in
            self?.showPage(i)
        }
        tabs.translatesAutoresizingMaskIntoConstraints = false
        pageHost.orientation = .vertical
        pageHost.alignment = .leading
        pageHost.spacing = 12
        pageHost.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(tabs)
        bg.addSubview(pageHost)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: bg.topAnchor, constant: 36),
            tabs.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            pageHost.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 18),
            pageHost.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 22),
            pageHost.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -22),
            pageHost.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -20),
            bg.widthAnchor.constraint(equalToConstant: width),
        ])
        footer = foot
        window?.contentView = bg
        refreshPermissions()
        showPage(0)
    }

    private var pages: [NSView] = []
    private let pageHost = NSStackView()
    private var footer: NSView?

    private func showPage(_ i: Int) {
        pageHost.arrangedSubviews.forEach { pageHost.removeArrangedSubview($0); $0.removeFromSuperview() }
        for v in [pages[i]] + (footer.map { [$0] } ?? []) {
            pageHost.addArrangedSubview(v)
            v.widthAnchor.constraint(equalTo: pageHost.widthAnchor).isActive = true
        }
        // the window fits the page, its top edge staying
        guard let w = window, let cv = w.contentView else { return }
        cv.layoutSubtreeIfNeeded()
        let h = ceil(cv.fittingSize.height)
        var f = w.frame
        let target = w.frameRect(forContentRect: NSRect(x: 0, y: 0, width: w.contentRect(forFrameRect: f).width, height: h))
        f.origin.y += f.height - target.height
        f.size.height = target.height
        w.setFrame(f, display: true, animate: w.isVisible)
    }

    private func refreshPermissions() {
        let missing = Permission.allCases.filter { $0.required && !$0.granted }.count
        if missing == 0 {
            permIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            permIcon.contentTintColor = .systemGreen
            permState.stringValue = L.t("permAllOK")
            permState.textColor = .secondaryLabelColor
        } else {
            permIcon.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
            permIcon.contentTintColor = .systemOrange
            permState.stringValue = String(format: L.t("permMissing"), missing)
            permState.textColor = .systemOrange
        }
    }

    // MARK: actions

    @objc private func toggleLogin(_ b: NSSwitch) {
        do {
            if b.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            status.stringValue = error.localizedDescription
            status.textColor = .systemRed
            b.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc private func toggleOCR(_ b: NSSwitch) {
        Prefs.shared.ocrEnabled = b.state == .on
        HotKeyCenter.shared.registerAll()
    }

    @objc private func togglePinTop(_ b: NSSwitch) {
        Prefs.shared.pinOnTop = b.state == .on
        PinWindow.applyLevelToAll()
    }

    @objc private func pickLang(_ p: NSPopUpButton) {
        Prefs.shared.language = p.selectedItem?.representedObject as? String ?? "system"
        status.stringValue = L.t("langRestart")
        status.textColor = .secondaryLabelColor
    }

    @objc private func openPermissions() { PermissionsWindow.show() }

    private let folderButton = NSButton(title: "", target: nil, action: nil)

    private func folderTitle() -> String {
        FileManager.default.displayName(atPath: Prefs.shared.quickFolder.path)
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = Prefs.shared.quickFolder
        panel.prompt = L.t("chooseFolder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Prefs.shared.quickFolder = url
        folderButton.title = folderTitle()
    }

    @objc private func toggleQuick(_ b: NSSwitch) {
        Prefs.shared.quickEnabled = b.state == .on
        HotKeyCenter.shared.registerAll()
    }

    @objc private func toggleQuickNotice(_ b: NSSwitch) { Prefs.shared.quickNotice = b.state == .on }

    @objc private func pickNoticePlace(_ p: NSPopUpButton) {
        Prefs.shared.noticePosition = p.selectedItem?.representedObject as? String ?? "topRight"
    }

    @objc private func toggleAskLeave(_ b: NSSwitch) { Prefs.shared.askBeforeLeaving = b.state == .on }

    @objc private func pickTheme(_ p: NSPopUpButton) {
        Prefs.shared.toolbarTheme = p.selectedItem?.representedObject as? String ?? "system"
    }

    func windowDidBecomeKey(_ notification: Notification) { refreshPermissions() }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}

/// Tabs at the top of Settings: a soft capsule, the chosen tab a raised white piece with an
/// icon and a name.
final class SettingsTabs: NSView {
    private var buttons: [NSButton] = []
    private let onPick: (Int) -> Void
    private var chosen = 0

    init(items: [(String, String)], onPick: @escaping (Int) -> Void) {
        self.onPick = onPick
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        let row = NSStackView()
        row.spacing = 2
        row.edgeInsets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        row.translatesAutoresizingMaskIntoConstraints = false
        for (i, (symbol, name)) in items.enumerated() {
            let b = NSButton(title: name, image: NSImage(systemSymbolName: symbol, accessibilityDescription: name)!,
                             target: self, action: #selector(pick(_:)))
            b.tag = i
            b.isBordered = false
            b.imagePosition = .imageLeading
            b.imageHugsTitle = true
            b.font = .systemFont(ofSize: 12, weight: .medium)
            b.symbolConfiguration = .init(pointSize: 12, weight: .medium)
            b.wantsLayer = true
            b.layer?.cornerRadius = 7
            b.translatesAutoresizingMaskIntoConstraints = false
            b.heightAnchor.constraint(equalToConstant: 28).isActive = true
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
            buttons.append(b)
            row.addArrangedSubview(b)
        }
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor), row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor), row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func pick(_ b: NSButton) {
        chosen = b.tag
        refresh()
        onPick(chosen)
    }

    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); refresh() }

    private func refresh() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = (dark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.06)).cgColor
        for (i, b) in buttons.enumerated() {
            let on = i == chosen
            b.layer?.backgroundColor = on ? (dark ? NSColor(white: 0.32, alpha: 1) : NSColor.white).cgColor : NSColor.clear.cgColor
            b.layer?.shadowOpacity = on ? (dark ? 0.4 : 0.14) : 0
            b.layer?.shadowRadius = 2
            b.layer?.shadowOffset = CGSize(width: 0, height: -1)
            b.contentTintColor = on ? .labelColor : .secondaryLabelColor
        }
    }
}
