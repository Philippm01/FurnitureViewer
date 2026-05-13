import Foundation
import SwiftUI
import Combine

class Session: ObservableObject {
    static let shared = Session()
    
    @Published var currentUser: User?
    
    private let userDefaultsKey = "saved_user"
    
    private init() {
        // loadUser()
    }
    
    func login(user: User) {
        self.currentUser = user
        saveUser()
    }
    
    func logout() {
        self.currentUser = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    func saveUser() {
        guard let user = currentUser else { return }
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadUser() {
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(User.self, from: savedData) {
            self.currentUser = decoded
        }
    }
}
