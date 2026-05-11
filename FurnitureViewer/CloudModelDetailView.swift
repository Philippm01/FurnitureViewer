import SwiftUI

struct CloudModelDetailView: View {
    let model: FurnitureAPIModel

    @StateObject private var downloadTask: ModelDownloadTask
    @State private var previewImage: UIImage? = nil
    @State private var isLoadingPreview = true
    @State private var showARPreview = false

    private let controller = ModelController()
    private let baseURL = "http://35.236.77.209/models"

    init(model: FurnitureAPIModel) {
        self.model = model
        _downloadTask = StateObject(wrappedValue: ModelDownloadTask(modelId: model.id ?? ""))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                previewImageSection

                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.name)
                            .font(.title2.bold())
                        Text("By \(model.creatorName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    metadataSection

                    Divider()

                    downloadSection
                }
                .padding(20)
            }
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPreview() }
        .fullScreenCover(isPresented: $showARPreview) {
            if let url = downloadTask.downloadedURL {
                NavigationStack {
                    ModelPreviewView(usdzURL: url, previewImageURL: nil)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showARPreview = false }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var previewImageSection: some View {
        ZStack {
            Color(.secondarySystemBackground)

            if isLoadingPreview {
                ProgressView()
                    .frame(height: 280)
            } else if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)
                    Text("No preview available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 280)
            }
        }
        .frame(height: 280)
    }

    private var metadataSection: some View {
        VStack(spacing: 0) {
            metaRow(icon: "tag.fill",         label: "Category",    value: model.categories)
            if let size = model.size {
                metaRow(icon: "internaldrive", label: "File Size",   value: String(format: "%.1f MB", size))
            }
            if let created = model.createdAt {
                metaRow(icon: "calendar",      label: "Added",       value: formatDate(created))
            }
            if let updated = model.updatedAt {
                metaRow(icon: "clock.arrow.circlepath", label: "Updated", value: formatDate(updated))
            }
            if let id = model.id {
                metaRow(icon: "number",        label: "Model ID",    value: String(id.prefix(8)) + "…")
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var downloadSection: some View {
        VStack(spacing: 16) {

            if let error = downloadTask.error {
                
                HStack {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text("Download failed: \(error.localizedDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Retry") { startDownload() }
                    .buttonStyle(.borderedProminent)

            } else if downloadTask.isComplete {
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Downloaded")
                            .font(.headline)
                    }

                    Button {
                        showARPreview = true
                    } label: {
                        Label("View in Room", systemImage: "arkit")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

            } else if downloadTask.progress > 0 {
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Downloading…")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(downloadTask.progress * 100))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.blue)
                    }

                    ProgressView(value: downloadTask.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
                .padding(.horizontal, 4)

            } else {
                
                Button {
                    startDownload()
                } label: {
                    Label("Download Model", systemImage: "icloud.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("Downloads the 3D model for AR viewing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadPreview() async {
        guard let id = model.id else {
            isLoadingPreview = false
            return
        }
        if let data = try? await controller.downloadPreview(id: id),
           let img = UIImage(data: data) {
            await MainActor.run {
                previewImage = img
                isLoadingPreview = false
            }
        } else {
            await MainActor.run { isLoadingPreview = false }
        }
    }

    private func startDownload() {
        guard let id = model.id,
              let url = URL(string: "\(baseURL)/\(id)/download") else { return }
        downloadTask.start(downloadURL: url)
    }

    private func formatDate(_ raw: String) -> String {
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: raw) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return raw
    }
}
