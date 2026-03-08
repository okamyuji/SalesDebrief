import Foundation
import SwiftData

@Model
final class StoredDebrief {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var accountName: String
    var visitAt: Date
    var contactName: String
    var visitObjective: String
    var whatHappened: String
    var interestLevel: String
    var objectionsOrConcerns: String
    var competitorMentions: String
    var nextAction: String
    var followUpDueAt: Date?
    var internalNote: String
    var rawTranscript: String
    var emailSubject: String
    var emailBody: String
    var toneRawValue: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        accountName: String,
        visitAt: Date,
        contactName: String,
        visitObjective: String,
        whatHappened: String,
        interestLevel: String,
        objectionsOrConcerns: String,
        competitorMentions: String,
        nextAction: String,
        followUpDueAt: Date?,
        internalNote: String,
        rawTranscript: String,
        emailSubject: String,
        emailBody: String,
        toneRawValue: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.accountName = accountName
        self.visitAt = visitAt
        self.contactName = contactName
        self.visitObjective = visitObjective
        self.whatHappened = whatHappened
        self.interestLevel = interestLevel
        self.objectionsOrConcerns = objectionsOrConcerns
        self.competitorMentions = competitorMentions
        self.nextAction = nextAction
        self.followUpDueAt = followUpDueAt
        self.internalNote = internalNote
        self.rawTranscript = rawTranscript
        self.emailSubject = emailSubject
        self.emailBody = emailBody
        self.toneRawValue = toneRawValue
    }
}
