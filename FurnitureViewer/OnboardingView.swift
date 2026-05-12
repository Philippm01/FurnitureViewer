import SwiftUI

struct OnboardingView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var existingUserToConfirm: User?
    @State private var showConfirmation = false
    
    private let userController = UserController()
    private let session = Session.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("Furniture Viewer")
                        .font(.largeTitle.bold())
                    
                    Text("Capture and share your 3D world.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                if showConfirmation, let user = existingUserToConfirm {
                    VStack(spacing: 20) {
                        Text("Welcome back!")
                            .font(.title2.bold())
                        
                        VStack(spacing: 8) {
                            Text("\(user.firstName) \(user.lastName)")
                                .font(.headline)
                            Text("@\(user.username)")
                                .foregroundColor(.secondary)
                            Text("ID: \(user.id ?? "Unknown")")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        
                        Button {
                            session.login(user: user)
                        } label: {
                            Text("Yes, this is me")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("No, use a different name") {
                            showConfirmation = false
                            existingUserToConfirm = nil
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 40)
                    .transition(.move(edge: .trailing))
                } else {
                    VStack(spacing: 16) {
                        TextField("First Name", text: )
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Last Name", text: )
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Username", text: )
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 40)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        handleGetStarted()
                    } label: {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Get Started")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)
                    .disabled(isLoading || username.isEmpty)
                }

                Spacer()
            }
            .animation(.default, value: showConfirmation)
            .navigationBarHidden(true)
        }
    }

    private func handleGetStarted() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await userController.search(name: username)
                
                if let existingUser = results.first(where: { zsh.username.lowercased() == username.lowercased() }) {
                    await MainActor.run {
                        self.existingUserToConfirm = existingUser
                        self.showConfirmation = true
                        self.isLoading = false
                    }
                } else {
                    let newUser = User(id: nil, firstName: firstName, lastName: lastName, username: username)
                    let createdUser = try await userController.create(user: newUser)
                    await MainActor.run {
                        session.login(user: createdUser)
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
