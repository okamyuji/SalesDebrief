import Foundation

public enum EmailTone: String, Codable, CaseIterable, Equatable, Sendable {
    case neutralProfessional
    case warmConsultative
    case directConcise
}
