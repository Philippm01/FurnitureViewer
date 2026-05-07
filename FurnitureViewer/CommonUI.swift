import SwiftUI

struct FancyModelRow: View {
    let title: String
    let image: UIImage?
    let systemIcon: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.blue.opacity(0.1))
                    Image(systemName: systemIcon)
                        .font(.title2)
                        .foregroundStyle(.blue.gradient)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
        .padding(.horizontal, 4)
    }
}

struct FancyCloudModelRow: View {
    let model: FurnitureAPIModel
    @State private var previewImage: UIImage? = nil
    private let controller = ModelController()
    
    var body: some View {
        FancyModelRow(
            title: model.name,
            image: previewImage,
            systemIcon: "icloud.and.arrow.down"
        )
        .task {
            await loadPreview()
        }
    }
    
    private func loadPreview() async {
        guard previewImage == nil, let id = model.id else { return }
        if let data = try? await controller.downloadPreview(id: id),
           let img = UIImage(data: data) {
            await MainActor.run { previewImage = img }
        }
    }
}
