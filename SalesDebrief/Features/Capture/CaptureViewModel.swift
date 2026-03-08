import Foundation
import SalesDebriefCore

@MainActor
@Observable
final class CaptureViewModel {
    var accountName = ""
    var transcript = ""
    var visitAt = Date()
    var isRecording = false
    var availability: TranscriptionAvailability = .manualOnly(reason: "")
    var statusMessage = ""
    var alertMessage: String?

    private let parser: RecapParser
    private let audioService: AudioRecordingServiceProtocol
    private let transcriptionService: OfflineTranscriptionServiceProtocol
    private let store: StoredDebriefStoreProtocol
    private var storedRecordID: UUID?
    private let localeProvider: () -> Locale
    private let deleteAudioFile: @Sendable (URL) throws -> Void

    init(
        parser: RecapParser,
        audioService: AudioRecordingServiceProtocol,
        transcriptionService: OfflineTranscriptionServiceProtocol,
        store: StoredDebriefStoreProtocol,
        localeProvider: @escaping () -> Locale = { .autoupdatingCurrent },
        deleteAudioFile: @escaping @Sendable (URL) throws -> Void = { url in
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    ) {
        self.parser = parser
        self.audioService = audioService
        self.transcriptionService = transcriptionService
        self.store = store
        self.localeProvider = localeProvider
        self.deleteAudioFile = deleteAudioFile
    }

    func loadAvailability() async {
        availability = await transcriptionService.availability(for: localeProvider())
        if case let .manualOnly(reason) = availability {
            statusMessage = reason
        } else {
            statusMessage = String(localized: "capture.available")
        }
    }

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        do {
            _ = try await audioService.startRecording()
            isRecording = true
            statusMessage = String(localized: "capture.recording")
        } catch {
            alertMessage = String(localized: "capture.error_recording")
        }
    }

    private func stopRecording() async {
        do {
            let url = try await audioService.stopRecording()
            isRecording = false
            statusMessage = String(localized: "capture.transcribing")
            switch await transcriptionService.availability(for: localeProvider()) {
            case .available:
                transcript = try await transcriptionService.transcribe(fileURL: url, locale: localeProvider())
                storedRecordID = try store.saveCaptureDraft(
                    id: storedRecordID,
                    accountName: accountName,
                    visitAt: visitAt,
                    transcript: transcript
                )
                try? deleteAudioFile(url)
                statusMessage = String(localized: "capture.transcribed")
            case let .manualOnly(reason):
                storedRecordID = try store.saveCaptureDraft(
                    id: storedRecordID,
                    accountName: accountName,
                    visitAt: visitAt,
                    transcript: String(localized: "capture.saved_audio_placeholder")
                )
                statusMessage = reason
            }
        } catch {
            isRecording = false
            alertMessage = String(localized: "capture.error_transcription")
        }
    }

    func buildDraft() -> RecapDraft {
        let parseResult = parser.parse(transcript: transcript, visitAt: visitAt)
        var fields = parseResult.fields
        if !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.accountName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return RecapDraft(
            rawTranscript: transcript,
            parseResult: parseResult,
            editableFields: fields,
            storedRecordID: storedRecordID
        )
    }
}

struct RecapDraft {
    let rawTranscript: String
    let parseResult: RecapParseResult
    var editableFields: RecapFields
    let storedRecordID: UUID?
}
