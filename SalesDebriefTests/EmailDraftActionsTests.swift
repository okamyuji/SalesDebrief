import Foundation
@testable import SalesDebrief
import SalesDebriefCore
import XCTest

@MainActor
final class EmailDraftActionsTests: XCTestCase {
    func testCopySubjectUsesSubjectOnly() {
        let recorder = CopyRecorder()
        let actions = EmailDraftActions(copyText: recorder.copy(_:))
        let draft = EmailDraft(subject: "Subject", body: "Body")

        let feedback = actions.copySubject(from: draft)

        XCTAssertEqual(recorder.copiedValues, ["Subject"])
        XCTAssertEqual(feedback, String(localized: "email.copied_subject"))
    }

    func testCopyBodyUsesBodyOnly() {
        let recorder = CopyRecorder()
        let actions = EmailDraftActions(copyText: recorder.copy(_:))
        let draft = EmailDraft(subject: "Subject", body: "Body")

        let feedback = actions.copyBody(from: draft)

        XCTAssertEqual(recorder.copiedValues, ["Body"])
        XCTAssertEqual(feedback, String(localized: "email.copied_body"))
    }
}

@MainActor
private final class CopyRecorder {
    private(set) var copiedValues: [String] = []

    func copy(_ value: String) {
        copiedValues.append(value)
    }
}
