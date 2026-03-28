import XCTest
@testable import SpareLifeCore

final class SpareLifeCoreSmokeTests: XCTestCase {
    func testMainTabsExposeExpectedCount() {
        XCTAssertEqual(MainTab.allCases.count, 5)
    }
}
