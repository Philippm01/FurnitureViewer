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

    private let friendsController = FriendsController()
    private let userController = UserController()

    var body: some View {
        List {
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
                SendModelView(friend: friend, storage: storage)
            }
        }
    }
    
    private func loadFriends() {
        guard let userId = session.currentUser.id, !userId.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let fetchedFriends = try await friendsController.listFriends(userId: userId)
                await MainActor.run {
                    self.friends = fetchedFriends
                    self.isLoading = false
                }
            } catch {
                print("Failed to load friends: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    private func searchUsers() {
        guard !searchText.isEmpty else { return }
        Task {
            do {
                let results = try await userController.search(name: searchText)
                await MainActor.run {
                    self.searchResults = results.filter { $0.id != session.currentUser.id }
                }
            } catch {
                print("Failed to search users: \(error)")
            }
        }
    }
    
    private func addFriend(friendId: String) {
        guard let userId = session.currentUser.id, !userId.isEmpty else { return }
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
        guard let userId = session.currentUser.id, !userId.isEmpty else { return }
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
    @ObservedObject var storage: ScanStorage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(storage.models) { model in
                HStack {
                    Text(model.metadata.name)
                    Spacer()
                    ShareLink(item: storage.modelURL(for: model)) {
                        Text("Send")
                            .bold()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
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
            .overlay {
                if storage.models.isEmpty {
                    ContentUnavailableView("No Models", systemImage: "cube", description: Text("You have no models to send."))
                }
            }
        }
    }
}
