import SwiftUI

struct OnboardingView: View {
    @State private var isLoginMode = true
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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

                Picker("Mode", selection: $isLoginMode) {
                    Text("Login").tag(true)
                    Text("Register").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                VStack(spacing: 16) {
                    if !isLoginMode {
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 40)
                .animation(.easeInOut, value: isLoginMode)

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
                        Text(isLoginMode ? "Login" : "Register")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .font(.headline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
                .disabled(isLoading || username.isEmpty || (!isLoginMode && (firstName.isEmpty || lastName.isEmpty)))

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private func handleGetStarted() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // If logging in, just send the username. 
                // The unified backend login route will match the user by username.
                let reqFirstName = isLoginMode ? "" : firstName
                let reqLastName = isLoginMode ? "" : lastName
                
                let authUser = User(id: nil, firstName: reqFirstName, lastName: reqLastName, username: username)
                let userResponse = try await userController.login(user: authUser)
                
                await MainActor.run {
                    session.login(user: userResponse)
                    self.isLoading = false
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
