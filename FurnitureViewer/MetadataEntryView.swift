import SwiftUI
import PhotosUI

struct MetadataEntryView: View {
    let usdzURL: URL
    let onSave: (UUID, String, String, String, Date, Data?) -> Void
    let onCancel: () -> Void

    @State private var modelID = UUID()
    @State private var modelName: String = ""
    @State private var categories: String = ""
    @State private var dateOfCreation: Date = .now

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var previewImageData: Data? = nil

    private var fileSizeString: String {
        let sizeInBytes = (try? FileManager.default.attributesOfItem(atPath: usdzURL.path)[.size] as? Int64) ?? 0
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Preview Image")) {
                    HStack {
                        Spacer()
                        if let previewImageData, let uiImage = UIImage(data: previewImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 150)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                )
                        }
                        Spacer()
                    }

                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text(previewImageData == nil ? "Select Preview Image" : "Change Preview Image")
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                previewImageData = data
                            }
                        }
                    }

                    if previewImageData != nil {
                        Button("Remove Image", role: .destructive) {
                            previewImageData = nil
                            selectedItem = nil
                        }
                    }
                }

                Section(header: Text("Model Details")) {
                    TextField("Model Name", text: $modelName)
                    TextField("Category (e.g. Furniture, Sofa)", text: $categories)
                    DatePicker("Date of Creation", selection: $dateOfCreation, displayedComponents: .date)
                }

                Section(header: Text("System Metadata")) {
                    LabeledContent("ID", value: modelID.uuidString.prefix(8).description + "...")
                        .contextMenu { Button("Copy ID") { UIPasteboard.general.string = modelID.uuidString } }
                    LabeledContent("Last Updated", value: Date.now.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Size", value: fileSizeString)
                    LabeledContent("Model Reference", value: "\(modelID.uuidString).usdz")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .navigationTitle("Save Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalCategories = categories.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            modelID,
                            finalName.isEmpty ? "Unnamed Model" : finalName,
                            "",
                            finalCategories.isEmpty ? "Uncategorized" : finalCategories,
                            dateOfCreation,
                            previewImageData
                        )
                    }
                }
            }
        }
    }
}
