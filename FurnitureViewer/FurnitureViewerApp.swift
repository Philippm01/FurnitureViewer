import SwiftUI

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
            
            Text("User Profile")
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

@main
struct FurnitureViewerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
