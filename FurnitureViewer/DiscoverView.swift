import SwiftUI

struct DiscoverView: View {
    @State private var models: [FurnitureAPIModel] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    private let controller = ModelController()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && models.isEmpty {
                    ProgressView("Fetching models…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if models.isEmpty {
                    ContentUnavailableView {
                        Label("No Models Found", systemImage: "icloud.slash")
                    } description: {
                        Text("The cloud library is empty. Pull down to refresh.")
                    }
                } else {
                    List {
                        ForEach(models) { model in
                            ZStack {
                                FancyCloudModelRow(model: model)
                                    .onAppear {
                                        if model.id == models.last?.id && hasMorePages && !isLoading {
                                            loadNextPage()
                                        }
                                    }
                                
                                NavigationLink(destination: UnifiedModelDetailView(source: .cloud(model))) {
                                    EmptyView()
                                }
                                .opacity(0)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        
                        if isLoading && !models.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshModels()
                    }
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await refreshModels() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if models.isEmpty {
                    Task { await refreshModels() }
                }
            }
        }
    }

    private func refreshModels() async {
        isLoading = true
        currentPage = 1
        hasMorePages = true
        do {
            let result = try await controller.discover(page: 1)
            await MainActor.run {
                self.models = result
                self.hasMorePages = result.count == 5
                self.isLoading = false
            }
        } catch {
            print("DiscoverView refresh error: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }

    private func loadNextPage() {
        guard !isLoading && hasMorePages else { return }
        isLoading = true
        currentPage += 1
        Task {
            do {
                let result = try await controller.discover(page: currentPage)
                await MainActor.run {
                    self.models.append(contentsOf: result)
                    self.hasMorePages = result.count == 5
                    self.isLoading = false
                }
            } catch {
                print("DiscoverView page \(currentPage) error: \(error)")
                await MainActor.run {
                    self.currentPage -= 1   
                    self.isLoading = false
                }
            }
        }
    }
}

