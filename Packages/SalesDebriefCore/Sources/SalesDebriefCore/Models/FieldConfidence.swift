import Foundation

public enum FieldConfidence: Equatable, Sendable {
    case extracted
    case uncertain
    case missing
}
