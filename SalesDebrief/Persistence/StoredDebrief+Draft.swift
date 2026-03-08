import Foundation
import SalesDebriefCore

extension StoredDebrief {
    func makeDraft() -> RecapDraft {
        let fields = RecapFields(
            accountName: accountName,
            visitAt: visitAt,
            contactName: emptyToNil(contactName),
            visitObjective: emptyToNil(visitObjective),
            whatHappened: whatHappened,
            interestLevel: nil,
            objectionsOrConcerns: emptyToNil(objectionsOrConcerns),
            competitorMentions: emptyToNil(competitorMentions),
            nextAction: emptyToNil(nextAction),
            followUpDueAt: followUpDueAt,
            internalNote: emptyToNil(internalNote)
        )

        return RecapDraft(
            rawTranscript: rawTranscript,
            parseResult: RecapParseResult(
                fields: fields,
                confidenceByField: [:],
                unmatchedTranscriptSegments: [],
                warnings: []
            ),
            editableFields: fields,
            storedRecordID: id
        )
    }

    var emailDraft: EmailDraft {
        EmailDraft(subject: emailSubject, body: emailBody)
    }

    var emailTone: EmailTone {
        EmailTone(rawValue: toneRawValue) ?? .neutralProfessional
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
