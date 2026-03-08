import Foundation
import SalesDebriefCore
import XCTest

final class EmailDraftGeneratorTests: XCTestCase {
    func testGenerateNeutralDraftIncludesSummaryAndNextAction() {
        let generator = EmailDraftGenerator()
        let recap = RecapFields(
            accountName: "Acme Dental",
            visitAt: ISO8601DateFormatter().date(from: "2026-03-07T10:00:00Z"),
            contactName: "Dr. Rivera",
            visitObjective: "review scanner rollout",
            whatHappened: "You confirmed interest in a two-site rollout.",
            interestLevel: .hot,
            objectionsOrConcerns: "Training time for assistants",
            competitorMentions: "Medisoft",
            nextAction: "I will send pricing by Tuesday",
            followUpDueAt: ISO8601DateFormatter().date(from: "2026-03-10T00:00:00Z"),
            internalNote: nil
        )

        let draft = generator.generate(from: recap, tone: .neutralProfessional, locale: Locale(identifier: "en"))

        XCTAssertEqual(draft.subject, "Follow-up from today's visit with Acme Dental")
        XCTAssertTrue(draft.body.contains("Dr. Rivera"))
        XCTAssertTrue(draft.body.contains("two-site rollout"))
        XCTAssertTrue(draft.body.contains("I will send pricing by Tuesday"))
    }

    func testGenerateJapaneseDraftUsesJapaneseTemplate() {
        let generator = EmailDraftGenerator()
        let recap = RecapFields(
            accountName: "青山商事",
            visitAt: ISO8601DateFormatter().date(from: "2026-03-07T10:00:00Z"),
            contactName: "田中様",
            visitObjective: nil,
            whatHappened: "導入時期について前向きな反応をいただきました。",
            interestLevel: .warm,
            objectionsOrConcerns: nil,
            competitorMentions: nil,
            nextAction: "来週火曜日までに見積もりを送付します",
            followUpDueAt: nil,
            internalNote: nil
        )

        let draft = generator.generate(from: recap, tone: .warmConsultative, locale: Locale(identifier: "ja"))

        XCTAssertEqual(draft.subject, "本日のご訪問のお礼")
        XCTAssertTrue(draft.body.contains("田中様"))
        XCTAssertTrue(draft.body.contains("見積もりを送付します"))
    }

    func testGenerateDirectDraftOmitsMissingOptionalSections() {
        let generator = EmailDraftGenerator()
        let recap = RecapFields(
            accountName: "Northwind",
            visitAt: nil,
            contactName: nil,
            visitObjective: nil,
            whatHappened: "Thanks for the time today.",
            interestLevel: nil,
            objectionsOrConcerns: nil,
            competitorMentions: nil,
            nextAction: nil,
            followUpDueAt: nil,
            internalNote: nil
        )

        let draft = generator.generate(from: recap, tone: .directConcise, locale: Locale(identifier: "en"))

        XCTAssertFalse(draft.body.contains("Next step"))
        XCTAssertFalse(draft.body.contains("Concern"))
        XCTAssertTrue(draft.body.contains("Thanks for the time today."))
    }
}
