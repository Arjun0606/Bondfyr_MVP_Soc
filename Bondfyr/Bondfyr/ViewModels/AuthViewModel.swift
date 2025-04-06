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
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isLoggedIn = false
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
                let appUser = AppUser(uid: uid, name: name, email: email, dob: dob, phoneNumber: phoneNumber)

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
                    self.isLoggedIn = false
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
                
                // Post notification that logout is complete
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
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
            // Example: clear out any user-specific cached data
            UserDefaults.standard.removeObject(forKey: "lastViewedEventId")
            
            // Don't clear out hasSeenOnboarding as we don't want to show onboarding again
        }
    }
}
