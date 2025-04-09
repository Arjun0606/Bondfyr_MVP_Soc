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

    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    init() {
        if auth.currentUser != nil {
            fetchUserProfile { _ in }
            isLoggedIn = true
        }
    }

    func signInWithGoogle(presenting: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ Firebase clientID missing")
            completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing client ID"]))
            return
        }

        print("Starting Google Sign-In flow...")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { result, error in
            if let error = error {
                print("❌ Google Sign-In failed: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            print("✅ Google Sign-In success, getting credentials...")
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("❌ Missing Google credentials")
                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Google credentials"]))
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
                    completion(false, authError)
                } else {
                    print("✅ Firebase auth success")
                    DispatchQueue.main.async {
                        self.isLoggedIn = true
                    }
                    self.fetchUserProfile { success in
                        if success {
                            print("✅ User profile loaded successfully")
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
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user profile: \(error.localizedDescription)")
                if let nsError = error as NSError?, nsError.domain.contains("app_check") {
                    // AppCheck error - this is likely a temporary issue, don't reset auth state
                    print("⚠️ AppCheck error - this is likely a temporary issue")
                    completion(false)
                    return
                }
                
                DispatchQueue.main.async {
                    self.currentUser = nil
                    // Keep isLoggedIn true if we have a valid Firebase user but had error fetching profile
                    // This allows us to go to profile creation instead of sign-in loop
                    self.isLoggedIn = self.auth.currentUser != nil
                }
                completion(false)
                return
            }
            
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

    func logout() {
        print("Logging out user")
        do {
            try auth.signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isLoggedIn = false
                
                // Remove notification post from here since we're handling it in SettingsView
                // to better control the navigation flow
                // NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
            }
            
            // Reset to initial state if needed
            resetAppToInitialState()
        } catch {
            print("❌ Logout Error: \(error.localizedDescription)")
        }
    }
    
    private func resetAppToInitialState() {
        // This function can be expanded to clear any local state
        // that should be reset when a user logs out
        
        // For now, just ensure we're on the main thread
        DispatchQueue.main.async {
            // Clear any cached data that should be reset
            UserDefaults.standard.removeObject(forKey: "lastViewedEventId")
            
            // Clear other user-specific data
            UserDefaults.standard.synchronize()
            
            // Don't clear out hasSeenOnboarding as we don't want to show onboarding again
        }
    }
    
    func updateCurrentUser(_ user: AppUser) {
        DispatchQueue.main.async {
            self.currentUser = user
        }
        
        // Update Firestore with the user data
        let userRef = db.collection("users").document(user.uid)
        userRef.updateData([
            "name": user.name,
            "phoneNumber": user.phoneNumber,
            "role": user.role.rawValue
        ]) { error in
            if let error = error {
                print("Error updating user in Firestore: \(error.localizedDescription)")
            } else {
                print("User data updated successfully in Firestore")
            }
        }
    }
}
