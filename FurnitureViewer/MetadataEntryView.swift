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
    @State private var showCamera = false
    @State private var pickedImage: UIImage? = nil
    @State private var showDiscardAlert = false

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
                                .shadow(radius: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 150)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 40))
                                            .foregroundColor(.secondary)
                                        Text("No preview image selected")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        Spacer()
                    }

                    HStack(spacing: 20) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("Gallery", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)

                    if previewImageData != nil {
                        Button("Remove Image", role: .destructive) {
                            previewImageData = nil
                            selectedItem = nil
                            pickedImage = nil
                        }
                        .frame(maxWidth: .infinity)
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
                    Button("Cancel") {
                        showDiscardAlert = true
                    }
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
                    .fontWeight(.bold)
                }
            }
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $pickedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .onChange(of: pickedImage) { _, newImage in
                if let newImage = newImage {
                    previewImageData = newImage.jpegData(compressionQuality: 0.8)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        previewImageData = data
                    }
                }
            }
            .alert("Discard Model?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    onCancel()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Are you sure you want to discard this 3D model? This action cannot be undone.")
            }
        }
    }
}
