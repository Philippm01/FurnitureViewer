import Foundation
import SwiftUI
import Combine

class Session: ObservableObject {
    static let shared = Session()
    
    @Published var currentUser: User
    
    private init() {

        self.currentUser = User(
            id: "5b1e0f67-28f3-4a8d-8afa-2693dadf6c98",
            firstName: "Philipp",
            lastName: "User",
            username: "philippm01"
        )
    }
}
