import Foundation
import SalesDebriefCore
import XCTest

final class RecapParserTests: XCTestCase {
    func testParseExtractsGuidedPromptFields() throws {
        let parser = RecapParser()
        let transcript = """
        Visited Acme Dental. Spoke with Dr. Rivera. Goal was review implant scanner rollout.
        What happened was they liked the demo and want pricing for two locations.
        Main concern was training time for assistants.
        Competitor mentioned was Medisoft.
        Next action is send pricing by next Tuesday.
        Follow-up by 2026-03-10.
        """

        let result = try parser.parse(
            transcript: transcript,
            visitAt: XCTUnwrap(makeDate("2026-03-07T10:00:00Z"))
        )

        XCTAssertEqual(result.fields.accountName, "Acme Dental")
        XCTAssertEqual(result.fields.contactName, "Dr. Rivera")
        XCTAssertEqual(result.fields.visitObjective, "review implant scanner rollout")
        XCTAssertEqual(result.fields.whatHappened, "they liked the demo and want pricing for two locations")
        XCTAssertEqual(result.fields.objectionsOrConcerns, "training time for assistants")
        XCTAssertEqual(result.fields.competitorMentions, "Medisoft")
        XCTAssertEqual(result.fields.nextAction, "send pricing by next Tuesday")
        XCTAssertEqual(result.fields.followUpDueAt, Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 3,
            day: 10
        )))
        XCTAssertEqual(result.confidenceByField[.accountName], .extracted)
        XCTAssertTrue(result.unmatchedTranscriptSegments.isEmpty)
    }

    func testParseLeavesAmbiguousFieldsEmpty() throws {
        let parser = RecapParser()
        let transcript = "Good visit. They seemed interested. Need to think about next steps."

        let result = try parser.parse(
            transcript: transcript,
            visitAt: XCTUnwrap(makeDate("2026-03-07T10:00:00Z"))
        )

        XCTAssertNil(result.fields.accountName)
        XCTAssertNil(result.fields.contactName)
        XCTAssertEqual(result.fields.whatHappened, "Good visit. They seemed interested. Need to think about next steps.")
        XCTAssertEqual(result.confidenceByField[.accountName], .missing)
        XCTAssertEqual(result.confidenceByField[.nextAction], .missing)
        XCTAssertEqual(result.unmatchedTranscriptSegments, ["Good visit. They seemed interested. Need to think about next steps."])
    }

    func testParseResolvesRelativeDueDatePhrase() throws {
        let parser = RecapParser()
        let transcript = """
        Visited Northwind Supply. What happened was they want a follow-up.
        Next action is send the revised quote.
        Follow-up by next Tuesday.
        """

        let result = try parser.parse(
            transcript: transcript,
            visitAt: XCTUnwrap(makeDate("2026-03-07T10:00:00Z"))
        )

        XCTAssertEqual(result.fields.followUpDueAt, Calendar(identifier: .gregorian).date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 3,
            day: 10
        )))
    }

    func testParsePreservesUnmatchedTranscriptSegments() throws {
        let parser = RecapParser()
        let transcript = """
        Visited Harbor Fitness. Spoke with Mina.
        They asked whether implementation support is included.
        Goal was check expansion timeline.
        """

        let result = try parser.parse(
            transcript: transcript,
            visitAt: XCTUnwrap(makeDate("2026-03-07T10:00:00Z"))
        )

        XCTAssertEqual(result.fields.accountName, "Harbor Fitness")
        XCTAssertEqual(result.fields.contactName, "Mina")
        XCTAssertEqual(result.fields.visitObjective, "check expansion timeline")
        XCTAssertEqual(result.unmatchedTranscriptSegments, ["They asked whether implementation support is included."])
    }

    private func makeDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
