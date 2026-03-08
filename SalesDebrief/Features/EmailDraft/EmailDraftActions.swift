import Foundation
import SalesDebriefCore
import UIKit

@MainActor
struct EmailDraftActions {
    let copyText: (String) -> Void

    init(copyText: @escaping (String) -> Void = { UIPasteboard.general.string = $0 }) {
        self.copyText = copyText
    }

    func copySubject(from draft: EmailDraft) -> String {
        copyText(draft.subject)
        return String(localized: "email.copied_subject")
    }

    func copyBody(from draft: EmailDraft) -> String {
        copyText(draft.body)
        return String(localized: "email.copied_body")
    }

    func activityItems(for draft: EmailDraft) -> [Any] {
        [draft.subject, draft.body]
    }
}
