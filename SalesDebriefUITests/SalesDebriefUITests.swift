import XCTest

@MainActor
final class SalesDebriefUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCanCreateManualDebrief() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["home.new"].tap()

        let transcript = app.textViews["capture.transcript"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 5))
        transcript.tap()
        transcript.typeText(
            "Visited Acme Dental. Spoke with Dr. Rivera. What happened was they want pricing. Next action is send pricing tomorrow."
        )

        app.buttons["capture.continue"].tap()
        XCTAssertTrue(app.buttons["recap.save"].waitForExistence(timeout: 5))
        app.buttons["recap.save"].tap()

        XCTAssertTrue(app.buttons["home.new"].waitForExistence(timeout: 5))
    }

    func testCanPreviewEmailBeforeSaving() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["home.new"].tap()

        let transcript = app.textViews["capture.transcript"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 5))
        transcript.tap()
        transcript.typeText("Visited Acme Dental. What happened was they want pricing.")

        app.buttons["capture.continue"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["recap.preview_email"].waitForExistence(timeout: 5))
        app.buttons["recap.preview_email"].tap()

        XCTAssertTrue(app.buttons["email.share"].waitForExistence(timeout: 5))
    }

    func testCanOpenSavedDebriefFromHistory() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["home.new"].tap()

        let transcript = app.textViews["capture.transcript"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 5))
        transcript.tap()
        transcript.typeText("Visited Acme Dental. Spoke with Dr. Rivera. What happened was they want pricing.")

        app.buttons["capture.continue"].tap()
        XCTAssertTrue(app.buttons["recap.save"].waitForExistence(timeout: 5))
        app.buttons["recap.save"].tap()

        XCTAssertTrue(app.buttons["home.history"].waitForExistence(timeout: 5))
        app.buttons["home.history"].tap()

        let firstHistoryRow = app.buttons["history.row.Acme Dental"].firstMatch
        XCTAssertTrue(firstHistoryRow.waitForExistence(timeout: 5))
        firstHistoryRow.tap()
        XCTAssertTrue(app.buttons["history.edit"].waitForExistence(timeout: 5))
    }

    func testRecentVisitNoteOpensDetailFromHome() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["home.new"].tap()

        let transcript = app.textViews["capture.transcript"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 5))
        transcript.tap()
        transcript.typeText("Visited Acme Dental. What happened was they want pricing.")

        app.buttons["capture.continue"].tap()
        XCTAssertTrue(app.buttons["recap.save"].waitForExistence(timeout: 5))
        app.buttons["recap.save"].tap()

        let recentRow = app.buttons["home.recent.Acme Dental"].firstMatch
        XCTAssertTrue(recentRow.waitForExistence(timeout: 5))
        recentRow.tap()

        XCTAssertTrue(app.buttons["history.edit"].waitForExistence(timeout: 5))
    }
}
