import ScreenCaptureKit

/// ScreenCaptureKit's calls, through their completion handlers. Their `async` forms, made by Swift
/// from those handlers, stop the app when a handler brings neither a result nor an error, as
/// macOS does now and then (seen while the Mac woke briefly in its sleep). Here that is a failure
/// like any other; a handler called a second time is let go.
enum SCK {
    struct Empty: Error {}

    /// The display list.
    static func shareableContent() async throws -> SCShareableContent {
        try await bridge { SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true, completionHandler: $0) }
    }

    /// An area of the screen, in global display coordinates (macOS 15.2 and later); nil if it failed.
    @available(macOS 15.2, *)
    static func image(in rect: CGRect) async -> CGImage? {
        try? await bridge { SCScreenshotManager.captureImage(in: rect, completionHandler: $0) }
    }

    /// One display, as a filter and a configuration say; nil if it failed.
    static func image(_ filter: SCContentFilter, _ cfg: SCStreamConfiguration) async -> CGImage? {
        try? await bridge { SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg, completionHandler: $0) }
    }

    /// Turns a call that answers once, with a value or an error, into a value or a thrown error.
    static func bridge<T>(_ call: (@escaping @Sendable (T?, Error?) -> Void) -> Void) async throws -> T {
        let once = Once()
        let box: UncheckedBox<T> = try await withCheckedThrowingContinuation { c in
            call { value, error in
                guard once.first() else { return }
                if let value { c.resume(returning: UncheckedBox(value)) } else { c.resume(throwing: error ?? Empty()) }
            }
        }
        return box.value
    }
    /// True the first time only, from any thread.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func first() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
    }
    private struct UncheckedBox<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }
}
