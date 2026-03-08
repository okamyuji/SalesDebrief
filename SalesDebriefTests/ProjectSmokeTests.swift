@testable import SalesDebrief
import XCTest

@MainActor
final class ProjectSmokeTests: XCTestCase {
    func testAppContainerCreatesHomeViewModel() {
        let container = AppContainer.live()

        let viewModel = container.makeHomeViewModel()

        XCTAssertFalse(viewModel.title.isEmpty)
        XCTAssertFalse(viewModel.subtitle.isEmpty)
    }
}
