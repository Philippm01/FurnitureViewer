import SwiftUI

struct MetadataEntryView: View {
    let usdzURL: URL
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var creatorName: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Model Details")) {
                    TextField("Creator Name", text: $creatorName)
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
                        let finalName = creatorName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(finalName.isEmpty ? "Unknown Creator" : finalName)
                    }
                }
            }
        }
    }
}
