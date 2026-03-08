import AVFoundation
import Foundation
import OSLog
import UIKit

protocol AudioRecordingServiceProtocol: Sendable {
    func startRecording() async throws -> URL
    func stopRecording() async throws -> URL
}

protocol AudioSessionProtocol: AnyObject {
    var maximumInputNumberOfChannels: Int { get }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func setActive(_ active: Bool) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
    func setPreferredSampleRate(_ sampleRate: Double) throws
    func setPreferredInputNumberOfChannels(_ channelCount: Int) throws
    func setPrefersNoInterruptionsFromSystemAlerts(_ prefersNoInterruptions: Bool) throws
}

protocol AudioRecorderProtocol: AnyObject {
    var isRecording: Bool { get }
    func prepareToRecord() -> Bool
    func record() -> Bool
    func pause()
    func stop()
}

struct AudioRecorderSettings {
    let formatID: UInt32
    let sampleRate: Double
    let channelCount: Int
    let quality: Int

    static let `default` = AudioRecorderSettings(
        formatID: kAudioFormatMPEG4AAC,
        sampleRate: 44100,
        channelCount: 1,
        quality: AVAudioQuality.high.rawValue
    )

    var dictionary: [String: Any] {
        [
            AVFormatIDKey: formatID,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVEncoderAudioQualityKey: quality,
        ]
    }
}

struct AudioSessionConfiguration {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions

    static let recording = AudioSessionConfiguration(
        category: .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetoothHFP]
    )
}

struct AudioRecordingDependencies {
    let makeSession: @Sendable () -> any AudioSessionProtocol
    let makeRecorder: @Sendable (URL, AudioRecorderSettings) throws -> any AudioRecorderProtocol

    static let live = AudioRecordingDependencies(
        makeSession: { AudioSessionAdapter() },
        makeRecorder: { url, settings in
            try AVAudioRecorder(url: url, settings: settings.dictionary)
        }
    )
}

