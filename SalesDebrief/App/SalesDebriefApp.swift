import SwiftUI

@main
struct SalesDebriefApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RootView(container: container)
            }
            .modelContainer(container.modelContainer)
        }
    }
}
