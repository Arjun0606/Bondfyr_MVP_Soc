import SwiftUI
import FirebaseAuth
import GoogleSignIn

struct LoginView: View {
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToHome = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App logo
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.orange)
                    .padding(.bottom, 20)
                
                Text("Bondfyr")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.bottom, 20)
                
                Text("Connect with events around you")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                
                // Google sign in button
                Button(action: signInWithGoogle) {
                    HStack {
                        Image("google_logo") // Add this image to assets
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal, 40)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 20)
                }
                
                Spacer()
                
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .edgesIgnoringSafeArea(.all)
            .navigationBarHidden(true)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(isPresented: $navigateToHome) {
            HomeView()
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isLoading = false
            showAlert(with: "Could not initialize Google Sign-In")
            return
        }
        
        AuthManager.shared.signInWithGoogle(presenting: rootViewController) { result in
            isLoading = false
            
            switch result {
            case .success(_):
                navigateToHome = true
            case .failure(let error):
                showAlert(with: error.localizedDescription)
            }
        }
    }
    
    private func showAlert(with message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct HomeView: View {
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToLogin = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome to Bondfyr")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("You are successfully logged in!")
                    .font(.headline)
                    .padding()
                
                if let user = AuthManager.shared.getCurrentUser() {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("User Details:")
                            .font(.headline)
                            .padding(.top)
                        
                        Text("Email: \(user.email ?? "No email")")
                        
                        if let displayName = user.displayName, !displayName.isEmpty {
                            Text("Name: \(displayName)")
                        }
                        
                        if let photoURL = user.photoURL {
                            AsyncImage(url: photoURL) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                            }
                            .padding(.top)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                }
                
                Spacer()
                
                Button(action: signOut) {
                    Text("Sign Out")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .navigationBarTitle("Home", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(isPresented: $navigateToLogin) {
            LoginView()
        }
    }
    
    private func signOut() {
        let result = AuthManager.shared.signOut()
        
        switch result {
        case .success():
            navigateToLogin = true
        case .failure(let error):
            showAlert(with: error.localizedDescription)
        }
    }
    
    private func showAlert(with message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
