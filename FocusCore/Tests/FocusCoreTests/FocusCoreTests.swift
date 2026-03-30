import Testing
@testable import FocusCore

@Suite("FocusCore Tests")
struct FocusCoreTests {
    @Test("App group identifier is correct")
    func appGroupIdentifier() {
        #expect(FocusCore.appGroupIdentifier == "group.com.colbychang.focus.shared")
    }

    @Test("Version is set")
    func version() {
        #expect(!FocusCore.version.isEmpty)
    }
}
