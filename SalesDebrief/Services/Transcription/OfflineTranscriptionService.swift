@preconcurrency import AVFoundation
import Foundation
import OSLog
import Speech

protocol OfflineTranscriptionServiceProtocol: Sendable {
    func availability(for locale: Locale) async -> TranscriptionAvailability
    func transcribe(fileURL: URL, locale: Locale) async throws -> String
}

actor OfflineTranscriptionService: OfflineTranscriptionServiceProtocol {
    private let chunkLength: TimeInterval
    private let overlap: TimeInterval
    private let preprocessor: TranscriptionAudioPreprocessor

    init(
        chunkLength: TimeInterval = 15,
        overlap: TimeInterval = 1
    ) {
        self.chunkLength = chunkLength
        self.overlap = overlap
        preprocessor = TranscriptionAudioPreprocessor(
            chunkLength: chunkLength,
            overlap: overlap
        )
    }

    func availability(for locale: Locale) async -> TranscriptionAvailability {
        guard let recognizer = speechRecognizer(for: locale) else {
            return .manualOnly(reason: String(localized: "capture.manual_only_unsupported_locale"))
        }

        guard recognizer.supportsOnDeviceRecognition else {
            return .manualOnly(reason: String(localized: "capture.manual_only_offline_unavailable"))
        }

        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return .available
        case .notDetermined:
            return await requestAuthorization()
        case .denied, .restricted:
            return .manualOnly(reason: String(localized: "capture.manual_only_permission"))
        @unknown default:
            return .manualOnly(reason: String(localized: "capture.manual_only_unknown"))
        }
    }

    func transcribe(fileURL: URL, locale: Locale) async throws -> String {
        AppLogger.transcription.notice(
            "transcription requested file=\(fileURL.lastPathComponent, privacy: .public) locale=\(locale.identifier, privacy: .public)"
        )
        guard let recognizer = speechRecognizer(for: locale) else {
            AppLogger.transcription.error("transcription unavailable for locale=\(locale.identifier, privacy: .public)")
            throw OfflineTranscriptionError.unavailable
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sales-debrief-transcription-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let preparedFiles = try await preprocessor.prepareRecognitionFiles(
            for: fileURL,
            outputDirectory: temporaryDirectory
        )
        let duration = try await audioDuration(for: fileURL)
        let rangeSummary =
            "file=\(fileURL.lastPathComponent) duration=\(duration) preparedChunks=\(preparedFiles.count)"
        AppLogger.transcription.notice("transcription chunk plan \(rangeSummary, privacy: .public)")

        var transcripts: [String] = []
        for preparedFile in preparedFiles {
            let transcript = try await transcribeSegment(fileURL: preparedFile, recognizer: recognizer)
            let normalizedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedTranscript.isEmpty {
                transcripts.append(normalizedTranscript)
            }
        }

        let mergedTranscript = transcripts.joined(separator: "\n")
        let resultSummary =
            "file=\(fileURL.lastPathComponent) " +
            "characters=\(mergedTranscript.count)"
        AppLogger.transcription.notice(
            "transcription finished \(resultSummary, privacy: .public)"
        )
        return mergedTranscript
    }

    private func speechRecognizer(for locale: Locale) -> SFSpeechRecognizer? {
        for identifier in SpeechRecognizerLocaleResolver.candidateIdentifiers(for: locale) {
            let resolvedLocale = Locale(identifier: identifier)
            if let recognizer = SFSpeechRecognizer(locale: resolvedLocale), recognizer.supportsOnDeviceRecognition {
                return recognizer
            }
        }
        return nil
    }

    private func requestAuthorization() async -> TranscriptionAvailability {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: .available)
                case .denied, .restricted:
                    continuation.resume(returning: .manualOnly(reason: String(localized: "capture.manual_only_permission")))
                case .notDetermined:
                    continuation.resume(returning: .manualOnly(reason: String(localized: "capture.manual_only_unknown")))
                @unknown default:
                    continuation.resume(returning: .manualOnly(reason: String(localized: "capture.manual_only_unknown")))
                }
            }
        }
    }

    private func audioDuration(for fileURL: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    private func transcribeSegment(fileURL: URL, recognizer: SFSpeechRecognizer) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            let guarder = RecognitionContinuationGuard()
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    let errorSummary =
                        "file=\(fileURL.lastPathComponent) " +
                        "error=\(String(describing: error))"
                    AppLogger.transcription.error(
                        "transcription failed \(errorSummary, privacy: .public)"
                    )
                    guarder.resumeOnce { continuation.resume(throwing: error) }
                    return
                }

                guard let result else {
                    guarder.resumeOnce { continuation.resume(returning: "") }
                    return
                }

                if result.isFinal {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guarder.resumeOnce { continuation.resume(returning: text) }
                }
            }
        }
    }
}

enum OfflineTranscriptionError: Error {
    case unavailable
    case invalidAudioFormat
}

final class RecognitionContinuationGuard: @unchecked Sendable {
    private var resumed = false
    private let lock = NSLock()

    func resumeOnce(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        block()
    }
}

