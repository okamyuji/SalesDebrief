import XCTest

final class AppConfigurationTests: XCTestCase {
    func testInfoPlistEnablesBackgroundAudioMode() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SalesDebrief/Supporting/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let backgroundModes = try XCTUnwrap(plist["UIBackgroundModes"] as? [String])

        XCTAssertTrue(backgroundModes.contains("audio"))
    }
}
