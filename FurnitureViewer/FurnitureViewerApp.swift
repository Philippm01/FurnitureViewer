import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                }
            
            Text("Models")
                .tabItem {
                    Image(systemName: "cube.fill")
                }
            
            Text("Contacts")
                .tabItem {
                    Image(systemName: "person.2.fill")
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
