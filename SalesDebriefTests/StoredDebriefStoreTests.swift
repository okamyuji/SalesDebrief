@testable import SalesDebrief
import SalesDebriefCore
import SwiftData
import XCTest

@MainActor
final class StoredDebriefStoreTests: XCTestCase {
    func testSaveCaptureDraftCreatesRecord() throws {
        let modelContainer = try makeContainer()
        let store = StoredDebriefStore(modelContainer: modelContainer)

        let identifier = try store.saveCaptureDraft(
            id: nil,
            accountName: "",
            visitAt: Date(timeIntervalSince1970: 100),
            transcript: "Customer asked for pricing."
        )

        let records = try fetchRecords(from: modelContainer)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, identifier)
        XCTAssertEqual(records[0].accountName, String(localized: "history.unknown_account"))
        XCTAssertEqual(records[0].whatHappened, "Customer asked for pricing.")
        XCTAssertEqual(records[0].rawTranscript, "Customer asked for pricing.")
    }

    func testSaveRecapUpdatesExistingRecordInsteadOfDuplicating() throws {
        let modelContainer = try makeContainer()
        let store = StoredDebriefStore(modelContainer: modelContainer)
        let identifier = try store.saveCaptureDraft(
            id: nil,
            accountName: "Acme",
            visitAt: Date(timeIntervalSince1970: 100),
            transcript: "Initial note"
        )

        let fields = RecapFields(
            accountName: "Acme Dental",
            visitAt: Date(timeIntervalSince1970: 200),
            contactName: "Dr. Rivera",
            visitObjective: "Review scanner rollout",
            whatHappened: "Requested pricing for two sites.",
            interestLevel: nil,
            objectionsOrConcerns: "Training time",
            competitorMentions: "Medisoft",
            nextAction: "Send quote",
            followUpDueAt: nil,
            internalNote: "Priority account"
        )

        _ = try store.saveRecap(
            id: identifier,
            fields: fields,
            rawTranscript: "Transcript",
            emailDraft: EmailDraft(subject: "Subject", body: "Body"),
            tone: .warmConsultative
        )

        let records = try fetchRecords(from: modelContainer)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, identifier)
        XCTAssertEqual(records[0].accountName, "Acme Dental")
        XCTAssertEqual(records[0].contactName, "Dr. Rivera")
        XCTAssertEqual(records[0].emailSubject, "Subject")
        XCTAssertEqual(records[0].toneRawValue, EmailTone.warmConsultative.rawValue)
    }

    func testDeleteRemovesExistingRecord() throws {
        let modelContainer = try makeContainer()
        let store = StoredDebriefStore(modelContainer: modelContainer)
        let identifier = try store.saveCaptureDraft(
            id: nil,
            accountName: "Acme",
            visitAt: Date(timeIntervalSince1970: 100),
            transcript: "Initial note"
        )

        try store.delete(id: identifier)

        XCTAssertTrue(try fetchRecords(from: modelContainer).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([StoredDebrief.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func fetchRecords(from container: ModelContainer) throws -> [StoredDebrief] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<StoredDebrief>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor)
    }
}
