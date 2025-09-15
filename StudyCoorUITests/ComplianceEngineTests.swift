//
//  ComplianceEngineTests (UI)
//  Converted to a simple UI smoke test to avoid importing app internals here.
//

import XCTest

final class ComplianceEngineTests: XCTestCase {

    @MainActor
    func testLaunchAndNavigateTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // Ensure main tabs exist
        XCTAssertTrue(app.tabBars.buttons["Calculator"].exists)
        XCTAssertTrue(app.tabBars.buttons["History"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        // Navigate to History and back
        app.tabBars.buttons["History"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.tabBars.buttons["Calculator"].tap()
    }
}
