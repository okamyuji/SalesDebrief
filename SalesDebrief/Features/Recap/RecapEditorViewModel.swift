import Foundation
import SalesDebriefCore

@MainActor
@Observable
final class RecapEditorViewModel {
    var accountName: String
    var visitAt: Date
    var contactName: String
    var visitObjective: String
    var whatHappened: String
    var objectionsOrConcerns: String
    var competitorMentions: String
    var nextAction: String
    var followUpDueAt: Date?
    var internalNote: String
    var selectedTone: EmailTone
    let rawTranscript: String
    private(set) var storedRecordID: UUID?

    private let generator: EmailDraftGenerator
    private let store: StoredDebriefStoreProtocol

    init(draft: RecapDraft, generator: EmailDraftGenerator, store: StoredDebriefStoreProtocol) {
        let fields = draft.editableFields
        accountName = fields.accountName ?? ""
        visitAt = fields.visitAt ?? .now
        contactName = fields.contactName ?? ""
        visitObjective = fields.visitObjective ?? ""
        whatHappened = fields.whatHappened
        objectionsOrConcerns = fields.objectionsOrConcerns ?? ""
        competitorMentions = fields.competitorMentions ?? ""
        nextAction = fields.nextAction ?? ""
        followUpDueAt = fields.followUpDueAt
        internalNote = fields.internalNote ?? ""
        selectedTone = .neutralProfessional
        rawTranscript = draft.rawTranscript
        storedRecordID = draft.storedRecordID
        self.generator = generator
        self.store = store
    }

    func makeFields() -> RecapFields {
        RecapFields(
            accountName: optional(accountName),
            visitAt: visitAt,
            contactName: optional(contactName),
            visitObjective: optional(visitObjective),
            whatHappened: whatHappened.trimmingCharacters(in: .whitespacesAndNewlines),
            interestLevel: nil,
            objectionsOrConcerns: optional(objectionsOrConcerns),
            competitorMentions: optional(competitorMentions),
            nextAction: optional(nextAction),
            followUpDueAt: followUpDueAt,
            internalNote: optional(internalNote)
        )
    }

    func makeEmailDraft(locale: Locale) -> EmailDraft {
        generator.generate(from: makeFields(), tone: selectedTone, locale: locale)
    }

    @discardableResult
    func save(locale: Locale) throws -> UUID {
        let identifier = try store.saveRecap(
            id: storedRecordID,
            fields: makeFields(),
            rawTranscript: rawTranscript,
            emailDraft: makeEmailDraft(locale: locale),
            tone: selectedTone
        )
        storedRecordID = identifier
        return identifier
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
