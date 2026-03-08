import Foundation
import SalesDebriefCore
import SwiftData

@MainActor
protocol StoredDebriefStoreProtocol: AnyObject {
    func saveCaptureDraft(id: UUID?, accountName: String, visitAt: Date, transcript: String) throws -> UUID
    func saveRecap(
        id: UUID?,
        fields: RecapFields,
        rawTranscript: String,
        emailDraft: EmailDraft,
        tone: EmailTone
    ) throws -> UUID
    func delete(id: UUID) throws
}

@MainActor
final class StoredDebriefStore: StoredDebriefStoreProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func saveCaptureDraft(id: UUID?, accountName: String, visitAt: Date, transcript: String) throws -> UUID {
        let context = ModelContext(modelContainer)
        let resolvedIdentifier = id ?? UUID()
        let record = try fetchRecord(id: resolvedIdentifier, in: context) ?? StoredDebrief(
            id: resolvedIdentifier,
            accountName: normalizedAccountName(accountName),
            visitAt: visitAt,
            contactName: "",
            visitObjective: "",
            whatHappened: transcript,
            interestLevel: "",
            objectionsOrConcerns: "",
            competitorMentions: "",
            nextAction: "",
            followUpDueAt: nil,
            internalNote: "",
            rawTranscript: transcript,
            emailSubject: "",
            emailBody: "",
            toneRawValue: EmailTone.neutralProfessional.rawValue
        )

        if record.modelContext == nil {
            context.insert(record)
        }

        record.updatedAt = .now
        record.accountName = normalizedAccountName(accountName)
        record.visitAt = visitAt
        record.whatHappened = transcript
        record.rawTranscript = transcript

        try context.save()
        return resolvedIdentifier
    }

    func saveRecap(
        id: UUID?,
        fields: RecapFields,
        rawTranscript: String,
        emailDraft: EmailDraft,
        tone: EmailTone
    ) throws -> UUID {
        let context = ModelContext(modelContainer)
        let resolvedIdentifier = id ?? UUID()
        let record = try fetchRecord(id: resolvedIdentifier, in: context) ?? StoredDebrief(
            id: resolvedIdentifier,
            accountName: normalizedAccountName(fields.accountName),
            visitAt: fields.visitAt ?? .now,
            contactName: "",
            visitObjective: "",
            whatHappened: fields.whatHappened,
            interestLevel: "",
            objectionsOrConcerns: "",
            competitorMentions: "",
            nextAction: "",
            followUpDueAt: nil,
            internalNote: "",
            rawTranscript: rawTranscript,
            emailSubject: "",
            emailBody: "",
            toneRawValue: tone.rawValue
        )

        if record.modelContext == nil {
            context.insert(record)
        }

        record.updatedAt = .now
        record.accountName = normalizedAccountName(fields.accountName)
        record.visitAt = fields.visitAt ?? .now
        record.contactName = fields.contactName ?? ""
        record.visitObjective = fields.visitObjective ?? ""
        record.whatHappened = fields.whatHappened
        record.interestLevel = fields.interestLevel?.rawValue ?? ""
        record.objectionsOrConcerns = fields.objectionsOrConcerns ?? ""
        record.competitorMentions = fields.competitorMentions ?? ""
        record.nextAction = fields.nextAction ?? ""
        record.followUpDueAt = fields.followUpDueAt
        record.internalNote = fields.internalNote ?? ""
        record.rawTranscript = rawTranscript
        record.emailSubject = emailDraft.subject
        record.emailBody = emailDraft.body
        record.toneRawValue = tone.rawValue

        try context.save()
        return resolvedIdentifier
    }

    func delete(id: UUID) throws {
        let context = ModelContext(modelContainer)
        guard let record = try fetchRecord(id: id, in: context) else {
            return
        }
        context.delete(record)
        try context.save()
    }

    private func normalizedAccountName(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? String(localized: "history.unknown_account") : trimmed
    }

    private func fetchRecord(id: UUID, in context: ModelContext) throws -> StoredDebrief? {
        var descriptor = FetchDescriptor<StoredDebrief>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
