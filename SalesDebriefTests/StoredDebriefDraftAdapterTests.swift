import Foundation
@testable import SalesDebrief
import SalesDebriefCore
import XCTest

final class StoredDebriefDraftAdapterTests: XCTestCase {
    func testMakeDraftPreservesEditableFieldsAndIdentifier() {
        let visitAt = Date(timeIntervalSince1970: 321)
        let followUpDueAt = Date(timeIntervalSince1970: 654)
        let record = StoredDebrief(
            id: UUID(),
            accountName: "Acme Dental",
            visitAt: visitAt,
            contactName: "Dr. Rivera",
            visitObjective: "Review rollout",
            whatHappened: "Requested pricing.",
            interestLevel: "",
            objectionsOrConcerns: "Training time",
            competitorMentions: "Medisoft",
            nextAction: "Send quote",
            followUpDueAt: followUpDueAt,
            internalNote: "Priority account",
            rawTranscript: "Transcript",
            emailSubject: "Subject",
            emailBody: "Body",
            toneRawValue: EmailTone.directConcise.rawValue
        )

        let draft = record.makeDraft()

        XCTAssertEqual(draft.storedRecordID, record.id)
        XCTAssertEqual(draft.rawTranscript, "Transcript")
        XCTAssertEqual(draft.editableFields.accountName, "Acme Dental")
        XCTAssertEqual(draft.editableFields.contactName, "Dr. Rivera")
        XCTAssertEqual(draft.editableFields.followUpDueAt, followUpDueAt)
    }
}
