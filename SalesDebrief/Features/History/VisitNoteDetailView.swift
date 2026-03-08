import SwiftData
import SwiftUI

struct VisitNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let debrief: StoredDebrief
    let container: AppContainer

    @State private var showDeleteConfirmation = false
    @State private var showEditor = false

    var body: some View {
        Form {
            Section(String(localized: "recap.section_summary")) {
                LabeledContent(String(localized: "capture.account_placeholder"), value: debrief.accountName)
                if !debrief.contactName.isEmpty {
                    LabeledContent(String(localized: "recap.contact"), value: debrief.contactName)
                }
                LabeledContent(
                    String(localized: "capture.visit_date"),
                    value: debrief.visitAt.formatted(date: .abbreviated, time: .shortened)
                )
            }

            Section(String(localized: "recap.section_details")) {
                Text(debrief.whatHappened)
                if !debrief.nextAction.isEmpty {
                    LabeledContent(String(localized: "recap.next_action"), value: debrief.nextAction)
                }
                if !debrief.objectionsOrConcerns.isEmpty {
                    LabeledContent(String(localized: "recap.concerns"), value: debrief.objectionsOrConcerns)
                }
            }

            Section(String(localized: "email.navigation")) {
                NavigationLink(String(localized: "email.open")) {
                    EmailDraftView(draft: debrief.emailDraft, tone: debrief.emailTone)
                }
            }

            Section {
                Button(String(localized: "history.delete"), role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .accessibilityIdentifier("history.detail")
        .navigationTitle(debrief.accountName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "history.edit")) {
                    showEditor = true
                }
                .accessibilityIdentifier("history.edit")
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                RecapEditorView(viewModel: container.makeRecapEditorViewModel(record: debrief))
            }
        }
        .confirmationDialog(
            String(localized: "history.delete_confirm_title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "history.delete"), role: .destructive) {
                delete()
            }
            Button(String(localized: "common.close"), role: .cancel) {}
        } message: {
            Text(String(localized: "history.delete_confirm_message"))
        }
    }

    private func delete() {
        do {
            try container.deleteRecord(id: debrief.id)
            dismiss()
        } catch {
            showDeleteConfirmation = false
        }
    }
}