enum SpeechRecognizerLocaleResolver {
    static func candidateIdentifiers(for locale: Locale) -> [String] {
        let normalizedIdentifier = locale.identifier.replacingOccurrences(of: "-", with: "_")
        let languageIdentifier = locale.language.languageCode?.identifier

        var candidates: [String] = []
        if !normalizedIdentifier.isEmpty {
            candidates.append(normalizedIdentifier)
        }
        if let languageIdentifier, !languageIdentifier.isEmpty, !candidates.contains(languageIdentifier) {
            candidates.append(languageIdentifier)
        }
        if candidates.isEmpty {
            candidates.append("en")
        }
        return candidates
    }
}

enum TranscriptionChunkPlanner {
    static func chunkRanges(
        forDuration duration: TimeInterval,
        chunkLength: TimeInterval,
        overlap: TimeInterval
    ) -> [Range<TimeInterval>] {
        guard duration > 0 else {
            return []
        }

        guard duration > chunkLength else {
            return [0 ..< duration]
        }

        let safeChunkLength = max(chunkLength, 1)
        let safeOverlap = min(max(overlap, 0), safeChunkLength / 2)
        let stride = max(safeChunkLength - safeOverlap, 1)

        var ranges: [Range<TimeInterval>] = []
        var start: TimeInterval = 0

        while start < duration {
            let end = min(start + safeChunkLength, duration)
            ranges.append(start ..< end)
            if end >= duration {
                break
            }
            start += stride
        }

        return ranges
    }
}

struct TranscriptionAudioPreprocessor {
    let chunkLength: TimeInterval
    let overlap: TimeInterval

    func prepareRecognitionFiles(for sourceURL: URL, outputDirectory: URL) async throws -> [URL] {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let sourceFormat = sourceFile.processingFormat
        let duration = Double(sourceFile.length) / sourceFormat.sampleRate
        let ranges = TranscriptionChunkPlanner.chunkRanges(
            forDuration: duration,
            chunkLength: chunkLength,
            overlap: overlap
        )

        return try ranges.enumerated().map { index, range in
            let outputURL = outputDirectory
                .appendingPathComponent("chunk-\(index)")
                .appendingPathExtension("wav")
            try writeChunk(
                from: sourceURL,
                sourceFormat: sourceFormat,
                range: range,
                outputURL: outputURL
            )
            return outputURL
        }
    }

    private func writeChunk(
        from sourceURL: URL,
        sourceFormat: AVAudioFormat,
        range: Range<TimeInterval>,
        outputURL: URL
    ) throws {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let outputFormat = try makeOutputFormat(for: sourceFormat)
        guard let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
            throw OfflineTranscriptionError.invalidAudioFormat
        }
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: outputFormat.settings,
            commonFormat: outputFormat.commonFormat,
            interleaved: outputFormat.isInterleaved
        )

        let startFrame = AVAudioFramePosition(range.lowerBound * sourceFormat.sampleRate)
        let totalFrames = AVAudioFramePosition((range.upperBound - range.lowerBound) * sourceFormat.sampleRate)
        sourceFile.framePosition = startFrame

        var remainingFrames = totalFrames
        let chunkFrameCapacity = AVAudioFrameCount(min(4096, max(remainingFrames, 1)))

        while remainingFrames > 0 {
            let framesToRead = AVAudioFrameCount(min(remainingFrames, AVAudioFramePosition(chunkFrameCapacity)))
            guard let sourceBuffer = AVAudioPCMBuffer(
                pcmFormat: sourceFormat,
                frameCapacity: framesToRead
            ) else {
                throw OfflineTranscriptionError.invalidAudioFormat
            }

            try sourceFile.read(into: sourceBuffer, frameCount: framesToRead)
            guard sourceBuffer.frameLength > 0 else {
                break
            }

            let convertedBuffer = try convertBuffer(
                sourceBuffer,
                from: sourceFormat,
                to: outputFormat,
                using: converter
            )
            guard convertedBuffer.frameLength > 0 else {
                continue
            }

            try outputFile.write(from: convertedBuffer)
            remainingFrames -= AVAudioFramePosition(sourceBuffer.frameLength)
        }
    }

    private func makeOutputFormat(for sourceFormat: AVAudioFormat) throws -> AVAudioFormat {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sourceFormat.sampleRate,
            channels: sourceFormat.channelCount,
            interleaved: true
        ) else {
            throw OfflineTranscriptionError.invalidAudioFormat
        }
        return outputFormat
    }

    private func convertBuffer(
        _ sourceBuffer: AVAudioPCMBuffer,
        from sourceFormat: AVAudioFormat,
        to outputFormat: AVAudioFormat,
        using converter: AVAudioConverter
    ) throws -> AVAudioPCMBuffer {
        let convertedCapacity = AVAudioFrameCount(
            max(
                1,
                ceil(Double(sourceBuffer.frameLength) * outputFormat.sampleRate / sourceFormat.sampleRate)
            )
        )
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: convertedCapacity
        ) else {
            throw OfflineTranscriptionError.invalidAudioFormat
        }

        var conversionError: NSError?
        final class InputState: @unchecked Sendable {
            var suppliedInput = false
        }
        let inputState = InputState()
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if inputState.suppliedInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            inputState.suppliedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let conversionError {
            throw conversionError
        }
        guard status == .haveData || status == .endOfStream || status == .inputRanDry else {
            throw OfflineTranscriptionError.invalidAudioFormat
        }

        return convertedBuffer
    }
}
