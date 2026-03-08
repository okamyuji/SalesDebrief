import Foundation

enum TranscriptionAvailability: Equatable {
    case available
    case manualOnly(reason: String)
}
