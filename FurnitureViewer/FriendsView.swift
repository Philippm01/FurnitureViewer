import SwiftUI

struct FriendsView: View {
    @StateObject private var session = Session.shared
    @StateObject private var storage = ScanStorage()
    @State private var friends: [User] = []
    @State private var searchResults: [User] = []
    @State private var searchText = ""
    @State private var isLoading = false
    
    @State private var receivedModels: [FurnitureAPIModel] = []
    @State private var isStreaming = false
    @State private var streamSession: StreamSessionResponse?

    private let friendsController = FriendsController()
    private let userController = UserController()
    private let modelController = ModelController()
    private let streamController = StreamController()

    var body: some View {
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
                
                ForEach(searchResults) { user in
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
                    ForEach(friends) { friend in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(friend.firstName) \(friend.lastName)")
                                    .font(.headline)
                                Text("@\(friend.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button {
                                startStream(with: friend)
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
        .sheet(isPresented: $showSendModelSheet) {
            if let friend = selectedFriendToSend {
                SendModelView(friend: friend)
            }
        }
        .fullScreenCover(isPresented: $isStreaming) {
            if let session = streamSession {
                LiveStreamView(session: session)
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

    private func startStream(with friend: User) {
        Task {
            do {
                let session = try await streamController.createSession()
                await MainActor.run {
                    self.streamSession = session
                    self.isStreaming = true
                }
            } catch {
                print("Failed to start stream: \(error)")
            }
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
            // For simplicity, we just fetch the discover list. 
            // In a real app, we'd fetch the user's own models.
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

struct LiveStreamView: View {
    let session: StreamSessionResponse
    @StateObject private var streamController = StreamController()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 400)
                    
                    VStack(spacing: 20) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.red)
                        
                        Text("Live Stream Session")
                            .font(.title2.bold())
                        
                        Text("ID: \(session.streamId)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Spacer()
                
                Button(role: .destructive) {
                    streamController.stop()
                    dismiss()
                } label: {
                    Text("End Stream")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Streaming")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                streamController.startHost(wsURL: session.hostWs)
            }
        }
    }
}
