import AVFoundation
@testable import SalesDebrief
import XCTest

final class OfflineTranscriptionServiceTests: XCTestCase {
    func testRecognitionContinuationGuardResumesOnlyOnce() {
        let guarder = RecognitionContinuationGuard()
        var resumeCount = 0

        guarder.resumeOnce { resumeCount += 1 }
        guarder.resumeOnce { resumeCount += 1 }

        XCTAssertEqual(resumeCount, 1)
    }

    func testPreprocessorCreatesSingleWAVChunkForShortAudio() async throws {
        let sourceURL = try makeSilentRecording(duration: 3)
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("offline-transcription-tests-\(UUID().uuidString)", isDirectory: true)
        let preprocessor = TranscriptionAudioPreprocessor(chunkLength: 15, overlap: 1)

        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let preparedFiles = try await preprocessor.prepareRecognitionFiles(
            for: sourceURL,
            outputDirectory: outputDirectory
        )

        XCTAssertEqual(preparedFiles.count, 1)
        XCTAssertEqual(preparedFiles[0].pathExtension, "wav")
    }

    func testPreprocessorSplitsLongAudioIntoMultipleWAVChunks() async throws {
        let sourceURL = try makeSilentRecording(duration: 32)
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("offline-transcription-tests-\(UUID().uuidString)", isDirectory: true)
        let preprocessor = TranscriptionAudioPreprocessor(chunkLength: 15, overlap: 1)

        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        let preparedFiles = try await preprocessor.prepareRecognitionFiles(
            for: sourceURL,
            outputDirectory: outputDirectory
        )

        XCTAssertEqual(preparedFiles.count, 3)
        XCTAssertTrue(preparedFiles.allSatisfy { $0.pathExtension == "wav" })
    }

    func testChunkRangesReturnSingleRangeForShortAudio() {
        let ranges = TranscriptionChunkPlanner.chunkRanges(forDuration: 12, chunkLength: 15, overlap: 1)

        XCTAssertEqual(ranges, [0 ..< 12])
    }

    func testChunkRangesSplitLongAudioWithOverlap() {
        let ranges = TranscriptionChunkPlanner.chunkRanges(forDuration: 48.4, chunkLength: 15, overlap: 1)

        XCTAssertEqual(ranges.count, 4)
        XCTAssertEqual(ranges[0], 0 ..< 15)
        XCTAssertEqual(ranges[1], 14 ..< 29)
        XCTAssertEqual(ranges[2], 28 ..< 43)
        XCTAssertEqual(ranges[3], 42 ..< 48.4)
    }

    func testRecognizerLocaleCandidatesPreferFullLocaleBeforeLanguageFallback() {
        let candidates = SpeechRecognizerLocaleResolver.candidateIdentifiers(for: Locale(identifier: "ja_JP"))

        XCTAssertEqual(candidates, ["ja_JP", "ja"])
    }

    func testRecognizerLocaleCandidatesNormalizeHyphenatedLocale() {
        let candidates = SpeechRecognizerLocaleResolver.candidateIdentifiers(for: Locale(identifier: "en-US"))

        XCTAssertEqual(candidates, ["en_US", "en"])
    }

    private func makeSilentRecording(duration: TimeInterval) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("offline-transcription-\(UUID().uuidString)")
            .appendingPathExtension("caf")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        try file.write(from: buffer)
        return url
    }
}
