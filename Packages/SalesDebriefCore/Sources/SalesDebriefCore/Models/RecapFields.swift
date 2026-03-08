import Foundation

public struct RecapFields: Equatable, Sendable {
    public var accountName: String?
    public var visitAt: Date?
    public var contactName: String?
    public var visitObjective: String?
    public var whatHappened: String
    public var interestLevel: InterestLevel?
    public var objectionsOrConcerns: String?
    public var competitorMentions: String?
    public var nextAction: String?
    public var followUpDueAt: Date?
    public var internalNote: String?

    public init(
        accountName: String?,
        visitAt: Date?,
        contactName: String?,
        visitObjective: String?,
        whatHappened: String,
        interestLevel: InterestLevel?,
        objectionsOrConcerns: String?,
        competitorMentions: String?,
        nextAction: String?,
        followUpDueAt: Date?,
        internalNote: String?
    ) {
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
    }
}