actor AudioRecordingService: AudioRecordingServiceProtocol {
    private let dependencies: AudioRecordingDependencies
    private let sessionConfiguration: AudioSessionConfiguration
    private var recorder: (any AudioRecorderProtocol)?
    private var audioSession: (any AudioSessionProtocol)?
    private var recordingURL: URL?
    private var interruptionObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var intendsToRecord = false
    private var shouldResumeWhenPossible = false

    init(
        dependencies: AudioRecordingDependencies = .live,
        sessionConfiguration: AudioSessionConfiguration = .recording
    ) {
        self.dependencies = dependencies
        self.sessionConfiguration = sessionConfiguration
    }

    func startRecording() async throws -> URL {
        AppLogger.audio.notice("start recording requested")
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = directory.appendingPathComponent("sales-debrief-\(UUID().uuidString).m4a")
        let session = dependencies.makeSession()
        try configureRecordingSession(session, settings: .default)

        let recorder = try dependencies.makeRecorder(url, .default)
        guard recorder.prepareToRecord(), recorder.record() else {
            AppLogger.audio.error("failed to start recorder for file \(url.lastPathComponent, privacy: .public)")
            try? session.setActive(false)
            throw RecordingError.failedToStart
        }
        installObserversIfNeeded()
        self.recorder = recorder
        audioSession = session
        recordingURL = url
        intendsToRecord = true
        shouldResumeWhenPossible = false
        AppLogger.audio.notice("recording started file=\(url.lastPathComponent, privacy: .public)")
        return url
    }

    func stopRecording() async throws -> URL {
        let intendsToRecordValue = intendsToRecord
        let shouldResumeWhenPossibleValue = shouldResumeWhenPossible
        let stateSummary = Self.recordingStateSummary(
            intendsToRecord: intendsToRecordValue,
            shouldResumeWhenPossible: shouldResumeWhenPossibleValue
        )
        AppLogger.audio.notice("stop recording requested \(stateSummary, privacy: .public)")
        recorder?.stop()
        recorder = nil
        try audioSession?.setActive(false)
        audioSession = nil
        intendsToRecord = false
        shouldResumeWhenPossible = false
        guard let recordingURL else {
            AppLogger.audio.error("stop recording failed because recording URL is missing")
            throw RecordingError.missingRecording
        }
        AppLogger.audio.notice("recording stopped file=\(recordingURL.lastPathComponent, privacy: .public)")
        return recordingURL
    }

    func handleAudioSessionInterruption(_ interruption: AudioSessionInterruption) async {
        switch interruption {
        case .began:
            let recorderIsRecording = recorder?.isRecording ?? false
            let intendsToRecordValue = intendsToRecord
            let interruptionSummary = "recorderIsRecording=\(recorderIsRecording) intendsToRecord=\(intendsToRecordValue)"
            AppLogger.audio.notice("audio interruption began \(interruptionSummary, privacy: .public)")
            if recorderIsRecording {
                recorder?.pause()
                shouldResumeWhenPossible = intendsToRecord
            }
        case let .ended(shouldResume):
            let intendsToRecordValue = intendsToRecord
            let shouldResumeWhenPossibleValue = shouldResumeWhenPossible
            let interruptionSummary =
                "shouldResume=\(shouldResume) " +
                Self.recordingStateSummary(
                    intendsToRecord: intendsToRecordValue,
                    shouldResumeWhenPossible: shouldResumeWhenPossibleValue
                )
            AppLogger.audio.notice(
                "audio interruption ended \(interruptionSummary, privacy: .public)"
            )
            guard shouldResume else {
                shouldResumeWhenPossible = false
                return
            }
            await resumeRecordingIfNeeded()
        }
    }

    func handleApplicationDidBecomeActive() async {
        let recorderIsRecording = recorder?.isRecording ?? false
        let intendsToRecordValue = intendsToRecord
        let shouldResumeWhenPossibleValue = shouldResumeWhenPossible
        let activationSummary =
            "recorderIsRecording=\(recorderIsRecording) " +
            Self.recordingStateSummary(
                intendsToRecord: intendsToRecordValue,
                shouldResumeWhenPossible: shouldResumeWhenPossibleValue
            )
        AppLogger.audio.notice(
            "application became active \(activationSummary, privacy: .public)"
        )
        await resumeRecordingIfNeeded()
    }

    private func resumeRecordingIfNeeded() async {
        let recorderExists = recorder != nil
        let recorderIsRecording = recorder?.isRecording ?? false
        let intendsToRecordValue = intendsToRecord
        let shouldResumeWhenPossibleValue = shouldResumeWhenPossible
        let resumeSummary =
            "recorderExists=\(recorderExists) " +
            "recorderIsRecording=\(recorderIsRecording) " +
            Self.recordingStateSummary(
                intendsToRecord: intendsToRecordValue,
                shouldResumeWhenPossible: shouldResumeWhenPossibleValue
            )
        AppLogger.audio.notice(
            "resume evaluation \(resumeSummary, privacy: .public)"
        )
        guard intendsToRecord, shouldResumeWhenPossible, let recorder, let audioSession else {
            AppLogger.audio.notice("resume skipped because state is not resumable")
            return
        }
        guard !recorder.isRecording else {
            shouldResumeWhenPossible = false
            AppLogger.audio.notice("resume skipped because recorder is already recording")
            return
        }
        do {
            try configureRecordingSession(audioSession, settings: .default)
            guard recorder.record() else {
                AppLogger.audio.error("resume failed because recorder.record() returned false")
                return
            }
            shouldResumeWhenPossible = false
            AppLogger.audio.notice("resume succeeded")
        } catch {
            AppLogger.audio.error("resume failed with error: \(String(describing: error), privacy: .public)")
            return
        }
    }

    private func installObserversIfNeeded() {
        installInterruptionObserverIfNeeded()
        installDidBecomeActiveObserverIfNeeded()
    }

    private func configureRecordingSession(
        _ session: any AudioSessionProtocol,
        settings: AudioRecorderSettings
    ) throws {
        try? session.setActive(false)
        try session.setCategory(
            sessionConfiguration.category,
            mode: sessionConfiguration.mode,
            options: sessionConfiguration.options
        )
        try session.setPreferredSampleRate(min(settings.sampleRate, 48000))
        if #available(iOS 14.5, *) {
            try? session.setPrefersNoInterruptionsFromSystemAlerts(true)
        }
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let preferredInputChannelCount = min(settings.channelCount, session.maximumInputNumberOfChannels)
        if preferredInputChannelCount > 0 {
            try session.setPreferredInputNumberOfChannels(preferredInputChannelCount)
        }
    }

    private func installInterruptionObserverIfNeeded() {
        guard interruptionObserver == nil else {
            return
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let interruption = AudioSessionInterruption(notification: notification) else {
                return
            }
            Task {
                await self?.handleAudioSessionInterruption(interruption)
            }
        }
    }

    private func installDidBecomeActiveObserverIfNeeded() {
        guard appDidBecomeActiveObserver == nil else {
            return
        }

        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task {
                await self?.handleApplicationDidBecomeActive()
            }
        }
    }

    private static func recordingStateSummary(
        intendsToRecord: Bool,
        shouldResumeWhenPossible: Bool
    ) -> String {
        "intendsToRecord=\(intendsToRecord) shouldResumeWhenPossible=\(shouldResumeWhenPossible)"
    }
}

final class AudioSessionAdapter: AudioSessionProtocol, @unchecked Sendable {
    private let session = AVAudioSession.sharedInstance()

    var maximumInputNumberOfChannels: Int {
        session.maximumInputNumberOfChannels
    }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        try session.setCategory(category, mode: mode, options: options)
    }

    func setActive(_ active: Bool) throws {
        try session.setActive(active)
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        try session.setActive(active, options: options)
    }

    func setPreferredSampleRate(_ sampleRate: Double) throws {
        try session.setPreferredSampleRate(sampleRate)
    }

    func setPreferredInputNumberOfChannels(_ channelCount: Int) throws {
        try session.setPreferredInputNumberOfChannels(channelCount)
    }

    func setPrefersNoInterruptionsFromSystemAlerts(_ prefersNoInterruptions: Bool) throws {
        if #available(iOS 14.5, *) {
            try session.setPrefersNoInterruptionsFromSystemAlerts(prefersNoInterruptions)
        }
    }
}

extension AVAudioRecorder: AudioRecorderProtocol {}

enum RecordingError: Error, Equatable {
    case missingRecording
    case failedToStart
}

enum AudioSessionInterruption: Equatable {
    case began
    case ended(shouldResume: Bool)

    init?(notification: Notification) {
        guard
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return nil
        }

        switch type {
        case .began:
            self = .began
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            self = .ended(shouldResume: options.contains(.shouldResume))
        @unknown default:
            return nil
        }
    }
}
