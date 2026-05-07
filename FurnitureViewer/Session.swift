import Foundation
import SwiftUI
import Combine

class Session: ObservableObject {
    static let shared = Session()
    
    @Published var currentUser: User
    
    private init() {

        self.currentUser = User(
            id: "philipp-01",
            firstName: "Philipp",
            lastName: "User",
            username: "philippm01"
        )
    }
}
