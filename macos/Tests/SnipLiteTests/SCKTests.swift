import Testing
import Foundation
@testable import SnipLite

/// Completion handlers as ScreenCaptureKit calls them, the odd ways included.
@Test func aHandlerWithNothingIsAFailure() async {
    await #expect(throws: SCK.Empty.self) { try await SCK.bridge { (done: @escaping @Sendable (Int?, Error?) -> Void) in done(nil, nil) } }
}

@Test func aHandlerWithAnErrorThrowsIt() async {
    struct E: Error {}
    await #expect(throws: E.self) { try await SCK.bridge { (done: @escaping @Sendable (Int?, Error?) -> Void) in done(nil, E()) } }
}

@Test func aHandlerCalledTwiceAnswersOnce() async throws {
    let v = try await SCK.bridge { (done: @escaping @Sendable (Int?, Error?) -> Void) in
        DispatchQueue.global().async { done(7, nil); done(nil, nil); done(8, nil) }
    }
    #expect(v == 7)
    try await Task.sleep(nanoseconds: 50_000_000)
}
