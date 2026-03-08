import SwiftData
import SwiftUI

struct HistoryView: View {
    let container: AppContainer
    @Query(sort: [SortDescriptor(\StoredDebrief.visitAt, order: .reverse)]) private var debriefs: [StoredDebrief]
    @State private var searchText = ""

    var body: some View {
        List(filteredDebriefs) { debrief in
            NavigationLink {
                VisitNoteDetailView(debrief: debrief, container: container)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(debrief.accountName)
                        .font(.headline)
                    Text(debrief.whatHappened)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(debrief.visitAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("history.row.\(debrief.accountName)")
        }
        .accessibilityIdentifier("history.list")
        .accessibilityIdentifier("history.screen")
        .navigationTitle(String(localized: "history.navigation"))
        .searchable(text: $searchText, prompt: Text(String(localized: "history.search")))
    }

    private var filteredDebriefs: [StoredDebrief] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return debriefs
        }

        return debriefs.filter {
            $0.accountName.localizedCaseInsensitiveContains(trimmed)
                || $0.contactName.localizedCaseInsensitiveContains(trimmed)
                || $0.whatHappened.localizedCaseInsensitiveContains(trimmed)
                || $0.rawTranscript.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
