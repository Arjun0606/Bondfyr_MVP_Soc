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
import FirebaseStorage
import GoogleSignIn
import AuthenticationServices

class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // Track authentication state
    @Published var authStateKnown: Bool = false
    @Published var isProfileComplete: Bool = false

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
                    // Update demo mode based on the signed-in user's email
                    let isReviewer = (user.email == AppStoreDemoManager.demoEmail)
                    AppStoreDemoManager.shared.isDemoAccount = isReviewer
                    if !isReviewer { AppStoreDemoManager.shared.hostMode = true }
                    
                    
                    // Check if we need to refresh the token
                    self.checkAndRefreshTokenIfNeeded(user: user)
                    
                    // Fetch the user profile and only set isLoggedIn if profile exists
                    self.fetchUserProfile { success in
                        DispatchQueue.main.async {
                            if success {
                                // Only set isLoggedIn if we have a valid profile
                                self.isLoggedIn = true
                            } else {
                                // For new users, we still want them logged in but without a profile
                                
                                self.isLoggedIn = true
                                self.currentUser = nil
                            }
                        }
                    }
                } else {
                    
                    self.isLoggedIn = false
                    self.currentUser = nil
                    // Clear demo mode on sign-out
                    AppStoreDemoManager.shared.isDemoAccount = false
                    AppStoreDemoManager.shared.hostMode = true
                }
            }
        }
    }
    
    // Check if token needs refresh and handle it
    private func checkAndRefreshTokenIfNeeded(user: User) {
        user.getIDTokenResult { tokenResult, error in
            if let error = error {
                
                return
            }
            
            guard let tokenResult = tokenResult else { return }
            
            // Check if token will expire soon (within 10 minutes)
            let expirationDate = tokenResult.expirationDate
            if expirationDate.timeIntervalSinceNow < 600 { // 10 minutes in seconds
                
                
                
                // Force token refresh
                user.getIDTokenForcingRefresh(true) { _, error in
                    if let error = error {
                        
                    } else {
                        
                    }
                }
            }
        }
    }

    func signInWithGoogle(presenting: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            
            let error = NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Firebase client ID"])
            completion(false, error)
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }

        
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
                
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                }
                completion(false, error)
                return
            }

            
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
            

            // First sign out to ensure clean auth state
            do {
                try Auth.auth().signOut()
            } catch {
                
                // Continue anyway
            }

            self.auth.signIn(with: credential) { authResult, authError in
                if let authError = authError {
                    
                    
                    DispatchQueue.main.async {
                        self.error = authError.localizedDescription
                    }
                    
                    completion(false, authError)
                } else {
                    
                    
                    // Save FCM token to Firestore after successful authentication
                    self.saveFCMTokenAfterSignIn()
                    // Set demo flag appropriately for Google sign-in
                    let isReviewer = (authResult?.user.email == AppStoreDemoManager.demoEmail)
                    AppStoreDemoManager.shared.isDemoAccount = isReviewer
                    if !isReviewer { AppStoreDemoManager.shared.hostMode = true }
                    
                    // After successful authentication, fetch the user profile
                    self.fetchUserProfile { success in
                        if success {
                            
                            
                            // Save the last sign-in time
                            UserDefaults.standard.set(Date(), forKey: "lastSignInTime")
                            
                            // Set logged in state only after confirming profile exists
                            DispatchQueue.main.async {
                                self.isLoggedIn = true
                                // Notify that user logged in
                                let userId = authResult?.user.uid
                                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: userId)
                            }
                        } else {
                            
                            DispatchQueue.main.async {
                                // For new users, we still want to consider the sign-in successful
                                self.isLoggedIn = true
                            }
                        }
                        
                        // Always complete with success if Firebase auth succeeded
                        completion(true, nil)
                    }
                }
            }
        }
    }

    // Apple Sign-In for App Store compliance (Guideline 4.8)
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        AuthManager.shared.signInWithApple(credential: credential) { [weak self] result in
            guard let self = self else {
                completion(false, NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Auth view model deallocated"]))
            return
        }
        
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            switch result {
            case .success(_):
                // Save FCM token to Firestore after successful authentication
                self.saveFCMTokenAfterSignIn()
                
                // After successful authentication, fetch the user profile
                self.fetchUserProfile { success in
                    if success {
                        // Save the last sign-in time
                        UserDefaults.standard.set(Date(), forKey: "lastSignInTime")
                        
                        // Set logged in state only after confirming profile exists
                        DispatchQueue.main.async {
                            self.isLoggedIn = true
                            // Notify that user logged in
                            let userId = Auth.auth().currentUser?.uid
                            NotificationCenter.default.post(name: NSNotification.Name("UserDidLogin"), object: userId)
                        }
                    } else {
                        DispatchQueue.main.async {
                            // For new users, we still want to consider the sign-in successful
                            self.isLoggedIn = true
                        }
                    }
                    
                    // Always complete with success if Firebase auth succeeded
                    completion(true, nil)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                }
                completion(false, error)
            }
        }
    }
    

    
    // MARK: - Email/Password Sign-In
    
    func signInWithEmail(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        auth.signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else {
                completion(false, NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Auth view model deallocated"]))
                return
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("❌ Email/Password sign-in failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                }
                completion(false, error)
                return
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user returned"])
                DispatchQueue.main.async {
                    self.error = "Sign-in failed"
                }
                completion(false, error)
                return
            }
            
            print("✅ Email/Password sign-in successful for user: \(user.uid)")
            
            // Fetch user profile from Firestore
            self.db.collection("users").document(user.uid).getDocument { document, error in
                if let error = error {
                    print("❌ Error fetching user profile: \(error)")
                    DispatchQueue.main.async {
                        self.error = "Failed to load user profile"
                    }
                    completion(false, error)
                    return
                }
                
                guard let document = document, document.exists, let data = document.data() else {
                    print("❌ User profile not found in Firestore")
                    DispatchQueue.main.async {
                        self.error = "User profile not found"
                    }
                    completion(false, NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "User profile not found"]))
                    return
                }
                
                // Create AppUser from Firestore data
                let roleString = data["role"] as? String ?? "user"
                let userRole = AppUser.UserRole(rawValue: roleString) ?? .user
                
                let appUser = AppUser(
                    uid: data["uid"] as? String ?? user.uid,
                    name: data["name"] as? String ?? "",
                    email: data["email"] as? String ?? user.email ?? "",
                    dob: (data["dob"] as? Timestamp)?.dateValue() ?? Date(timeIntervalSince1970: 631152000),
                    phoneNumber: data["phoneNumber"] as? String ?? "",
                    role: userRole,
                    username: data["username"] as? String,
                    gender: data["gender"] as? String,
                    bio: data["bio"] as? String,
                    instagramHandle: data["instagramHandle"] as? String,
                    snapchatHandle: data["snapchatHandle"] as? String,
                    avatarURL: data["avatarURL"] as? String,
                    googleID: data["googleID"] as? String,
                    city: data["city"] as? String
                )
                
                DispatchQueue.main.async {
                    self.currentUser = appUser
                    self.isLoggedIn = true
                    self.error = nil
                    
                    // Check if this is the demo account
                    if user.email == AppStoreDemoManager.demoEmail {
                        AppStoreDemoManager.shared.isDemoAccount = true
                        print("🎭 Demo account detected and logged in")
                        print("🎭 Setting up complete App Store reviewer experience...")
                        
                        // Force create fresh demo parties on every login for consistent review experience
                        Task {
                            // Wait a moment for user profile to be fully loaded
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                            await AppStoreDemoManager.shared.createDemoParties()
                            print("🎭 Demo parties ready - reviewer can test both HOST and GUEST experiences")
                            
                            // Force refresh the UI
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshPartyData"), object: nil)
                            }
                        }
                    } else {
                        // Ensure demo mode is OFF for non-reviewer accounts
                        AppStoreDemoManager.shared.isDemoAccount = false
                        AppStoreDemoManager.shared.hostMode = true
                    }
                }
                
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Email/Password Sign-Up
    
    func signUpWithEmail(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        auth.createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else {
                completion(false, NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Auth view model deallocated"]))
                return
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("❌ Email/Password sign-up failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                }
                completion(false, error)
                return
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user returned"])
                DispatchQueue.main.async {
                    self.error = "Sign-up failed"
                }
                completion(false, error)
                return
            }
            
            print("✅ Email/Password sign-up successful for user: \(user.uid)")
            
            // Create basic user profile in Firestore
            let userData: [String: Any] = [
                "uid": user.uid,
                "name": "", // Will be filled during profile completion
                "email": user.email ?? email,
                "dob": Timestamp(date: Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()),
                "phoneNumber": "",
                "role": "user",
                "createdAt": Timestamp(date: Date()),
                "isHostVerified": false,
                "isGuestVerified": false,
                "hostedPartiesCount": 0,
                "attendedPartiesCount": 0,
                "hostRating": 0.0,
                "guestRating": 0.0,
                "hostRatingsCount": 0,
                "guestRatingsCount": 0
            ]
            
            self.db.collection("users").document(user.uid).setData(userData) { error in
                if let error = error {
                    print("❌ Error creating user profile: \(error)")
                    DispatchQueue.main.async {
                        self.error = "Failed to create user profile"
                    }
                    completion(false, error)
                    return
                }
                
                print("✅ User profile created successfully")
                DispatchQueue.main.async {
                    self.isLoggedIn = true
                    self.error = nil
                }
                
                completion(true, nil)
            }
        }
    }
    
    func fetchUserProfile(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
                completion(false)
                return
            }
            
        let db = Firestore.firestore()
        func handleSnapshot(_ data: [String: Any]?) -> Bool {
            guard let data = data,
               let name = data["name"] as? String,
               let email = data["email"] as? String,
               let dobTimestamp = data["dob"] as? Timestamp,
                  let phoneNumber = data["phoneNumber"] as? String else {
                return false
            }
                
                let dob = dobTimestamp.dateValue()
                let roleString = data["role"] as? String ?? "user"
                let role = AppUser.UserRole(rawValue: roleString) ?? .user
                let username = data["username"] as? String
                let gender = data["gender"] as? String
                let bio = data["bio"] as? String
                let instagramHandle = data["instagramHandle"] as? String
                let snapchatHandle = data["snapchatHandle"] as? String
                let avatarURL = data["avatarURL"] as? String
                let googleID = data["googleID"] as? String
                let city = data["city"] as? String
                
                // --- Verification & Reputation ---
                let isHostVerified = data["isHostVerified"] as? Bool ?? false
                let isGuestVerified = data["isGuestVerified"] as? Bool ?? false
                let hostedPartiesCount = data["hostedPartiesCount"] as? Int ?? 0
                let attendedPartiesCount = data["attendedPartiesCount"] as? Int ?? 0
                let hostRating = data["hostRating"] as? Double ?? 0.0
                let guestRating = data["guestRating"] as? Double ?? 0.0
                let hostRatingsCount = data["hostRatingsCount"] as? Int ?? 0
                let guestRatingsCount = data["guestRatingsCount"] as? Int ?? 0
                let totalLikesReceived = data["totalLikesReceived"] as? Int ?? 0
                let successfulPartiesCount = data["successfulPartiesCount"] as? Int ?? 0

                let user = AppUser(
                    uid: uid,
                    name: name,
                    email: email,
                    dob: dob,
                    phoneNumber: phoneNumber,
                    role: role,
                    username: username,
                    gender: gender,
                    bio: bio,
                    instagramHandle: instagramHandle,
                    snapchatHandle: snapchatHandle,
                    avatarURL: avatarURL,
                    googleID: googleID,
                    city: city,
                    partiesHosted: hostedPartiesCount,
                    partiesAttended: attendedPartiesCount,
                    isHostVerified: isHostVerified,
                    isGuestVerified: isGuestVerified
                )
                
                DispatchQueue.main.async {
                self.currentUser = user
                    let hasUsername = username?.isEmpty == false
                    let hasGender = gender?.isEmpty == false
                    let hasCity = city?.isEmpty == false
                self.isProfileComplete = hasUsername && hasGender && hasCity
            }
            return true
        }
        
        // Try server first
        db.collection("users").document(uid).getDocument(source: .default) { [weak self] snapshot, error in
            if let data = snapshot?.data(), handleSnapshot(data) {
                    completion(true)
                return
                }
            // Fallback to cache to avoid blocking on App Check/Network
            db.collection("users").document(uid).getDocument(source: .cache) { snapshot, _ in
                if handleSnapshot(snapshot?.data()) {
                    completion(true)
            } else {
                    // Final fallback to shallow local profile so UI doesn't appear empty
                    if let shallow = UserDefaults.standard.dictionary(forKey: "localProfile_\(uid)") {
                        var data: [String: Any] = [
                            "name": shallow["name"] as? String ?? "",
                            "email": Auth.auth().currentUser?.email ?? "",
                            "dob": Timestamp(date: Date(timeIntervalSince1970: 631152000)),
                            "phoneNumber": ""
                        ]
                        for (k, v) in shallow { data[k] = v }
                        _ = handleSnapshot(data)
                        completion(true)
                    } else {
                completion(false)
                    }
                }
            }
        }
    }

    func logout(completion: ((Error?) -> Void)? = nil) {
        print("🚪 Starting logout process...")
        
        // First, send the logout notification before actual logout
        // to make sure all observers get notified
        NotificationCenter.default.post(name: NSNotification.Name("UserWillLogout"), object: nil)
        
        DispatchQueue.main.async {
            // Reset local state immediately
            print("🔄 Resetting local auth state...")
            self.currentUser = nil
            self.isLoading = true
        }
        
        do {
            // Make sure Firebase Auth user is signed out
            try auth.signOut()
            print("✅ Firebase auth sign out successful")
            
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.isLoading = false
                self.authStateKnown = true  // Make sure auth state is known
                
                print("📢 Posting logout notification...")
                // Now post the actual logout notification
                NotificationCenter.default.post(name: NSNotification.Name("UserDidLogout"), object: nil)
            }
            
            // Reset to initial state if needed
            resetAppToInitialState()
            
            completion?(nil)
            print("✅ Logout completed successfully")
        } catch {
            print("❌ Logout error: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.error = "Failed to log out: \(error.localizedDescription)"
                self.isLoading = false
            }
            
            completion?(error)
        }
    }
    
    // Save FCM token to Firestore after successful sign-in
    private func saveFCMTokenAfterSignIn() {
        // Use the new FCM notification manager to handle token saving
        Task {
            await FCMNotificationManager.shared.updateUserFCMToken()
        }
    }
    
    private func resetAppToInitialState() {
        print("🔄 Resetting app to initial state...")
        
        // Clear user-specific data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "lastViewedEventId")
        UserDefaults.standard.removeObject(forKey: "chat_username")
        UserDefaults.standard.removeObject(forKey: "chat_username_updated")
        UserDefaults.standard.removeObject(forKey: "lastSignInTime")
        
        // For account deletion, also clear profile completion status
        UserDefaults.standard.removeObject(forKey: "profileCompleted")
        
        // Clear any cached tickets or saved events
        UserDefaults.standard.removeObject(forKey: "savedEvents")
        UserDefaults.standard.removeObject(forKey: "myTickets")
        
        // Clear demo mode settings on logout
        UserDefaults.standard.removeObject(forKey: "isDemoMode")
        
        // Don't clear onboarding status - user has already seen it
        // UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
        
        UserDefaults.standard.synchronize()
        print("✅ App state reset complete")
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
                
                
                DispatchQueue.main.async {
                    self.error = "Failed to update profile: \(error.localizedDescription)"
                }
            } else {
                
                
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
        
        // First, delete the user's Firestore data manually (since Cloud Function isn't working)
        // Delete user subcollections first, then the main user document
        let userRef = db.collection("users").document(uid)
        
        // Delete user subcollections
        let subcollections = ["stats", "badges", "tickets", "fcmTokens", "deviceTokens"]
        let group = DispatchGroup()
        
        for subcollection in subcollections {
            group.enter()
            userRef.collection(subcollection).getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    for document in documents {
                        document.reference.delete()
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Now delete the main user document
            userRef.delete { [weak self] firestoreError in
                guard let self = self else { return }
                
                if let firestoreError = firestoreError {
                    
                    // Continue anyway - we'll still try to delete the auth user
                } else {
                    
                }
                
                // Now delete Firebase Auth user
                user.delete { [weak self] authError in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    
                    if let authError = authError {
                        
                        
                        // Check if error is due to requiring recent authentication
                        let error = authError as NSError
                        if error.domain == AuthErrorDomain && 
                           error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                            
                            
                            
                            DispatchQueue.main.async {
                                self.error = "For security reasons, you need to sign in again before deleting your account"
                            }
                            
                            // Force logout in this case
                            self.logout { _ in
                                completion(authError)
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.error = "Failed to delete account: \(authError.localizedDescription)"
                            }
                            
                            completion(authError)
                        }
                    } else {
                        
                        
                        // Clear local state
                        DispatchQueue.main.async {
                            self.currentUser = nil
                            self.isLoggedIn = false
                            self.isProfileComplete = false // Reset profile completion status
                        }
                        
                        // Post notification that user was deleted
                        NotificationCenter.default.post(name: NSNotification.Name("UserWasDeleted"), object: nil)
                        
                        // Reset app state
                        self.resetAppToInitialState()
                        
                        completion(nil)
                    }
                }
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
        db.collection("users").document(user.uid).setData(userData, completion: { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                
                
                DispatchQueue.main.async {
                    self.error = "Failed to create profile: \(error.localizedDescription)"
                }
                
                completion(false, error)
            } else {
                
                
                // Create local user object
                let appUser = AppUser(
                    uid: user.uid,
                    name: name,
                    email: user.email ?? "",
                    dob: dob,
                    phoneNumber: phoneNumber,
                    role: .user, // Explicitly set the role to match Firestore
                    partiesHosted: 0,
                    partiesAttended: 0,
                    isHostVerified: false,
                    isGuestVerified: false
                )
                
                DispatchQueue.main.async {
                    self.currentUser = appUser
                    self.isLoggedIn = true
                }
                
                completion(true, nil)
            }
        })
    }

    func updateProfile(
        username: String? = nil,
        gender: String? = nil,
        bio: String? = nil,
        instagramHandle: String? = nil,
        snapchatHandle: String? = nil,
        avatarURL: String? = nil,
        city: String? = nil,
        dob: Date? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            completion(.failure(NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])))
            return
        }
        
        // For email/password users, displayName might be nil initially
        let displayName = user.displayName ?? ""
        
        let uid = user.uid
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        // First check if user document exists
        db.collection("users").document(uid).getDocument(source: .default) { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = error.localizedDescription
                    completion(.failure(error))
                }
                return
            }
            
            let documentExists = document?.exists == true
            var userData: [String: Any] = [:]
            
            if documentExists {
                // For existing users, only update provided fields
                if let username = username {
                    userData["username"] = username
                }
                if let gender = gender {
                    userData["gender"] = gender.isEmpty ? NSNull() : gender
                }
                if let bio = bio {
                    userData["bio"] = bio.isEmpty ? NSNull() : bio
                }
                if let instagramHandle = instagramHandle {
                    userData["instagramHandle"] = instagramHandle.isEmpty ? NSNull() : instagramHandle
                }
                if let snapchatHandle = snapchatHandle {
                    userData["snapchatHandle"] = snapchatHandle.isEmpty ? NSNull() : snapchatHandle
                }
                if let avatarURL = avatarURL {
                    userData["avatarURL"] = avatarURL.isEmpty ? NSNull() : avatarURL
                }
                if let city = city {
                    userData["city"] = city
                }
                if let dob = dob {
                    userData["dob"] = Timestamp(date: dob)
                }
                userData["lastUpdated"] = Timestamp()
            } else {
                // For new users, create complete profile with required fields
                userData = [
                    "uid": uid,
                    "name": displayName,
                    "email": email,
                    "dob": dob != nil ? Timestamp(date: dob!) : Timestamp(date: Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()),
                    "phoneNumber": user.phoneNumber ?? "",
                    "role": "user",
                    "username": username ?? "",
                    "gender": gender?.isEmpty == false ? gender : NSNull(),
                    "bio": bio?.isEmpty == false ? bio : NSNull(),
                    "instagramHandle": instagramHandle?.isEmpty == false ? instagramHandle : NSNull(),
                    "snapchatHandle": snapchatHandle?.isEmpty == false ? snapchatHandle : NSNull(),
                    "avatarURL": avatarURL?.isEmpty == false ? avatarURL : NSNull(),
                    "googleID": uid,
                    "city": city ?? "",
                    "isHostVerified": false,
                    "isGuestVerified": false,
                    "hostedPartiesCount": 0,
                    "attendedPartiesCount": 0,
                    "hostRating": 0.0,
                    "guestRating": 0.0,
                    "hostRatingsCount": 0,
                    "guestRatingsCount": 0,
                    "totalEarnings": 0.0,
                    "totalSpent": 0.0,
                    "totalLikesReceived": 0,
                    "partyReviews": [],
                    "socialProfiles": [:],
                    "preferences": [:],
                    "createdAt": Timestamp(date: Date()),
                    "lastActiveAt": Timestamp(date: Date()),
                    "lastUpdated": Timestamp()
                ]
            }
            
            // Enforce unique username (case-insensitive)
            if let desiredUsername = username, !desiredUsername.isEmpty {
                let lower = desiredUsername.lowercased()
                let usernamesRef = self.db.collection("usernames").document(lower)
                self.db.runTransaction({ (txn, errPtr) -> Any? in
                    do {
                        let snap = try txn.getDocument(usernamesRef)
                        if let data = snap.data(), let existingUid = data["uid"] as? String, existingUid != uid {
                            // Username taken
                            errPtr?.pointee = NSError(domain: "auth", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username already taken"])
                            return nil
                        }
                        // Reserve/assign to current user
                        txn.setData(["uid": uid, "updatedAt": Timestamp()], forDocument: usernamesRef, merge: true)
                    } catch {
                        // If not found, set it
                        txn.setData(["uid": uid, "updatedAt": Timestamp()], forDocument: usernamesRef)
                    }
                    return nil
                }) { _, txnError in
                    if let txnError = txnError {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.error = txnError.localizedDescription
                            completion(.failure(txnError))
                        }
                        return
                    }
                }
            }
            
            // Use appropriate Firestore operation
            let operation: (([String: Any], @escaping (Error?) -> Void) -> Void) = documentExists ? 
                { data, completion in
                    self.db.collection("users").document(uid).updateData(data, completion: completion)
                } : 
                { data, completion in
                    self.db.collection("users").document(uid).setData(data, completion: completion)
                }
            
            // Perform the operation
            operation(userData) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                
                if let error = error {
                    
                    completion(.failure(error))
                } else {
                    // Persist a shallow local copy for fast restore on next login
                    var local: [String: Any] = [:]
                    if let username = username { local["username"] = username }
                    if let gender = gender { local["gender"] = gender }
                    if let city = city { local["city"] = city }
                    if let bio = bio { local["bio"] = bio }
                    if let instagramHandle = instagramHandle { local["instagramHandle"] = instagramHandle }
                    if let snapchatHandle = snapchatHandle { local["snapchatHandle"] = snapchatHandle }
                    if let avatarURL = avatarURL { local["avatarURL"] = avatarURL }
                    UserDefaults.standard.set(local, forKey: "localProfile_\(uid)")
                    UserDefaults.standard.set(true, forKey: "profileCompleted_\(uid)")
                    
                    
                    // Refresh user profile to get updated data
                    self?.fetchUserProfile { success in
                        if success {
                            // Update profile completion status
                            DispatchQueue.main.async {
                                let hasUsername = self?.currentUser?.username?.isEmpty == false
                                let hasGender = self?.currentUser?.gender?.isEmpty == false
                                let hasCity = self?.currentUser?.city?.isEmpty == false
                                self?.isProfileComplete = hasUsername && hasGender && hasCity
                            }
                            completion(.success(()))
                        } else {
                            // Be resilient: if Firestore fetch fails (e.g., App Check hiccup),
                            // mark completion locally and proceed. UI will refresh once Firestore is reachable.
                            DispatchQueue.main.async {
                                // Create a minimal local currentUser so navigation can continue
                                if let uid = Auth.auth().currentUser?.uid, let email = Auth.auth().currentUser?.email {
                                    let localUser = AppUser(
                                        uid: uid,
                                        name: "",
                                        email: email,
                                        dob: dob ?? Date(timeIntervalSince1970: 631152000),
                                        phoneNumber: "",
                                        role: .user,
                                        username: username ?? "",
                                        gender: gender,
                                        bio: bio,
                                        instagramHandle: instagramHandle,
                                        snapchatHandle: snapchatHandle,
                                        avatarURL: avatarURL,
                                        city: city
                                    )
                                    self?.currentUser = localUser
                                    let hasUsername = (username?.isEmpty == false)
                                    let hasGender = (gender?.isEmpty == false)
                                    let hasCity = (city?.isEmpty == false)
                                    self?.isProfileComplete = hasUsername && hasGender && hasCity
                                }
                            }
                            // Background refresh later
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                self?.fetchUserProfile { _ in }
                            }
                            completion(.success(()))
                        }
                    }
                }
            }
        }
    }
    
    func uploadProfileImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])))
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])))
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let profileImageRef = storageRef.child("profile_images/\(uid).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        profileImageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            profileImageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let downloadURL = url {
                    completion(.success(downloadURL.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
    }
}
