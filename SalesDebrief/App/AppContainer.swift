import Foundation
import SalesDebriefCore
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    private let parser = RecapParser()
    private let emailGenerator = EmailDraftGenerator()
    private let audioService: AudioRecordingServiceProtocol
    private let transcriptionService: OfflineTranscriptionServiceProtocol
    private let store: StoredDebriefStoreProtocol

    init(
        modelContainer: ModelContainer,
        audioService: AudioRecordingServiceProtocol,
        transcriptionService: OfflineTranscriptionServiceProtocol
    ) {
        self.modelContainer = modelContainer
        self.audioService = audioService
        self.transcriptionService = transcriptionService
        store = StoredDebriefStore(modelContainer: modelContainer)
    }

    static func live() -> AppContainer {
        let schema = Schema([StoredDebrief.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let modelContainer = try? ModelContainer(for: schema, configurations: [configuration])
        return AppContainer(
            modelContainer: modelContainer ?? .preview,
            audioService: AudioRecordingService(),
            transcriptionService: OfflineTranscriptionService()
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel()
    }

    func makeHomeView() -> HomeView {
        HomeView(viewModel: makeHomeViewModel(), container: self)
    }

    func makeCaptureViewModel() -> CaptureViewModel {
        CaptureViewModel(
            parser: parser,
            audioService: audioService,
            transcriptionService: transcriptionService,
            store: store
        )
    }

    func makeRecapEditorViewModel(draft: RecapDraft) -> RecapEditorViewModel {
        RecapEditorViewModel(draft: draft, generator: emailGenerator, store: store)
    }

    func makeRecapEditorViewModel(record: StoredDebrief) -> RecapEditorViewModel {
        makeRecapEditorViewModel(draft: record.makeDraft())
    }

    func deleteRecord(id: UUID) throws {
        try store.delete(id: id)
    }
}

private extension ModelContainer {
    static var preview: ModelContainer {
        let schema = Schema([StoredDebrief.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            preconditionFailure("Failed to create in-memory preview container: \(error)")
        }
    }
}
