import Foundation

public struct EmailDraftGenerator: Sendable {
    public init() {}

    public func generate(from recap: RecapFields, tone: EmailTone, locale: Locale) -> EmailDraft {
        if locale.identifier.hasPrefix("ja") {
            return generateJapaneseDraft(from: recap, tone: tone)
        }

        return generateEnglishDraft(from: recap, tone: tone)
    }

    private func generateEnglishDraft(from recap: RecapFields, tone: EmailTone) -> EmailDraft {
        let subject = switch tone {
        case .neutralProfessional:
            "Follow-up from today's visit with \(recap.accountName ?? "your team")"
        case .warmConsultative:
            "Thank you for meeting today"
        case .directConcise:
            "Quick follow-up"
        }

        var lines: [String] = []
        lines.append("Hi \(recap.contactName ?? "there"),")
        lines.append("")
        switch tone {
        case .neutralProfessional:
            lines.append("Thank you for taking the time to meet today.")
        case .warmConsultative:
            lines.append("Thank you again for the conversation today.")
        case .directConcise:
            lines.append("Thank you for your time today.")
        }
        lines.append(recap.whatHappened)

        if let nextAction = recap.nextAction, !nextAction.isEmpty {
            lines.append("")
            lines.append("Next step: \(nextAction)")
        }

        if let followUpDueAt = recap.followUpDueAt {
            lines.append("Timing: \(followUpDueAt.formatted(date: .abbreviated, time: .omitted))")
        }

        lines.append("")
        lines.append("Best regards,")

        return EmailDraft(subject: subject, body: lines.joined(separator: "\n"))
    }

    private func generateJapaneseDraft(from recap: RecapFields, tone: EmailTone) -> EmailDraft {
        let subject = switch tone {
        case .neutralProfessional, .warmConsultative:
            "本日のご訪問のお礼"
        case .directConcise:
            "ご訪問後のご連絡"
        }

        var lines: [String] = []
        lines.append("\(recap.contactName ?? "ご担当者様")")
        lines.append("")
        lines.append("本日はお時間をいただき、ありがとうございました。")
        lines.append(recap.whatHappened)

        if let nextAction = recap.nextAction, !nextAction.isEmpty {
            lines.append("")
            lines.append("次のアクション: \(nextAction)")
        }

        lines.append("")
        lines.append("よろしくお願いいたします。")

        return EmailDraft(subject: subject, body: lines.joined(separator: "\n"))
    }
}
