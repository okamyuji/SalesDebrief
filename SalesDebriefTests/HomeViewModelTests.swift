@testable import SalesDebrief
import XCTest

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testDefaultLocalizationUsesVisitNoteTerminology() {
        let viewModel = HomeViewModel()

        XCTAssertEqual(viewModel.title, String(localized: "home.title"))
        XCTAssertFalse(viewModel.title.localizedCaseInsensitiveContains("debrief"))
    }

    func testInitializerUsesProvidedStrings() {
        let viewModel = HomeViewModel(title: "Title", subtitle: "Subtitle")

        XCTAssertEqual(viewModel.title, "Title")
        XCTAssertEqual(viewModel.subtitle, "Subtitle")
    }
}
