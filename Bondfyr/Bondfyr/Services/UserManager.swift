import SwiftUI
import FirebaseAuth

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUserID: String?
    @Published var isAuthenticated = false
    
    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUserID = user?.uid
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        DispatchQueue.main.async {
            self.currentUserID = result.user.uid
            self.isAuthenticated = true
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        DispatchQueue.main.async {
            self.currentUserID = nil
            self.isAuthenticated = false
        }
    }
} 