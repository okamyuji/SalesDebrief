import SalesDebriefCore
import SwiftUI

struct RecapEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: RecapEditorViewModel
    @State private var showEmailPreview = false
    @State private var saveErrorMessage: String?

    var body: some View {
        Form {
            Section(String(localized: "recap.section_summary")) {
                TextField(String(localized: "capture.account_placeholder"), text: $viewModel.accountName)
                TextField(String(localized: "recap.contact"), text: $viewModel.contactName)
                DatePicker(
                    String(localized: "capture.visit_date"),
                    selection: $viewModel.visitAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section(String(localized: "recap.section_details")) {
                TextField(String(localized: "recap.objective"), text: $viewModel.visitObjective, axis: .vertical)
                TextField(String(localized: "recap.what_happened"), text: $viewModel.whatHappened, axis: .vertical)
                TextField(String(localized: "recap.concerns"), text: $viewModel.objectionsOrConcerns, axis: .vertical)
                TextField(String(localized: "recap.competitor"), text: $viewModel.competitorMentions, axis: .vertical)
                TextField(String(localized: "recap.next_action"), text: $viewModel.nextAction, axis: .vertical)
                DatePicker(
                    String(localized: "recap.follow_up"),
                    selection: followUpDateBinding,
                    displayedComponents: [.date]
                )
                Toggle(String(localized: "recap.follow_up_enabled"), isOn: Binding(
                    get: { viewModel.followUpDueAt != nil },
                    set: { enabled in
                        viewModel.followUpDueAt = enabled ? (viewModel.followUpDueAt ?? .now) : nil
                    }
                ))
                TextField(String(localized: "recap.internal_note"), text: $viewModel.internalNote, axis: .vertical)
            }

            Section(String(localized: "recap.section_email")) {
                Picker(String(localized: "recap.tone"), selection: $viewModel.selectedTone) {
                    Text(String(localized: "tone.neutral")).tag(EmailTone.neutralProfessional)
                    Text(String(localized: "tone.warm")).tag(EmailTone.warmConsultative)
                    Text(String(localized: "tone.direct")).tag(EmailTone.directConcise)
                }
                Button(String(localized: "recap.preview_email")) {
                    showEmailPreview = true
                }
                .accessibilityIdentifier("recap.preview_email")
            }

            Section(String(localized: "recap.section_transcript")) {
                Text(viewModel.rawTranscript)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(String(localized: "recap.navigation"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.save")) {
                    save()
                }
                .disabled(viewModel.whatHappened.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("recap.save")
            }
        }
        .sheet(isPresented: $showEmailPreview) {
            NavigationStack {
                EmailDraftView(
                    draft: viewModel.makeEmailDraft(locale: .autoupdatingCurrent),
                    tone: viewModel.selectedTone
                )
            }
        }
        .alert(String(localized: "capture.alert_title"), isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private func save() {
        do {
            try viewModel.save(locale: .autoupdatingCurrent)
            dismiss()
        } catch {
            saveErrorMessage = String(localized: "recap.error_save")
        }
    }

    private var followUpDateBinding: Binding<Date> {
        Binding<Date>(
            get: { viewModel.followUpDueAt ?? .now },
            set: { viewModel.followUpDueAt = $0 }
        )
    }
}
