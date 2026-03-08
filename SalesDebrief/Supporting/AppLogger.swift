import OSLog

enum AppLogger {
    static let subsystem = "com.yujiokamoto.SalesDebrief"

    static let lifecycleCategory = "lifecycle"
    static let audioCategory = "audio"
    static let transcriptionCategory = "transcription"

    static let lifecycle = Logger(subsystem: subsystem, category: lifecycleCategory)
    static let audio = Logger(subsystem: subsystem, category: audioCategory)
    static let transcription = Logger(subsystem: subsystem, category: transcriptionCategory)
}
