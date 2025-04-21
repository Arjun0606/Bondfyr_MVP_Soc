//
//  AuthViewModel.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // Track authentication state
    @Published var authStateKnown: Bool = false

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let authStateListener = authStateListener {
            auth.removeStateDidChangeListener(authStateListener)
        }
    }
    
    // Setup a listener for Firebase auth state changes
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.authStateKnown = true
                
                if let user = user {
                    print("🔥 Auth state changed: User is logged in with UID: \(user.uid)")
                    self.isLoggedIn = true
                    
                    // Check if we need to refresh the token
                    self.checkAndRefreshTokenIfNeeded(user: user)
                    
                    // Fetch the user profile
                    self.fetchUserProfile { _ in }
                } else {
                    print("🔥 Auth state changed: User is logged out")
                    self.isLoggedIn = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    // Check if token needs refresh and handle it
    private func checkAndRefreshTokenIfNeeded(user: User) {
        user.getIDTokenResult { tokenResult, error in
            if let error = error {
                print("❌ Error getting token: \(error.localizedDescription)")
                return
            }
            
            guard let tokenResult = tokenResult else { return }
            
            // Check if token will expire soon (within 10 minutes)
            let expirationDate = tokenResult.expirationDate
            if expirationDate.timeIntervalSinceNow < 600 { // 10 minutes in seconds
                
                print("⚠️ Token expiring soon, refreshing...")
                
                // Force token refresh
                user.getIDTokenForcingRefresh(true) { _, error in
                    if let error = error {
                        print("❌ Error refreshing token: \(error.localizedDescription)")
                    } else {
                        print("✅ Token refreshed successfully")
                    }
                }
            }
        }
    }

    func signInWithGoogle(presenting: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ Firebase clientID missing")
            let error = NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Firebase client ID"])
            completion(false, error)
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }

        print("Starting Google Sign-In flow...")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { [weak self] result, error in
            guard let self = self else { 
                completion(false, NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Auth view model deallocated"]))
                return 
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("❌ Google Sign-In failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                }
                completion(false, error)
                return
            }

            print("✅ Google Sign-In success, getting credentials...")
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                
                let error = NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Google credentials"])
                DispatchQueue.main.async {
                    self.error = "Missing Google credentials"
                }
                completion(false, error)
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            print("Authenticating with Firebase...")

            // First sign out to ensure clean auth state
            do {
                try Auth.auth().signOut()
            } catch {
                print("⚠️ Warning while signing out before new sign in: \(error.localizedDescription)")
                // Continue anyway
            }

            self.auth.signIn(with: credential) { authResult, authError in
                if let authError = authError {
                    print("❌ Firebase auth failed: \(authError.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        self.error = authError.localizedDescription
                    }
                    
                    completion(false, authError)
                } else {
                    print("✅ Firebase auth success")
                    
                    DispatchQueue.main.async {
                        self.isLoggedIn = true
                    }
                    
                    // After successful authentication, fetch the user profile
                    self.fetchUserProfile { success in
                        if success {
                            print("✅ User profile loaded successfully")
                            
                            // Save the last sign-in time
                            UserDefaults.standard.set(Date(), forKey: "lastSignInTime")
                            
                            // Notify that user logged in
                            DispatchQueue.main.async {
                                let userId = authResult?.user.uid
                                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: userId)
                            }
                        } else {
                            print("⚠️ User profile not found, will need to create one")
                        }
                        
                        completion(success, nil)
                    }
                }
            }
        }
    }

    func fetchUserProfile(completion: @escaping (Bool) -> Void) {
        guard let uid = auth.currentUser?.uid else {
            print("❌ No Firebase user found when trying to fetch profile")
            
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isLoggedIn = false
            }
            
            completion(false)
            return
        }

        print("Fetching user profile for UID: \(uid)")
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error fetching user profile: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.error = "Failed to fetch profile: \(error.localizedDescription)"
                }
                
                if let nsError = error as NSError?, nsError.domain.contains("app_check") {
                    // AppCheck error - this is likely a temporary issue, don't reset auth state
                    print("⚠️ AppCheck error - this is likely a temporary issue")
                    completion(false)
                    return
                }
                
                // Keep isLoggedIn true if we have a valid Firebase user but had error fetching profile
                // This allows us to go to profile creation instead of sign-in loop
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isLoggedIn = self.auth.currentUser != nil
                }
                
                completion(false)
                return
            }
            
            // Check if document exists and has data
            if let data = snapshot?.data(),
               let name = data["name"] as? String,
               let email = data["email"] as? String,
               let dobTimestamp = data["dob"] as? Timestamp,
               let phoneNumber = data["phoneNumber"] as? String {

                let dob = dobTimestamp.dateValue()
                
                // Get role from user data or default to "user"
                let roleString = data["role"] as? String ?? "user"
                let role = AppUser.UserRole(rawValue: roleString) ?? .user
                
                let appUser = AppUser(uid: uid, name: name, email: email, dob: dob, phoneNumber: phoneNumber, role: role)

                print("User profile loaded: \(name)")
                
                DispatchQueue.main.async {
                    self.currentUser = appUser
                    self.isLoggedIn = true
                }
                
                completion(true)
            } else {
                print("User profile data incomplete or missing")
                
                DispatchQueue.main.async {
                    self.currentUser = nil
                    // Keep isLoggedIn true if we have a valid Firebase user but had error fetching profile
                    // This allows us to go to profile creation instead of sign-in loop
                    self.isLoggedIn = self.auth.currentUser != nil
                }
                
                completion(false)
            }
        }
    }

    func logout(completion: ((Error?) -> Void)? = nil) {
        print("Logging out user")
        
        // First, send the logout notification before actual logout
        // to make sure all observers get notified
        NotificationCenter.default.post(name: NSNotification.Name("UserWillLogout"), object: nil)
        
        DispatchQueue.main.async {
            // Reset local state immediately
            self.currentUser = nil
            self.isLoading = true
        }
        
        do {
            // Make sure Firebase Auth user is signed out
            try auth.signOut()
            
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.isLoading = false
                
                // Now post the actual logout notification
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
            }
            
            // Reset to initial state if needed
            resetAppToInitialState()
            
            completion?(nil)
        } catch {
            print("❌ Logout Error: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.error = "Failed to log out: \(error.localizedDescription)"
                self.isLoading = false
            }
            
            completion?(error)
        }
    }
    
    private func resetAppToInitialState() {
        // Clear user-specific data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "lastViewedEventId")
        UserDefaults.standard.removeObject(forKey: "chat_username")
        UserDefaults.standard.removeObject(forKey: "chat_username_updated")
        
        // Don't clear onboarding status
        // UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
        
        UserDefaults.standard.synchronize()
    }
    
    func updateCurrentUser(_ user: AppUser) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // Update Firestore with the user data
        let userRef = db.collection("users").document(user.uid)
        userRef.updateData([
            "name": user.name,
            "phoneNumber": user.phoneNumber,
            "role": user.role.rawValue
        ]) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Error updating user in Firestore: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.error = "Failed to update profile: \(error.localizedDescription)"
                }
            } else {
                print("User data updated successfully in Firestore")
                
                DispatchQueue.main.async {
                    self.currentUser = user
                }
            }
        }
    }
    
    func deleteAccount(completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            let error = NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
            completion(error)
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // Get user ID before deletion
        let uid = user.uid
        
        // Send notification that user will be deleted
        NotificationCenter.default.post(name: NSNotification.Name("UserWillBeDeleted"), object: nil)
        
        // Delete Firebase Auth user first - this is more secure and allows us to use a Cloud Function 
        // to clean up the user data in Firestore (which will have proper admin permissions)
        user.delete { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("❌ Error deleting auth user: \(error.localizedDescription)")
                
                // Check if error is due to requiring recent authentication
                let authError = error as NSError
                if authError.domain == AuthErrorDomain && 
                   authError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    
                    print("⚠️ Requires recent login, logging out user")
                    
                    DispatchQueue.main.async {
                        self.error = "For security reasons, you need to sign in again before deleting your account"
                    }
                    
                    // Force logout in this case
                    self.logout { _ in
                        completion(error)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.error = "Failed to delete account: \(error.localizedDescription)"
                    }
                    
                    completion(error)
                }
            } else {
                print("✅ User auth deleted successfully")
                
                // Note: Firestore data for this user should be deleted by a Cloud Function trigger
                // that listens for user deletion events
                
                // Clear local state
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isLoggedIn = false
                }
                
                // Post notification that user was deleted
                NotificationCenter.default.post(name: NSNotification.Name("UserWasDeleted"), object: nil)
                
                // Reset app state
                self.resetAppToInitialState()
                
                completion(nil)
            }
        }
    }
    
    // Create a new user profile in Firestore
    func createUserProfile(name: String, dob: Date, phoneNumber: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            let error = NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
            completion(false, error)
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // Create the user data
        let userData: [String: Any] = [
            "name": name,
            "email": user.email ?? "",
            "dob": Timestamp(date: dob),
            "phoneNumber": phoneNumber,
            "role": "user",
            "createdAt": Timestamp(date: Date())
        ]
        
        // Save to Firestore
        db.collection("users").document(user.uid).setData(userData) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("❌ Error creating user profile: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.error = "Failed to create profile: \(error.localizedDescription)"
                }
                
                completion(false, error)
            } else {
                print("✅ User profile created successfully")
                
                // Create local user object
                let appUser = AppUser(
                    uid: user.uid,
                    name: name,
                    email: user.email ?? "",
                    dob: dob,
                    phoneNumber: phoneNumber,
                    role: .user // Explicitly set the role to match Firestore
                )
                
                DispatchQueue.main.async {
                    self.currentUser = appUser
                    self.isLoggedIn = true
                }
                
                completion(true, nil)
            }
        }
    }
}
