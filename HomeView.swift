import SwiftUI

struct HomeView: View {
    @StateObject private var storage = ScanStorage()
    @State private var isScanning = false
    var body: some View {
        NavigationStack {
            List(storage.models) { model in
                Text("\(model.metadata.creator) – \(model.metadata.dateOfCreation.formatted())")
            }
            .navigationTitle("Furniture")
            .toolbar {
                Button("Add Model") { isScanning = true }
            }
            .sheet(isPresented: $isScanning) {
                CaptureView()
            }
        }
    }
}
