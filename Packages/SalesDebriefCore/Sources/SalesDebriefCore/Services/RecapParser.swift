import Foundation

public struct RecapParser: Sendable {
    public init() {}

    public func parse(transcript: String, visitAt: Date) -> RecapParseResult {
        let cleanedTranscript = clean(transcript: transcript)
        let extractions = makeExtractions(in: cleanedTranscript)
        let accountName = extractions.account?.value
        let contactName = extractions.contact?.value
        let visitObjective = extractions.objective?.value
        let whatHappened = extractions.happened?.value ?? cleanedTranscript
        let objections = extractions.concern?.value
        let competitor = extractions.competitor?.value
        let nextAction = extractions.action?.value
        let followUpText = extractions.followUp?.value
        let followUpDueAt = followUpText.flatMap { resolveDueDate(text: $0, relativeTo: visitAt) }
        let matchedRanges = ranges(from: extractions)
        let unmatched = unmatchedSegments(in: cleanedTranscript, excluding: matchedRanges)

        return RecapParseResult(
            fields: RecapFields(
                accountName: accountName,
                visitAt: visitAt,
                contactName: contactName,
                visitObjective: visitObjective,
                whatHappened: whatHappened,
                interestLevel: nil,
                objectionsOrConcerns: objections,
                competitorMentions: competitor,
                nextAction: nextAction,
                followUpDueAt: followUpDueAt,
                internalNote: nil
            ),
            confidenceByField: makeConfidenceByField(
                extractions: extractions,
                whatHappened: whatHappened,
                followUpDueAt: followUpDueAt
            ),
            unmatchedTranscriptSegments: unmatched,
            warnings: followUpText != nil && followUpDueAt == nil ? ["follow_up_unparsed"] : []
        )
    }

