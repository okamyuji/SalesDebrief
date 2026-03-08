import OSLog
import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    let container: AppContainer
    @State private var showCapture = false

    var body: some View {
        container.makeHomeView()
            .sheet(isPresented: $showCapture) {
                NavigationStack {
                    CaptureFlowView(container: container)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(String(localized: "history.navigation")) {
                        HistoryView(container: container)
                    }
                    .accessibilityIdentifier("home.history")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "home.new")) {
                        showCapture = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("home.new")
                }
            }
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                AppLogger.lifecycle.notice("scene phase changed: \(newPhase.logDescription, privacy: .public)")
            }
    }
}

private struct CaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let container: AppContainer
    @State private var draft: RecapDraft?

    var body: some View {
        Group {
            if let draft {
                RecapEditorView(viewModel: container.makeRecapEditorViewModel(draft: draft))
            } else {
                CaptureView(viewModel: container.makeCaptureViewModel()) { nextDraft in
                    draft = nextDraft
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.close")) {
                    dismiss()
                }
            }
        }
    }
}

private extension ScenePhase {
    var logDescription: String {
        switch self {
        case .active:
            "active"
        case .inactive:
            "inactive"
        case .background:
            "background"
        @unknown default:
            "unknown"
        }
    }
}
