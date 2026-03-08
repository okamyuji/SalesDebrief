import Foundation

@Observable
final class HomeViewModel {
    let title: String
    let subtitle: String

    init(
        title: String = String(localized: "home.title"),
        subtitle: String = String(localized: "home.subtitle")
    ) {
        self.title = title
        self.subtitle = subtitle
    }
}
