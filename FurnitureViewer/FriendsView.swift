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
    @State private var streamingModelName = ""
    @State private var pollTimer: Timer?

    private let friendsController = FriendsController()
    private let userController = UserController()
    private let modelController = ModelController()
    private let streamController = StreamController()

    var body: some View {
        List {
            Section(header: Text("Answer AR Stream Call")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter the Stream ID shared by your caller:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Stream ID", text: $incomingStreamId)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button("Simulate Ring") {
                            guard !incomingStreamId.isEmpty else { return }
                            withAnimation(.spring()) {
                                showIncomingCallRing = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(incomingStreamId.isEmpty)
                    }
                }
                .padding(.vertical, 4)
            }
            
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
                                showStreamModelPicker = true
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
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
        .sheet(isPresented: $showSendModelSheet) {
            if let friend = selectedFriendToSend {
                SendModelView(friend: friend)
            }
        }
        .sheet(isPresented: $showStreamModelPicker) {
            if let friend = selectedFriendToStream {
                StreamModelPickerView(friend: friend) { selectedModelName in
                    startStreamHosting(modelName: selectedModelName)
                }
            }
        }
        .fullScreenCover(isPresented: $showIncomingCallRing) {
            IncomingCallView(streamId: incomingStreamId) {
                // Accepted
                showIncomingCallRing = false
                acceptIncomingStream(streamId: incomingStreamId)
            } onDeny: {
                // Denied
                showIncomingCallRing = false
            }
        }
        .fullScreenCover(isPresented: $isStreaming) {
            if let session = streamSession {
                LiveStreamView(session: session, isHost: isHost, modelName: streamingModelName)
            }
        }
    }
    
    private func loadFriends() {
        guard let userId = session.currentUser?.id, !userId.isEmpty else { return }
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

    private func startStreamHosting(modelName: String) {
        guard let callerId = session.currentUser?.id, let receiverId = selectedFriendToStream?.id else { return }
        Task {
            do {
                let sessionRes = try await streamController.createSession()
                // Initiate call with backend signaling
                _ = try await streamController.initiateCall(callerId: callerId, receiverId: receiverId)
                await MainActor.run {
                    self.streamSession = sessionRes
                    self.isHost = true
                    self.streamingModelName = modelName
                    self.isStreaming = true
                }
            } catch {
                print("Failed to start stream: \(error)")
            }
        }
    }
    
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            pollIncomingCalls()
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollIncomingCalls() {
        guard let userId = session.currentUser?.id, !userId.isEmpty else { return }
        Task {
            do {
                let calls = try await streamController.checkIncomingCalls(userId: userId)
                if let call = calls.first, let streamId = call.streamId {
                    await MainActor.run {
                        if !self.showIncomingCallRing && !self.isStreaming {
                            self.incomingStreamId = streamId
                            withAnimation(.spring()) {
                                self.showIncomingCallRing = true
                            }
                        }
                    }
                }
            } catch {
                // Ignore silent polling errors
            }
        }
    }
    
    private func acceptIncomingStream(streamId: String) {
        let baseWs = APIConfig.streamHost.replacingOccurrences(of: "http://", with: "ws://")
        let viewerWs = "\(baseWs)/ws/\(streamId)/viewer"
        let hostWs = "\(baseWs)/ws/\(streamId)/host"
        let sessionRes = StreamSessionResponse(streamId: streamId, hostWs: hostWs, viewerWs: viewerWs)
        
        self.streamSession = sessionRes
        self.isHost = false
        self.streamingModelName = "Shared AR View"
        self.isStreaming = true
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
struct StreamModelPickerView: View {
    let friend: User
    let onSelectModel: (String) -> Void
    @State private var models: [FurnitureAPIModel] = []
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    private let controller = ModelController()
    
    var body: some View {
        NavigationStack {
            List(models) { model in
                Button {
                    onSelectModel(model.name)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(model.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(model.categories)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "video.fill")
                            .foregroundColor(.red)
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
            .task {
                do {
                    let res = try await controller.discover(page: 1)
                    await MainActor.run {
                        self.models = res
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run { isLoading = false }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if models.isEmpty {
                    ContentUnavailableView("No Models Available", systemImage: "cube.transparent")
                }
            }
        }
    }
}

// MARK: - Send Model View
struct SendModelView: View {
    let friend: User
    @State private var myModels: [FurnitureAPIModel] = []
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    
    private let modelController = ModelController()
    private let session = Session.shared

    var body: some View {
        NavigationStack {
            List(myModels) { model in
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.name)
                            .font(.headline)
                        Text(model.categories)
                            .font(.caption)
                    }
                    Spacer()
                    Button {
                        sendModel(model)
                    } label: {
                        Text("Send")
                            .bold()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Send to \(friend.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadMyModels()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if myModels.isEmpty {
                    ContentUnavailableView("No Models", systemImage: "cube", description: Text("You have no models in the cloud to send."))
                }
            }
        }
    }

    private func loadMyModels() async {
        isLoading = true
        do {
            let result = try await modelController.discover(page: 1)
            await MainActor.run {
                self.myModels = result
                self.isLoading = false
            }
        } catch {
            print("Failed to load models to share: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    private func sendModel(_ model: FurnitureAPIModel) {
        guard let modelId = model.id, let receiverId = friend.id, let senderId = session.currentUser?.id else { return }
        let request = ShareRequest(senderId: senderId, receiverId: receiverId, modelId: modelId)
        
        Task {
            do {
                try await modelController.shareModel(request: request)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to share model: \(error)")
            }
        }
    }
}

// MARK: - Live Stream View
struct LiveStreamView: View {
    let session: StreamSessionResponse
    let isHost: Bool
    let modelName: String
    @StateObject private var streamController = StreamController()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 400)
                    
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(isHost ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: isHost ? "video.fill" : "eye.fill")
                                .font(.system(size: 40))
                                .foregroundColor(isHost ? .red : .blue)
                        }
                        
                        VStack(spacing: 8) {
                            Text(isHost ? "Hosting Live Stream" : "Viewing Live Stream")
                                .font(.title2.bold())
                            
                            Text("Model: \(modelName)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Stream ID: \(session.streamId)")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        
                        if isHost {
                            Button {
                                UIPasteboard.general.string = session.streamId
                            } label: {
                                Label("Copy Stream ID", systemImage: "doc.on.doc")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                Button(role: .destructive) {
                    streamController.stop()
                    dismiss()
                } label: {
                    Text(isHost ? "End Stream" : "Leave Stream")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle(isHost ? "Streaming Live" : "AR Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if isHost {
                    streamController.startHost(wsURL: session.hostWs)
                } else {
                    streamController.startViewer(wsURL: session.viewerWs)
                }
            }
        }
    }
}
