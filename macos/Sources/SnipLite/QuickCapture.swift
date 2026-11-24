import AppKit

/// ⇧F1: the screen under the mouse straight to a file, no capture screen (from sniplite 1.4 for
/// Windows). The file goes to the folder chosen in Settings (the Desktop by default); a notice
/// like a macOS banner says so, and a click on it shows the file in Finder.
enum QuickCapture {
    static func run() {
        Task { @MainActor in
            guard Permission.screenRecording.granted else { PermissionsWindow.show(); return }
            Notice.hide()                                 // the last one's: not in this picture
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
            do {
                guard let shot = try await Capture.captureAll(only: screen).first else { return }
                let url = try save(shot)
                Log.write("quick capture: \(url.path)")
                AppDelegate.snip()                        // the menu bar icon says it every time
                if Prefs.shared.quickNotice {             // and the banner, with where it went, if wanted
                    Notice.show(.picture(shot.image), L.t("quickSaved"), place(of: url), on: screen, tip: L.t("showInFinder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            } catch CaptureError.noPermission {
                AppDelegate.askForPermission()
            } catch {
                NSSound.beep()
                Log.write("quick capture failed: \(error)")
            }
            CaptureSession.releaseMemory()
        }
    }

    /// sniplite_<date>_<time>.png in the folder; a number added if that name is taken.
    static func save(_ shot: DisplayShot) throws -> URL {
        let folder = Prefs.shared.quickFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        let base = "sniplite_\(f.string(from: Date()))"
        var url = folder.appendingPathComponent(base + ".png")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base)_\(n).png"); n += 1
        }
        let rep = NSBitmapImageRep(cgImage: shot.image)
        rep.size = shot.screen.frame.size
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.failed("png")
        }
        try data.write(to: url)
        return url
    }

    /// The folder in sniplite's language (the Desktop), then the file name.
    private static func place(of file: URL) -> String {
        let folder = file.deletingLastPathComponent().standardizedFileURL
        let name = folder == FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.standardizedFileURL
            ? L.t("desktopName") : FileManager.default.displayName(atPath: folder.path)
        return name + " · " + file.lastPathComponent
    }
}
