import Foundation

public struct RecapParseResult: Equatable, Sendable {
    public let fields: RecapFields
    public let confidenceByField: [RecapField: FieldConfidence]
    public let unmatchedTranscriptSegments: [String]
    public let warnings: [String]

    public init(
        fields: RecapFields,
        confidenceByField: [RecapField: FieldConfidence],
        unmatchedTranscriptSegments: [String],
        warnings: [String]
    ) {
        self.fields = fields
        self.confidenceByField = confidenceByField
        self.unmatchedTranscriptSegments = unmatchedTranscriptSegments
        self.warnings = warnings
    }
}