    private func clean(transcript: String) -> String {
        transcript
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeExtractions(in transcript: String) -> Extractions {
        Extractions(
            account: extract(after: "Visited ", in: transcript, markers: Marker.all),
            contact: extract(after: "Spoke with ", in: transcript, markers: Marker.all),
            objective: extract(after: "Goal was ", in: transcript, markers: Marker.all),
            happened: extract(after: "What happened was ", in: transcript, markers: Marker.all),
            concern: extract(after: "Main concern was ", in: transcript, markers: Marker.all),
            competitor: extract(after: "Competitor mentioned was ", in: transcript, markers: Marker.all),
            action: extract(after: "Next action is ", in: transcript, markers: Marker.all),
            followUp: extract(after: "Follow-up by ", in: transcript, markers: Marker.all)
        )
    }

    private func ranges(from extractions: Extractions) -> [Range<String.Index>] {
        [
            extractions.account?.range,
            extractions.contact?.range,
            extractions.objective?.range,
            extractions.happened?.range,
            extractions.concern?.range,
            extractions.competitor?.range,
            extractions.action?.range,
            extractions.followUp?.range,
        ].compactMap(\.self)
    }

    private func makeConfidenceByField(
        extractions: Extractions,
        whatHappened: String,
        followUpDueAt: Date?
    ) -> [RecapField: FieldConfidence] {
        var confidenceByField = Dictionary(
            uniqueKeysWithValues: RecapField.allCases.map { field in
                (field, FieldConfidence.missing)
            }
        )
        confidenceByField[.visitAt] = .extracted
        confidenceByField[.whatHappened] = whatHappened.isEmpty ? .missing : .extracted
        confidenceByField[.accountName] = fieldConfidence(for: extractions.account?.value)
        confidenceByField[.contactName] = fieldConfidence(for: extractions.contact?.value)
        confidenceByField[.visitObjective] = fieldConfidence(for: extractions.objective?.value)
        confidenceByField[.objectionsOrConcerns] = fieldConfidence(for: extractions.concern?.value)
        confidenceByField[.competitorMentions] = fieldConfidence(for: extractions.competitor?.value)
        confidenceByField[.nextAction] = fieldConfidence(for: extractions.action?.value)
        confidenceByField[.followUpDueAt] = followUpDueAt == nil ? .missing : .extracted
        confidenceByField[.interestLevel] = .missing
        confidenceByField[.internalNote] = .missing
        return confidenceByField
    }

    private func extract(after prefix: String, in transcript: String, markers: [String]) -> Extraction? {
        guard let prefixRange = transcript.range(of: prefix) else {
            return nil
        }

        let start = prefixRange.upperBound
        let nextMarkerStart = markers
            .filter { $0 != prefix }
            .compactMap { marker in
                transcript.range(of: marker, range: start ..< transcript.endIndex)?.lowerBound
            }
            .min() ?? transcript.endIndex
        let nextSentenceBoundary = transcript.range(of: ". ", range: start ..< transcript.endIndex)?.lowerBound ?? transcript.endIndex
        var end = min(nextMarkerStart, nextSentenceBoundary)
        var rawValue = transcript[start ..< end]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if prefix == "Spoke with ", isLikelyTitleOnly(rawValue), end < nextMarkerStart {
            let boundarySearchStart =
                transcript.index(end, offsetBy: 2, limitedBy: transcript.endIndex) ?? transcript.endIndex
            let secondBoundary = transcript.range(
                of: ". ",
                range: boundarySearchStart ..< transcript.endIndex
            )?.lowerBound ?? nextMarkerStart
            end = min(nextMarkerStart, secondBoundary)
            rawValue = transcript[start ..< end]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        }
        guard !rawValue.isEmpty else {
            return nil
        }

        let range = prefixRange.lowerBound ..< end
        return Extraction(value: String(rawValue), range: range)
    }

    private func fieldConfidence(for value: String?) -> FieldConfidence {
        guard let value, !value.isEmpty else {
            return .missing
        }

        return .extracted
    }

    private func resolveDueDate(text: String, relativeTo visitAt: Date) -> Date? {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        if let absoluteDate = ISO8601DateFormatter().date(from: "\(normalized)T00:00:00Z") {
            return absoluteDate
        }

        if normalized == "next tuesday" {
            return nextWeekday(3, after: visitAt, calendar: calendar)
        }

        return nil
    }

    private func nextWeekday(_ weekday: Int, after date: Date, calendar: Calendar) -> Date? {
        let currentWeekday = calendar.component(.weekday, from: date)
        var offset = weekday - currentWeekday
        if offset <= 0 {
            offset += 7
        }

        return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date))
    }

    private func unmatchedSegments(in transcript: String, excluding ranges: [Range<String.Index>]) -> [String] {
        guard !ranges.isEmpty else {
            return [transcript]
        }

        let sortedRanges = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var cursor = transcript.startIndex
        var segments: [String] = []

        for range in sortedRanges {
            if cursor < range.lowerBound {
                let segment = transcript[cursor ..< range.lowerBound]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                if !segment.isEmpty {
                    segments.append("\(segment).")
                }
            }
            cursor = max(cursor, range.upperBound)
        }

        if cursor < transcript.endIndex {
            let segment = transcript[cursor ..< transcript.endIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            if !segment.isEmpty {
                segments.append("\(segment).")
            }
        }

        return segments
    }

    private func isLikelyTitleOnly(_ value: String) -> Bool {
        ["Dr", "Mr", "Mrs", "Ms", "Prof"].contains(value)
    }
}

private struct Extraction {
    let value: String
    let range: Range<String.Index>
}

private struct Extractions {
    let account: Extraction?
    let contact: Extraction?
    let objective: Extraction?
    let happened: Extraction?
    let concern: Extraction?
    let competitor: Extraction?
    let action: Extraction?
    let followUp: Extraction?
}

private enum Marker {
    static let all = [
        "Visited ",
        "Spoke with ",
        "Goal was ",
        "What happened was ",
        "Main concern was ",
        "Competitor mentioned was ",
        "Next action is ",
        "Follow-up by ",
    ]
}
