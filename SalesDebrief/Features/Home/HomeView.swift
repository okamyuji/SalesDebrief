import SwiftData
import SwiftUI

struct HomeView: View {
    let viewModel: HomeViewModel
    let container: AppContainer
    @Query(sort: [SortDescriptor(\StoredDebrief.visitAt, order: .reverse)]) private var debriefs: [StoredDebrief]

    init(viewModel: HomeViewModel, container: AppContainer) {
        self.viewModel = viewModel
        self.container = container
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(viewModel.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Label(String(localized: "home.offline"), systemImage: "lock.shield")
                        .font(.headline)
                    Text(String(localized: "home.offline_detail"))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "home.recent"))
                        .font(.title3.bold())
                    if debriefs.isEmpty {
                        Text(String(localized: "home.empty"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(debriefs.prefix(3)) { debrief in
                            NavigationLink {
                                VisitNoteDetailView(debrief: debrief, container: container)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(debrief.accountName)
                                        .font(.headline)
                                    Text(debrief.whatHappened)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.recent.\(debrief.accountName)")
                            if debrief.id != debriefs.prefix(3).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .accessibilityIdentifier("home.screen")
        .navigationTitle(String(localized: "home.navigation"))
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(), container: .live())
    }
    .modelContainer(for: StoredDebrief.self, inMemory: true)
}
