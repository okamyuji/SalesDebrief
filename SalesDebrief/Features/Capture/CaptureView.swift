import SwiftUI

struct CaptureView: View {
    @State var viewModel: CaptureViewModel
    let onContinue: (RecapDraft) -> Void

    var body: some View {
        Form {
            Section(String(localized: "capture.section_account")) {
                TextField(String(localized: "capture.account_placeholder"), text: $viewModel.accountName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("capture.account")
                DatePicker(
                    String(localized: "capture.visit_date"),
                    selection: $viewModel.visitAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section(String(localized: "capture.section_audio")) {
                Label(viewModel.statusMessage, systemImage: "waveform")
                    .foregroundStyle(.secondary)
                Button(viewModel.isRecording ? String(localized: "capture.stop") : String(localized: "capture.record")) {
                    Task {
                        await viewModel.toggleRecording()
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("capture.record")
            }

            Section(String(localized: "capture.section_transcript")) {
                TextEditor(text: $viewModel.transcript)
                    .frame(minHeight: 180)
                    .accessibilityIdentifier("capture.transcript")
            }
        }
        .navigationTitle(String(localized: "capture.navigation"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "capture.continue")) {
                    onContinue(viewModel.buildDraft())
                }
                .disabled(viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("capture.continue")
            }
        }
        .task {
            await viewModel.loadAvailability()
        }
        .alert(String(localized: "capture.alert_title"), isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
}
