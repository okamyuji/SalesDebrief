import AVFoundation
@testable import SalesDebrief
import XCTest

final class AudioRecordingServiceTests: XCTestCase {
    func testStartRecordingConfiguresAudioSessionForRecording() async throws {
        let session = StubAudioSession()
        let recorder = StubAudioRecorder()
        let service = AudioRecordingService(
            dependencies: AudioRecordingDependencies(
                makeSession: { session },
                makeRecorder: { _, _ in recorder }
            )
        )

        _ = try await service.startRecording()

        XCTAssertEqual(session.category, .playAndRecord)
        XCTAssertEqual(session.mode, .default)
        XCTAssertTrue(session.options.contains(.defaultToSpeaker))
        XCTAssertTrue(session.options.contains(.allowBluetoothHFP))
        XCTAssertEqual(session.setActiveCalls, [false, true])
        XCTAssertEqual(session.setActiveOptionsCalls, [[], [.notifyOthersOnDeactivation]])
        XCTAssertEqual(session.preferredSampleRate, 44100)
        XCTAssertEqual(session.preferredInputChannelCount, 1)
        XCTAssertTrue(session.prefersNoInterruptionsFromSystemAlerts)
        XCTAssertEqual(recorder.prepareToRecordCalls, 1)
        XCTAssertEqual(recorder.recordCalls, 1)
    }

    func testStopRecordingStopsRecorderAndDeactivatesSession() async throws {
        let session = StubAudioSession()
        let recorder = StubAudioRecorder()
        let service = AudioRecordingService(
            dependencies: AudioRecordingDependencies(
                makeSession: { session },
                makeRecorder: { _, _ in recorder }
            )
        )

        let startedURL = try await service.startRecording()
        let stoppedURL = try await service.stopRecording()

        XCTAssertEqual(startedURL, stoppedURL)
        XCTAssertEqual(recorder.stopCalls, 1)
        XCTAssertEqual(session.setActiveCalls, [false, true, false])
    }

    func testStartRecordingThrowsWhenRecorderCannotStart() async {
        let service = AudioRecordingService(
            dependencies: AudioRecordingDependencies(
                makeSession: { StubAudioSession() },
                makeRecorder: { _, _ in StubAudioRecorder(canPrepare: false, canRecord: false) }
            )
        )

        await XCTAssertThrowsErrorAsync(
            {
                try await service.startRecording()
            },
            { error in
                XCTAssertEqual(error as? RecordingError, .failedToStart)
            }
        )
    }

    func testInterruptionEndResumesRecorderWhenSystemRequestsResume() async throws {
        let session = StubAudioSession()
        let recorder = StubAudioRecorder()
        let service = AudioRecordingService(
            dependencies: AudioRecordingDependencies(
                makeSession: { session },
                makeRecorder: { _, _ in recorder }
            )
        )

        _ = try await service.startRecording()
        await service.handleAudioSessionInterruption(.began)
        recorder.simulateRecordingStoppedBySystem()
        await service.handleAudioSessionInterruption(.ended(shouldResume: true))

        XCTAssertEqual(recorder.pauseCalls, 1)
        XCTAssertEqual(recorder.recordCalls, 2)
        XCTAssertEqual(session.setActiveCalls, [false, true, false, true])
        XCTAssertEqual(
            session.setActiveOptionsCalls,
            [[], [.notifyOthersOnDeactivation], [], [.notifyOthersOnDeactivation]]
        )
        XCTAssertTrue(recorder.isRecording)
    }

    func testDidBecomeActiveResumesRecorderWhenRecordingWasInterruptedWithoutEndNotification() async throws {
        let session = StubAudioSession()
        let recorder = StubAudioRecorder()
        let service = AudioRecordingService(
            dependencies: AudioRecordingDependencies(
                makeSession: { session },
                makeRecorder: { _, _ in recorder }
            )
        )

        _ = try await service.startRecording()
        await service.handleAudioSessionInterruption(.began)
        recorder.simulateRecordingStoppedBySystem()
        await service.handleApplicationDidBecomeActive()

        XCTAssertEqual(recorder.pauseCalls, 1)
        XCTAssertEqual(recorder.recordCalls, 2)
        XCTAssertEqual(session.setActiveCalls, [false, true, false, true])
        XCTAssertEqual(
            session.setActiveOptionsCalls,
            [[], [.notifyOthersOnDeactivation], [], [.notifyOthersOnDeactivation]]
        )
        XCTAssertTrue(recorder.isRecording)
    }

    func testDidBecomeActiveDoesNotResumeAfterUserStoppedRecording() async throws {
        let session = StubAudioSession()
        let recorder = StubAudioRecorder()
        let service = AudioRecordingService(
            dependencies: AudioRecordingDependencies(
                makeSession: { session },
                makeRecorder: { _, _ in recorder }
            )
        )

        _ = try await service.startRecording()
        _ = try await service.stopRecording()
        await service.handleApplicationDidBecomeActive()

        XCTAssertEqual(recorder.recordCalls, 1)
        XCTAssertEqual(session.setActiveCalls, [false, true, false])
        XCTAssertFalse(recorder.isRecording)
    }
}

private final class StubAudioSession: AudioSessionProtocol, @unchecked Sendable {
    private(set) var category: AVAudioSession.Category?
    private(set) var mode: AVAudioSession.Mode?
    private(set) var options: AVAudioSession.CategoryOptions = []
    private(set) var setActiveCalls: [Bool] = []
    private(set) var setActiveOptionsCalls: [AVAudioSession.SetActiveOptions] = []
    private(set) var preferredSampleRate: Double?
    private(set) var preferredInputChannelCount: Int?
    private(set) var prefersNoInterruptionsFromSystemAlerts = false
    let maximumInputNumberOfChannels = 1

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        self.category = category
        self.mode = mode
        self.options = options
    }

    func setActive(_ active: Bool) throws {
        setActiveCalls.append(active)
        setActiveOptionsCalls.append([])
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        setActiveCalls.append(active)
        setActiveOptionsCalls.append(options)
    }

    func setPreferredSampleRate(_ sampleRate: Double) throws {
        preferredSampleRate = sampleRate
    }

    func setPreferredInputNumberOfChannels(_ channelCount: Int) throws {
        preferredInputChannelCount = channelCount
    }

    func setPrefersNoInterruptionsFromSystemAlerts(_ prefersNoInterruptions: Bool) throws {
        prefersNoInterruptionsFromSystemAlerts = prefersNoInterruptions
    }
}

private final class StubAudioRecorder: AudioRecorderProtocol, @unchecked Sendable {
    let canPrepare: Bool
    let canRecord: Bool
    private(set) var prepareToRecordCalls = 0
    private(set) var recordCalls = 0
    private(set) var pauseCalls = 0
    private(set) var stopCalls = 0
    private(set) var isRecording = false

    init(canPrepare: Bool = true, canRecord: Bool = true) {
        self.canPrepare = canPrepare
        self.canRecord = canRecord
    }

    func prepareToRecord() -> Bool {
        prepareToRecordCalls += 1
        return canPrepare
    }

    func record() -> Bool {
        recordCalls += 1
        isRecording = canRecord
        return canRecord
    }

    func stop() {
        stopCalls += 1
        isRecording = false
    }

    func pause() {
        pauseCalls += 1
        isRecording = false
    }

    func simulateRecordingStoppedBySystem() {
        isRecording = false
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> some Any,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown")
    } catch {
        errorHandler(error)
    }
}
