import XCTest

@MainActor
final class XianxiaStage1UITests: XCTestCase {
    private let proxyBaseURL = URL(string: "http://127.0.0.1:17881")!

    override func setUpWithError() throws {
        continueAfterFailure = false
        if requiresProxyControl {
            try Self.setProxyMode("online")
        }
    }

    override func tearDownWithError() throws {
        if requiresProxyControl {
            try Self.setProxyMode("online")
        }
    }

    func testStage1TopicFeedDetailPaginationAndOfflineFallbackOnIPhone15Pro() throws {
        let app = configuredApp()

        app.launch()

        let feedScrollView = app.scrollViews["xianxia.feed.scrollView"]
        XCTAssertTrue(feedScrollView.waitForExistence(timeout: 20))

        let firstTopicCard = app.buttons.matching(identifier: "xianxia.topicCard").firstMatch
        XCTAssertTrue(firstTopicCard.waitForExistence(timeout: 20))

        firstTopicCard.tap()

        let detailScrollView = app.scrollViews["xianxia.topicDetail.scrollView"]
        XCTAssertTrue(detailScrollView.waitForExistence(timeout: 20))
        waitForStaticTextCount(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Shard #")),
            atLeast: 2,
            in: detailScrollView,
            timeout: 20
        )

        app.buttons["xianxia.topicDetail.back"].tap()
        XCTAssertTrue(firstTopicCard.waitForExistence(timeout: 10))

        app.terminate()
        try Self.setProxyMode("offline")

        app.launch()

        let cachedTopicCard = app.buttons.matching(identifier: "xianxia.topicCard").firstMatch
        XCTAssertTrue(cachedTopicCard.waitForExistence(timeout: 20))
        cachedTopicCard.tap()

        XCTAssertTrue(app.scrollViews["xianxia.topicDetail.scrollView"].waitForExistence(timeout: 20))
        waitForStaticTextCount(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Shard #")),
            atLeast: 2,
            in: app.scrollViews["xianxia.topicDetail.scrollView"],
            timeout: 20
        )
    }

    func testMastersDirectoryShows8CardsAndOpensOneToOneOnIPhone15Pro() throws {
        let app = XCUIApplication()

        app.launch()

        let mastersTab = app.buttons["main-tab-master"]
        XCTAssertTrue(mastersTab.waitForExistence(timeout: 20))
        mastersTab.tap()

        let cardQuery = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "master-stage1-card-")
        )
        let firstCard = cardQuery.firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 20))
        waitForElementCount(cardQuery, atLeast: 8, timeout: 20)

        firstCard.tap()

        let conversationIdentity = app.descendants(matching: .any)
            .matching(identifier: "master-conversation-identity")
            .firstMatch
        XCTAssertTrue(conversationIdentity.waitForExistence(timeout: 20))

        let composerInput = app.descendants(matching: .any)
            .matching(identifier: "master-composer-input")
            .firstMatch
        XCTAssertTrue(composerInput.waitForExistence(timeout: 20))
    }

    private func configuredApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["XIANXIA_TOPICS_BASE_URL"] = "http://127.0.0.1:17881/v1/clawdb-topics"
        app.launchEnvironment["XIANXIA_TOPICS_TENANT_ID"] = "default"
        app.launchEnvironment["XIANXIA_TOPICS_FEED_BATCH_SIZE"] = "2"
        app.launchEnvironment["XIANXIA_TOPICS_SHARD_BATCH_SIZE"] = "1"
        return app
    }

    private var requiresProxyControl: Bool {
        name.contains("TopicFeed")
    }

    private nonisolated static func setProxyMode(_ mode: String) throws {
        var components = URLComponents(
            url: URL(string: "http://127.0.0.1:17881")!.appendingPathComponent("__control"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "mode", value: mode)]
        guard let url = components?.url else {
            XCTFail("Failed to build proxy control URL")
            return
        }

        let data = try Data(contentsOf: url)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(payload?["mode"] as? String, mode)
    }

    private func waitForElementCount(
        _ query: XCUIElementQuery,
        atLeast expectedCount: Int,
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if query.count >= expectedCount {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        XCTFail(
            "Expected at least \(expectedCount) elements for \(query.debugDescription), found \(query.count)",
            file: file,
            line: line
        )
    }

    private func waitForStaticTextCount(
        _ query: XCUIElementQuery,
        atLeast expectedCount: Int,
        in scrollView: XCUIElement,
        timeout: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if query.count >= expectedCount {
                return
            }

            if scrollView.exists {
                scrollView.swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        XCTFail(
            "Expected at least \(expectedCount) shard labels, found \(query.count)",
            file: file,
            line: line
        )
    }
}
