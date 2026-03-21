import SwiftUI

struct HomeView: View {
    @StateObject private var storage = ScanStorage()
    @StateObject private var captureManager = CaptureManager()
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if storage.models.isEmpty {
                        ContentUnavailableView {
                            Label("No Furniture Scanned", systemImage: "sofa.fill")
                        } description: {
                            Text("Tap the button below to scan your first 3D model.")
                        }
                    } else {
                        List {
                            ForEach(storage.models) { model in
                                NavigationLink(destination: Text("Preview for \(model.id)")) {
                                    VStack(alignment: .leading) {
                                        Text(model.metadata.creator)
                                            .font(.headline)
                                        Text("Created \(model.metadata.dateOfCreation.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .onDelete(perform: deleteModels)
                        }
                    }
                }
                .navigationTitle("Furniture")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            captureManager.reset()
                            isScanning = true
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                    }
                }

                // Floating Action Button
                Button {
                    captureManager.reset()
                    isScanning = true
                } label: {
                    Label("New Scan", systemImage: "camera.viewfinder")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
            }
            .fullScreenCover(isPresented: $isScanning) {
                CaptureView(manager: captureManager)
            }
        }
    }

    private func deleteModels(at offsets: IndexSet) {
        for index in offsets {
            storage.delete(storage.models[index])
        }
    }
}
