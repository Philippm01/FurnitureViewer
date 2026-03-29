import SwiftUI

struct MetadataEntryView: View {
    let usdzURL: URL
    let onSave: (UUID, String, String, Date) -> Void
    let onCancel: () -> Void
    
    @State private var modelID = UUID()
    @State private var modelName: String = ""
    @State private var creatorName: String = ""
    @State private var dateOfCreation: Date = .now
    
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
                Section(header: Text("Editable Properties")) {
                    TextField("Model Name", text: $modelName)
                    TextField("Creator Name", text: $creatorName)
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
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalCreator = creatorName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            modelID,
                            finalName.isEmpty ? "Unnamed Model" : finalName,
                            finalCreator.isEmpty ? "Unknown" : finalCreator,
                            dateOfCreation
                        )
                    }
                }
            }
        }
    }
}
