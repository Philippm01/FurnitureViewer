import Foundation

class FriendsController {
    private let baseURL = APIConfig.friendsURL

    func listFriends(userId: String) async throws -> [User] {
        guard let url = URL(string: "\(baseURL)/\(userId)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([User].self, from: data)
    }

    func addFriend(userId: String, friendId: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(userId)/add") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["friend_id": friendId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            print("Add friend failed with status \(httpResponse.statusCode)")
        }
    }

    func removeFriend(userId: String, friendId: String) async throws {
        guard let url = URL(string: "\(baseURL)/\(userId)/remove") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["friend_id": friendId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            print("Remove friend failed with status \(httpResponse.statusCode)")
        }
    }
}
