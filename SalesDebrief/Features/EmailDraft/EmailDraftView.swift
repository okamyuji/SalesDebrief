import SalesDebriefCore
import SwiftUI
import UIKit

struct EmailDraftView: View {
    let draft: EmailDraft
    let tone: EmailTone
    @State private var actions = EmailDraftActions()
    @State private var showShareSheet = false
    @State private var feedbackMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabeledContent(String(localized: "email.subject"), value: draft.subject)
                Divider()
                Text(draft.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .navigationTitle(String(localized: "email.navigation"))
        .accessibilityIdentifier("email.screen")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(String(localized: "email.copy_subject")) {
                    feedbackMessage = actions.copySubject(from: draft)
                }
                .accessibilityIdentifier("email.copy_subject")

                Button(String(localized: "email.copy_body")) {
                    feedbackMessage = actions.copyBody(from: draft)
                }
                .accessibilityIdentifier("email.copy_body")

                Button(String(localized: "email.share")) {
                    showShareSheet = true
                }
                .accessibilityIdentifier("email.share")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: actions.activityItems(for: draft))
        }
        .alert(item: $feedbackMessage.asAlertItem) { item in
            Alert(title: Text(item.message))
        }
    }
}

private struct AlertMessage: Identifiable {
    let id = UUID()
    let message: String
}

private extension Binding where Value == String? {
    var asAlertItem: Binding<AlertMessage?> {
        Binding<AlertMessage?>(
            get: {
                wrappedValue.map { AlertMessage(message: $0) }
            },
            set: { wrappedValue = $0?.message }
        )
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
