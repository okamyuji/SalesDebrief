@testable import SalesDebrief
import XCTest

final class AppLoggerTests: XCTestCase {
    func testLoggerConfigurationUsesStableSubsystemAndCategories() {
        XCTAssertEqual(AppLogger.subsystem, "com.yujiokamoto.SalesDebrief")
        XCTAssertEqual(AppLogger.lifecycleCategory, "lifecycle")
        XCTAssertEqual(AppLogger.audioCategory, "audio")
        XCTAssertEqual(AppLogger.transcriptionCategory, "transcription")
    }
}
