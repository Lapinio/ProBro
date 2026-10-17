import Testing
@testable import ProBro

struct ProBroTests {
    @Test func greetingMatchesPlatform() {
        #if os(macOS)
        #expect(Platform.current == .macOS)
        #else
        #expect(Platform.current == .iOS)
        #endif
        #expect(!Platform.current.greeting.isEmpty)
    }
}
