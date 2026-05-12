import SwiftUI

struct RootView: View {
    @StateObject private var session = Session.shared
    
    var body: some View {
        if session.currentUser != nil {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("My Scans", systemImage: "cube.fill")
                }

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "globe")
                }
            
            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
        }
    }
}

@main
struct FurnitureViewerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
