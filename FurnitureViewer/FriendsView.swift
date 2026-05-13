import SwiftUI

struct FriendsView: View {
    @StateObject private var session = Session.shared
    @StateObject private var storage = ScanStorage()
    @State private var friends: [User] = []
    @State private var searchResults: [User] = []
    @State private var searchText = ""
    @State private var isLoading = false
    
    @State private var selectedFriendToSend: User?
    @State private var showSendModelSheet = false
    
    // Streaming/Calling States
    @State private var selectedFriendToStream: User?
    @State private var showStreamModelPicker = false
    @State private var incomingStreamId = ""
    @State private var showIncomingCallRing = false
    
    @State private var receivedModels: [FurnitureAPIModel] = []
    @State private var isStreaming = false
    @State private var streamSession: StreamSessionResponse?
    @State private var isHost = true
    @State private var streamingModel: FurnitureAPIModel?
    @State private var streamingLocalURL: URL?
    
    @StateObject private var rtcManager = WebRTCManager()

    private let friendsController = FriendsController()
    private let userController = UserController()
    private let modelController = ModelController()

    var body: some View {
        NavigationStack {
            List {
                if !receivedModels.isEmpty {
                    Section(header: Text("Received Models")) {
                        ForEach(receivedModels) { model in
                            NavigationLink(destination: UnifiedModelDetailView(source: .cloud(model))) {
                                HStack {
                                    Image(systemName: "cube.box.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(model.name)
                                            .font(.headline)
                                        Text("From \(model.creatorName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Search Users")) {
                    TextField("Search users by name", text: $searchText)
                        .onSubmit {
                            searchUsers()
                        }
                    
                    ForEach(searchResults, id: \.username) { user in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(user.firstName) \(user.lastName)")
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                addFriend(friendId: user.id ?? "")
                            } label: {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                
                Section(header: Text("My Friends")) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if friends.isEmpty {
                        Text("No friends yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(friends, id: \.username) { friend in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(friend.firstName) \(friend.lastName)")
                                        .font(.headline)
                                    Text("@\(friend.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                // Call / Stream Trigger Button
                                Button {
                                    selectedFriendToStream = friend
                                } label: {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                                .padding(.trailing, 4)

                                Button {
                                    selectedFriendToSend = friend
                                    showSendModelSheet = true
                                } label: {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                                .padding(.trailing, 8)
                            }
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    removeFriend(friendId: friend.id ?? "")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .onAppear {
                loadFriends()
            }
            .onChange(of: session.currentUser?.id) { newId in
                if let userId = newId, !userId.isEmpty {
                    rtcManager.start(userId: userId)
                }
            }
            .onChange(of: rtcManager.incomingCallStreamId) { newId in
                if let streamId = newId, !self.isStreaming {
                    self.incomingStreamId = streamId
                    self.showIncomingCallRing = true
                }
            }
            .sheet(isPresented: $showSendModelSheet) {
                if let friend = selectedFriendToSend {
                    SendModelView(friend: friend)
                }
            }
            .sheet(item: $selectedFriendToStream) { friend in
                StreamModelPickerView(friend: friend) { selectedModel, localURL in
                    startStreamHosting(model: selectedModel, localURL: localURL)
                }
            }
            .fullScreenCover(isPresented: $showIncomingCallRing) {
                IncomingCallView(streamId: incomingStreamId) {
                    // Accepted
                    showIncomingCallRing = false
                    rtcManager.respondToCall(accepted: true)
                    self.isHost = false
                    self.isStreaming = true
                } onDeny: {
                    // Denied
                    showIncomingCallRing = false
                    rtcManager.respondToCall(accepted: false)
                    rtcManager.incomingCallStreamId = nil
                }
            }
            .fullScreenCover(isPresented: $isStreaming) {
                LiveStreamView(rtcManager: rtcManager, isHost: isHost, model: streamingModel, localURL: streamingLocalURL)
            }
        }
    }
    
    private func loadFriends() {
        guard let userId = session.currentUser?.id, !userId.isEmpty else { return }
        rtcManager.start(userId: userId)
        isLoading = true
        Task {
            do {
                let fetchedFriends = try await friendsController.listFriends(userId: userId)
                let fetchedReceived = try await modelController.getReceivedModels(userId: userId)
                await MainActor.run {
                    self.friends = fetchedFriends
                    self.receivedModels = fetchedReceived
                    self.isLoading = false
                }
            } catch {
                print("Failed to load friends/received: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func startStreamHosting(model: FurnitureAPIModel, localURL: URL?) {
        guard let callerId = session.currentUser?.id, let receiverId = selectedFriendToStream?.id else { return }
        
        let streamId = UUID().uuidString
        rtcManager.callTarget(targetId: receiverId, streamId: streamId, modelId: model.id ?? "")
        
        self.selectedFriendToStream = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isHost = true
            self.streamingModel = model
            self.streamingLocalURL = localURL
            self.isStreaming = true
        }
    }
    
    private func searchUsers() {
        guard !searchText.isEmpty else { return }
        Task {
            do {
                let results = try await userController.search(name: searchText)
                await MainActor.run {
                    self.searchResults = results.filter { $0.id != session.currentUser?.id }
                }
            } catch {
                print("Failed to search users: \(error)")
            }
        }
    }
    
    private func addFriend(friendId: String) {
        guard let userId = session.currentUser?.id, !userId.isEmpty else { return }
        Task {
            do {
                try await friendsController.addFriend(userId: userId, friendId: friendId)
                loadFriends()
                await MainActor.run {
                    searchText = ""
                    searchResults = []
                }
            } catch {
                print("Failed to add friend: \(error)")
            }
        }
    }
    
    private func removeFriend(friendId: String) {
        guard let userId = session.currentUser?.id, !userId.isEmpty else { return }
        Task {
            do {
                try await friendsController.removeFriend(userId: userId, friendId: friendId)
                loadFriends()
            } catch {
                print("Failed to remove friend: \(error)")
            }
        }
    }
}

// MARK: - Premium Incoming Call Interface
struct IncomingCallView: View {
    let streamId: String
    let onAccept: () -> Void
    let onDeny: () -> Void
    @State private var isRinging = false
    
    var body: some View {
        ZStack {
            // Premium dark background
            LinearGradient(colors: [Color.black.opacity(0.85), Color.black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 140, height: 140)
                            .scaleEffect(isRinging ? 1.3 : 1.0)
                            .opacity(isRinging ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isRinging)
                        
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 110, height: 110)
                            .shadow(color: .blue.opacity(0.5), radius: 15)
                        
                        Image(systemName: "video.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    }
                    .onAppear { isRinging = true }
                    
                    Text("Incoming AR Stream...")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text("Stream ID: \(streamId)")
                        .font(.subheadline.monospaced())
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack(spacing: 60) {
                    // Deny
                    Button {
                        onDeny()
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 75, height: 75)
                                .overlay(
                                    Image(systemName: "phone.down.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                            Text("Deny")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Accept
                    Button {
                        onAccept()
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 75, height: 75)
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                            Text("Accept")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Stream Model Picker
// MARK: - Stream Model Picker
struct StreamModelPickerView: View {
    let friend: User
    let onSelectModel: (FurnitureAPIModel, URL?) -> Void
    @StateObject private var storage = ScanStorage()
    @Environment(\.dismiss) var dismiss
    
    private var localModels: [FurnitureModel] {
        storage.models
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if localModels.isEmpty {
                    ContentUnavailableView("No Local Scans", systemImage: "cube.transparent", description: Text("Scan some models first to stream them."))
                } else {
                    List(localModels) { local in
                        Button {
                            let apiModel = FurnitureAPIModel(
                                id: local.id.uuidString,
                                name: local.metadata.name,
                                creatorName: local.metadata.creator,
                                categories: "Local Scan",
                                size: Double(local.metadata.size) / 1_000_000
                            )
                            onSelectModel(apiModel, storage.modelURL(for: local))
                        } label: {
                            HStack {
                                Image(systemName: "cube.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(local.metadata.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Local Scan")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "video.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stream to \(friend.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Send Model View
struct SendModelView: View {
    let friend: User
    @State private var uploadedModels: [FurnitureAPIModel] = []
    @State private var previews: [String: UIImage] = [:]
    @State private var isLoading = true
    @State private var isSharing = false
    @Environment(\.dismiss) var dismiss
    
    private let modelController = ModelController()
    private let session = Session.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading uploaded models...")
                            .foregroundColor(.secondary)
                    }
                } else if uploadedModels.isEmpty {
                    ContentUnavailableView(
                        "No Uploaded Models",
                        systemImage: "cloud.slash",
                        description: Text("No uploaded models found in the cloud. Create or publish models first to share them.")
                    )
                } else {
                    List(uploadedModels) { model in
                        HStack(spacing: 16) {
                            // Inline Thumbnail
                            if let id = model.id, let uiImage = previews[id] {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.gradient)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "cube.fill")
                                            .foregroundColor(.white)
                                    )
                                    .onAppear {
                                        loadPreview(for: model)
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.name)
                                    .font(.headline)
                                Text(model.categories)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let size = model.size {
                                    Text(String(format: "%.1f MB", size))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                sendCloudModel(model)
                            } label: {
                                Text("Send")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isSharing)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Send to \(friend.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isSharing)
                }
            }
            .task {
                await loadUploadedModels()
            }
            .overlay {
                if isSharing {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Sending model...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color(UIColor.systemBackground).opacity(0.2))
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                    }
                }
            }
        }
    }

    private func loadUploadedModels() async {
        isLoading = true
        do {
            // Fetch first two pages of discover to ensure uploaded models are available
            async let page1 = try? modelController.discover(page: 1)
            async let page2 = try? modelController.discover(page: 2)
            
            let res1 = (await page1) ?? []
            let res2 = (await page2) ?? []
            
            // Combine and remove duplicates
            var seen = Set<String>()
            var combined: [FurnitureAPIModel] = []
            for m in (res1 + res2) {
                if let id = m.id, !seen.contains(id) {
                    seen.insert(id)
                    combined.append(m)
                }
            }
            
            await MainActor.run {
                self.uploadedModels = combined
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func loadPreview(for model: FurnitureAPIModel) {
        guard let id = model.id else { return }
        Task {
            if let data = try? await modelController.downloadPreview(id: id),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.previews[id] = uiImage
                }
            }
        }
    }

    private func sendCloudModel(_ model: FurnitureAPIModel) {
        guard let modelId = model.id, let receiverId = friend.id, let senderId = session.currentUser?.id else { return }
        
        isSharing = true
        let request = ShareRequest(senderId: senderId, receiverId: receiverId, modelId: modelId)
        
        Task {
            do {
                try await modelController.shareModel(request: request)
                await MainActor.run {
                    isSharing = false
                    dismiss()
                }
            } catch {
                print("Failed to share model: \(error)")
                await MainActor.run {
                    isSharing = false
                }
            }
        }
    }
}

// MARK: - Live Stream View
// MARK: - Live Stream View
struct LiveStreamView: View {
    @ObservedObject var rtcManager: WebRTCManager
    let isHost: Bool
    let model: FurnitureAPIModel?
    let localURL: URL?
    
    @StateObject private var downloadTask: ModelDownloadTask
    @Environment(\.dismiss) var dismiss

    init(rtcManager: WebRTCManager, isHost: Bool, model: FurnitureAPIModel?, localURL: URL? = nil) {
        self.rtcManager = rtcManager
        self.isHost = isHost
        self.model = model
        self.localURL = localURL
        _downloadTask = StateObject(wrappedValue: ModelDownloadTask(modelId: model?.id ?? ""))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isHost {
                if let url = localURL ?? downloadTask.downloadedURL {
                    // Send AR View Video to WebRTC
                    ARCaptureView(usdzURL: url) { pixelBuffer, timestamp in
                        rtcManager.webRTC.captureFrame(pixelBuffer, timestamp: timestamp)
                    }
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2.0)
                        Text("Downloading Model...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            } else {
                // Receiver Video View
                if let videoTrack = rtcManager.remoteVideoTrack {
                    RTCVideoViewRepresentable(videoTrack: videoTrack)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2.0)
                            .tint(.white)
                        Text("Waiting for sender's video...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            }
            
            // Overlay controls
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        rtcManager.endCall()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
                
                if !rtcManager.isConnected {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Text("Connecting Peer-to-Peer...")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    .padding(.bottom)
                }
            }
        }
        .onAppear {
            if isHost, localURL == nil, let model = model {
                if let id = model.id, let url = URL(string: "\(APIConfig.modelsURL)/\(id)/download") {
                    downloadTask.start(modelId: id, downloadURL: url)
                }
            }
        }
    }
}
