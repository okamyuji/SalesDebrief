@testable import SalesDebrief
import SalesDebriefCore
import XCTest

@MainActor
final class RecapEditorViewModelTests: XCTestCase {
    func testMakeFieldsTrimsOptionalValues() {
        let parseResult = RecapParseResult(
            fields: RecapFields(
                accountName: "Acme",
                visitAt: .now,
                contactName: nil,
                visitObjective: nil,
                whatHappened: " Interested in a rollout ",
                interestLevel: nil,
                objectionsOrConcerns: nil,
                competitorMentions: nil,
                nextAction: nil,
                followUpDueAt: nil,
                internalNote: nil
            ),
            confidenceByField: [:],
            unmatchedTranscriptSegments: [],
            warnings: []
        )
        let draft = RecapDraft(
            rawTranscript: "raw",
            parseResult: parseResult,
            editableFields: parseResult.fields,
            storedRecordID: nil
        )
        let viewModel = RecapEditorViewModel(
            draft: draft,
            generator: EmailDraftGenerator(),
            store: StubStoredDebriefStore()
        )
        viewModel.accountName = "  Acme Dental  "
        viewModel.contactName = "  Dr. Rivera "
        viewModel.whatHappened = " Confirmed interest. "

        let fields = viewModel.makeFields()

        XCTAssertEqual(fields.accountName, "Acme Dental")
        XCTAssertEqual(fields.contactName, "Dr. Rivera")
        XCTAssertEqual(fields.whatHappened, "Confirmed interest.")
    }

    func testMakeEmailDraftUsesSelectedTone() {
        let parseResult = RecapParseResult(
            fields: RecapFields(
                accountName: "Acme",
                visitAt: .now,
                contactName: "Dr. Rivera",
                visitObjective: nil,
                whatHappened: "You asked for pricing.",
                interestLevel: nil,
                objectionsOrConcerns: nil,
                competitorMentions: nil,
                nextAction: "I will send pricing.",
                followUpDueAt: nil,
                internalNote: nil
            ),
            confidenceByField: [:],
            unmatchedTranscriptSegments: [],
            warnings: []
        )
        let store = StubStoredDebriefStore()
        let draft = RecapDraft(
            rawTranscript: "raw",
            parseResult: parseResult,
            editableFields: parseResult.fields,
            storedRecordID: UUID()
        )
        let viewModel = RecapEditorViewModel(
            draft: draft,
            generator: EmailDraftGenerator(),
            store: store
        )
        viewModel.selectedTone = .warmConsultative

        let email = viewModel.makeEmailDraft(locale: Locale(identifier: "en"))

        XCTAssertEqual(email.subject, "Thank you for meeting today")
    }

    func testSaveUsesExistingStoredRecordIdentifier() throws {
        let store = StubStoredDebriefStore()
        let identifier = UUID()
        let parseResult = RecapParseResult(
            fields: RecapFields(
                accountName: "Acme",
                visitAt: .now,
                contactName: "Dr. Rivera",
                visitObjective: nil,
                whatHappened: "You asked for pricing.",
                interestLevel: nil,
                objectionsOrConcerns: nil,
                competitorMentions: nil,
                nextAction: nil,
                followUpDueAt: nil,
                internalNote: nil
            ),
            confidenceByField: [:],
            unmatchedTranscriptSegments: [],
            warnings: []
        )
        let draft = RecapDraft(
            rawTranscript: "raw",
            parseResult: parseResult,
            editableFields: parseResult.fields,
            storedRecordID: identifier
        )
        let viewModel = RecapEditorViewModel(
            draft: draft,
            generator: EmailDraftGenerator(),
            store: store
        )

        try viewModel.save(locale: Locale(identifier: "en"))

        XCTAssertEqual(store.savedIdentifiers, [identifier])
    }
}

@MainActor
private final class StubStoredDebriefStore: StoredDebriefStoreProtocol {
    private(set) var savedIdentifiers: [UUID?] = []

    func saveCaptureDraft(id: UUID?, accountName: String, visitAt: Date, transcript: String) throws -> UUID {
        _ = accountName
        _ = visitAt
        _ = transcript
        let resolved = id ?? UUID()
        savedIdentifiers.append(resolved)
        return resolved
    }

    func saveRecap(
        id: UUID?,
        fields: RecapFields,
        rawTranscript: String,
        emailDraft: EmailDraft,
        tone: EmailTone
    ) throws -> UUID {
        _ = fields
        _ = rawTranscript
        _ = emailDraft
        _ = tone
        savedIdentifiers.append(id)
        return id ?? UUID()
    }

    func delete(id _: UUID) throws {}
}
