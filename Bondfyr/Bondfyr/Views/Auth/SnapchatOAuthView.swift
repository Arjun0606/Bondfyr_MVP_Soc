import SwiftUI
import AuthenticationServices
import SafariServices

struct SnapchatOAuthView: View {
    @Environment(\.dismiss) private var dismiss
    let onSuccess: (String) -> Void
    let onManual: () -> Void
    
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var showWebView = false
    
    private let snapchatLoginURL = "https://accounts.snapchat.com/accounts/oauth2/auth"
    private let redirectURI = "bondfyr://auth/snapchat/callback"
    private let clientID = "YOUR_SNAPCHAT_CLIENT_ID" // Replace with actual client ID
    
    // Observer for auth callback
    private let authObserver = NotificationCenter.default
        .publisher(for: Notification.Name("SnapchatAuthSuccess"))
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                Text("Connect Snapchat")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Logo and description
                Image("snapchat_logo")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding(.bottom)
                
                Text("Connect your Snapchat account to find your friends and share your nightlife experiences.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    // Connect button
                    Button(action: connectWithSnapchat) {
                        HStack {
                            Image("snapchat_logo")
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text("Continue with Snapchat")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Manual entry option
                    Button(action: { onManual() }) {
                        Text("Enter username manually")
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                }
                
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .sheet(isPresented: $showWebView) {
                if let url = URL(string: "\(snapchatLoginURL)?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=user.display_name") {
                    SafariView(url: url)
                }
            }
            .onReceive(authObserver) { notification in
                handleAuthCallback(notification)
            }
        }
    }
    
    private func connectWithSnapchat() {
        showWebView = true
    }
    
    private func handleAuthCallback(_ notification: Notification) {
        guard let code = notification.userInfo?["code"] as? String else {
            error = "Failed to get authorization code"
            return
        }
        
        isLoading = true
        
        // Exchange code for access token and get user info
        // This would typically be done through your backend
        // For now, simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            showWebView = false
            
            // For testing, generate a random username
            let randomUsername = "user" + String(Int.random(in: 1000...9999))
            onSuccess(randomUsername)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    SnapchatOAuthView(
        onSuccess: { _ in },
        onManual: {}
    )
    .preferredColorScheme(.dark)
} 