import SwiftUI

struct CitySearchView: View {
    @EnvironmentObject var store: WeatherStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [City] = []

    var body: some View {
        NavigationStack {
            List {
                if !results.isEmpty {
                    Section("搜索结果") {
                        ForEach(results) { city in
                            Button {
                                store.addCity(city)
                                dismiss()
                            } label: {
                                cityRow(city)
                            }
                        }
                    }
                }
                Section("我的城市") {
                    ForEach(store.cities) { city in
                        Button {
                            store.selectedID = city.id
                            dismiss()
                        } label: {
                            HStack {
                                cityRow(city)
                                Spacer()
                                if city.id == store.selectedID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.cities[$0] }.forEach { store.removeCity($0) }
                    }
                }
            }
            .navigationTitle("城市")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .searchable(text: $query, prompt: "搜索城市，如 太原、上海、Tokyo")
            .task(id: query) { await runSearch() }
        }
    }

    private func cityRow(_ city: City) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(city.name)
                .foregroundStyle(.primary)
            if !city.subtitle.isEmpty {
                Text(city.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        results = (try? await WeatherService.searchCities(q)) ?? []
    }
}
