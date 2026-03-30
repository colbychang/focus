import Testing
@testable import FocusCore

@Suite("Focus Tests")
struct FocusTests {
    @Test("FocusCore is importable and has correct app group identifier")
    func focusCoreImportable() {
        #expect(FocusCore.appGroupIdentifier == "group.com.colbychang.focus.shared")
    }
}
