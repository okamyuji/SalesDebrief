import Foundation
@testable import SalesDebrief
import SalesDebriefCore
import XCTest

@MainActor
final class CaptureViewModelTests: XCTestCase {
    func testLoadAvailabilitySetsAvailableStatus() async {
        let viewModel = makeViewModel(
            transcriptionService: StubTranscriptionService(
                availability: .available,
                transcript: ""
            )
        )

        await viewModel.loadAvailability()

        XCTAssertEqual(viewModel.availability, .available)
        XCTAssertEqual(viewModel.statusMessage, String(localized: "capture.available"))
    }

    func testLoadAvailabilitySetsManualReason() async {
        let viewModel = makeViewModel(
            transcriptionService: StubTranscriptionService(
                availability: .manualOnly(reason: "Manual only"),
                transcript: ""
            )
        )

        await viewModel.loadAvailability()

        XCTAssertEqual(viewModel.statusMessage, "Manual only")
    }

    func testToggleRecordingSuccessLoadsTranscript() async {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-view-model-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data())
        let audioService = StubAudioService(startURL: audioURL, stopURL: audioURL)
        let transcriptionService = StubTranscriptionService(
            availability: .available,
            transcript: "Transcribed text"
        )
        let viewModel = makeViewModel(
            audioService: audioService,
            transcriptionService: transcriptionService
        )

        await viewModel.toggleRecording()

        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(viewModel.statusMessage, String(localized: "capture.recording"))

        await viewModel.toggleRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.transcript, "Transcribed text")
        XCTAssertEqual(viewModel.statusMessage, String(localized: "capture.transcribed"))
        XCTAssertEqual(viewModel.buildDraft().storedRecordID, transcriptionService.savedIdentifier)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    func testToggleRecordingStartFailureSetsAlert() async {
        let viewModel = makeViewModel(
            audioService: StubAudioService(startError: StubError.failedToStart)
        )

        await viewModel.toggleRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.alertMessage, String(localized: "capture.error_recording"))
    }

    func testToggleRecordingStopFailureSetsAlert() async {
        let audioService = StubAudioService(
            startURL: URL(fileURLWithPath: "/tmp/debrief.m4a"),
            stopError: StubError.failedToStop
        )
        let viewModel = makeViewModel(audioService: audioService)

        await viewModel.toggleRecording()
        await viewModel.toggleRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.alertMessage, String(localized: "capture.error_transcription"))
    }

    func testToggleRecordingManualOnlyLeavesTranscriptUntouched() async {
        let audioService = StubAudioService(
            startURL: URL(fileURLWithPath: "/tmp/debrief.m4a"),
            stopURL: URL(fileURLWithPath: "/tmp/debrief.m4a")
        )
        let viewModel = makeViewModel(
            audioService: audioService,
            transcriptionService: StubTranscriptionService(
                availability: .manualOnly(reason: "Manual only"),
                transcript: "unused"
            )
        )

        await viewModel.toggleRecording()
        await viewModel.toggleRecording()

        XCTAssertEqual(viewModel.statusMessage, "Manual only")
        XCTAssertEqual(viewModel.transcript, "")
    }

    func testBuildDraftPrefersManualAccountName() {
        let viewModel = makeViewModel()
        viewModel.accountName = "  Override Name  "
        viewModel.transcript = "Visited Parsed Name. What happened was shared next steps."
        viewModel.visitAt = Date(timeIntervalSince1970: 123)

        let draft = viewModel.buildDraft()

        XCTAssertEqual(draft.rawTranscript, viewModel.transcript)
        XCTAssertEqual(draft.editableFields.accountName, "Override Name")
        XCTAssertEqual(draft.editableFields.whatHappened, "shared next steps")
    }

    func testToggleRecordingSavesPlaceholderWhenManualTranscriptIsUnavailable() async {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-view-model-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data())
        let audioService = StubAudioService(startURL: audioURL, stopURL: audioURL)
        let transcriptionService = StubTranscriptionService(
            availability: .manualOnly(reason: "Manual only"),
            transcript: ""
        )
        let viewModel = makeViewModel(
            audioService: audioService,
            transcriptionService: transcriptionService
        )

        await viewModel.toggleRecording()
        await viewModel.toggleRecording()

        XCTAssertEqual(viewModel.buildDraft().storedRecordID, transcriptionService.savedIdentifier)
        XCTAssertEqual(
            transcriptionService.savedTranscripts,
            [String(localized: "capture.saved_audio_placeholder")]
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
    }

    private func makeViewModel(
        audioService: StubAudioService = StubAudioService(),
        transcriptionService: StubTranscriptionService = StubTranscriptionService(
            availability: .available,
            transcript: ""
        )
    ) -> CaptureViewModel {
        CaptureViewModel(
            parser: RecapParser(),
            audioService: audioService,
            transcriptionService: transcriptionService,
            store: transcriptionService,
            localeProvider: { Locale(identifier: "en_US") }
        )
    }
}

private actor StubAudioService: AudioRecordingServiceProtocol {
    let startURL: URL?
    let stopURL: URL?
    let startError: Error?
    let stopError: Error?

    init(
        startURL: URL? = nil,
        stopURL: URL? = nil,
        startError: Error? = nil,
        stopError: Error? = nil
    ) {
        self.startURL = startURL
        self.stopURL = stopURL
        self.startError = startError
        self.stopError = stopError
    }

    func startRecording() async throws -> URL {
        if let startError {
            throw startError
        }
        return startURL ?? URL(fileURLWithPath: "/tmp/default-start.m4a")
    }

    func stopRecording() async throws -> URL {
        if let stopError {
            throw stopError
        }
        return stopURL ?? URL(fileURLWithPath: "/tmp/default-stop.m4a")
    }
}

@MainActor
private final class StubTranscriptionService: OfflineTranscriptionServiceProtocol, StoredDebriefStoreProtocol {
    let availability: TranscriptionAvailability
    let transcript: String
    private(set) var savedTranscripts: [String] = []
    private(set) var savedIdentifier = UUID()

    init(availability: TranscriptionAvailability, transcript: String) {
        self.availability = availability
        self.transcript = transcript
    }

    func availability(for _: Locale) async -> TranscriptionAvailability {
        availability
    }

    func transcribe(fileURL _: URL, locale _: Locale) async throws -> String {
        transcript
    }

    func saveCaptureDraft(id: UUID?, accountName: String, visitAt: Date, transcript: String) throws -> UUID {
        _ = accountName
        _ = visitAt
        if let id {
            savedIdentifier = id
        }
        savedTranscripts.append(transcript)
        return savedIdentifier
    }

    func saveRecap(
        id: UUID?,
        fields: RecapFields,
        rawTranscript: String,
        emailDraft: EmailDraft,
        tone: EmailTone
    ) throws -> UUID {
        _ = fields
        _ = rawTranscript
        _ = emailDraft
        _ = tone
        return id ?? savedIdentifier
    }

    func delete(id _: UUID) throws {}
}

private enum StubError: Error {
    case failedToStart
    case failedToStop
}
