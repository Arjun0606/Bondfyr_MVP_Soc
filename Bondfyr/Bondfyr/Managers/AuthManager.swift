//
//  AuthManager.swift
//  Bondfyr
//
//  Created by Claude AI on 08/04/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices

enum AuthError: Error {
    case userNotFound
    case invalidCredentials
    case networkError
    case serverError
    case weakPassword
    case emailAlreadyInUse
    case invalidEmail
    case userDisabled
    case unknownError
    case missingEmail
    case missingPassword
    case missingUserData
    case appleSignInFailed
    case googleSignInFailed
    case notLoggedIn
}

class AuthManager {
    static let shared = AuthManager()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Sign In Methods
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, AuthError>) -> Void) {
        guard !email.isEmpty else {
            completion(.failure(.missingEmail))
            return
        }
        
        guard !password.isEmpty else {
            completion(.failure(.missingPassword))
            return
        }
        
        auth.signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                let authError = self.handleAuthError(error)
                completion(.failure(authError))
                return
            }
            
            guard let user = authResult?.user else {
                completion(.failure(.userNotFound))
                return
            }
            
            self.updateUserLastLogin(userId: user.uid)
            completion(.success(user))
        }
    }
    
    // MARK: - Sign Up Methods
    
    func signUp(email: String, password: String, name: String, phoneNumber: String, completion: @escaping (Result<User, AuthError>) -> Void) {
        guard !email.isEmpty else {
            completion(.failure(.missingEmail))
            return
        }
        
        guard !password.isEmpty else {
            completion(.failure(.missingPassword))
            return
        }
        
        guard !name.isEmpty else {
            completion(.failure(.missingUserData))
            return
        }
        
        auth.createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                let authError = self.handleAuthError(error)
                completion(.failure(authError))
                return
            }
            
            guard let user = authResult?.user else {
                completion(.failure(.userNotFound))
                return
            }
            
            // Create user profile in Firestore
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": email,
                "name": name,
                "phoneNumber": phoneNumber,
                "createdAt": Timestamp(),
                "lastLogin": Timestamp(),
                "photoURL": ""
            ]
            
            self.db.collection("users").document(user.uid).setData(userData) { error in
                if let error = error {
                    
                    completion(.failure(.serverError))
                    return
                }
                
                // Set display name
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = name
                
                changeRequest.commitChanges { error in
                    if let error = error {
                        
                    }
                    
                    // Send verification email
                    user.sendEmailVerification { error in
                        if let error = error {
                            
                        }
                        
                        completion(.success(user))
                    }
                }
            }
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle(presenting viewController: UIViewController, completion: @escaping (Result<User, AuthError>) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure(.googleSignInFailed))
            return
        }
        
        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController, hint: nil, additionalScopes: nil) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                
                completion(.failure(.googleSignInFailed))
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(.failure(.googleSignInFailed))
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            self.signInWithCredential(credential: credential) { result in
                switch result {
                case .success(let user):
                    // Update or create user profile in Firestore
                    if let email = user.email, let name = user.displayName {
                        let userData: [String: Any] = [
                            "uid": user.uid,
                            "email": email,
                            "name": name,
                            "photoURL": user.photoURL?.absoluteString ?? "",
                            "role": "user",
                            "lastLogin": Timestamp()
                        ]
                        
                        // Use setData with merge to update existing or create new
                        self.db.collection("users").document(user.uid).setData(userData, merge: true) { error in
                            if let error = error {
                                
                            }
                            completion(.success(user))
                        }
                    } else {
                        completion(.success(user))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, completion: @escaping (Result<User, AuthError>) -> Void) {
        guard let nonce = randomNonceString() else {
            completion(.failure(.appleSignInFailed))
            return
        }
        
        guard let appleIDToken = credential.identityToken else {
            completion(.failure(.appleSignInFailed))
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            completion(.failure(.appleSignInFailed))
            return
        }
        
        let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                idToken: idTokenString,
                                                rawNonce: nonce)
        
        signInWithCredential(credential: credential) { result in
            switch result {
            case .success(let user):
                // Update or create user profile in Firestore
                let email = user.email ?? "private@apple.com"
                let name = user.displayName ?? "Apple User"
                
                let userData: [String: Any] = [
                    "uid": user.uid,
                    "email": email,
                    "name": name,
                    "photoURL": user.photoURL?.absoluteString ?? "",
                    "role": "user",
                    "lastLogin": Timestamp()
                ]
                
                // Use setData with merge to update existing or create new
                self.db.collection("users").document(user.uid).setData(userData, merge: true) { error in
                    if let error = error {
                        print("Error updating user data: \(error)")
                    }
                    completion(.success(user))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Demo Sign In
    
    func signInWithDemo(completion: @escaping (Result<User, AuthError>) -> Void) {
        print("🔧 Starting demo sign-in with master demo account...")
        
        // Sign in with the dedicated demo account
        auth.signIn(withEmail: AppStoreDemoManager.demoEmail, password: AppStoreDemoManager.demoPassword) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                print("❌ Demo sign-in failed with error: \(error.localizedDescription)")
                
                // If account doesn't exist, create it
                if error.code == AuthErrorCode.userNotFound.rawValue {
                    print("🔧 Demo account not found, creating it...")
                    Task {
                        await AppStoreDemoManager.shared.createDemoAccountIfNeeded()
                        // Retry sign-in after creation
                        self.signInWithDemo(completion: completion)
                    }
                    return
                }
                
                let authError = self.handleAuthError(error)
                completion(.failure(authError))
                return
            }
            
            guard let user = authResult?.user else {
                print("❌ No user returned from anonymous auth")
                completion(.failure(.userNotFound))
                return
            }
            
            print("✅ Demo account sign-in successful for user: \(user.uid)")
            
            // Mark this as demo account
            AppStoreDemoManager.shared.isDemoAccount = true
            
            // Create demo user profile in Firestore - App Store Reviewer Account
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": "appstore.reviewer@bondfyr.demo",
                "name": "App Store Reviewer",
                "photoURL": "",
                "role": "user",
                "lastLogin": Timestamp(),
                "isDemoUser": true,
                "isAppStoreReviewer": true,
                "city": "San Francisco",
                "username": "AppReviewer",
                "dob": Date(timeIntervalSince1970: 631152000), // Jan 1, 1990 (33 years old)
                "phoneNumber": "+1-800-APP-STORE",
                "gender": "non-binary",
                "bio": "Demo account for App Store review process",
                "instagramHandle": "",
                "snapchatHandle": "",
                "avatarURL": "",
                "googleID": user.uid,
                "isHostVerified": true,
                "isGuestVerified": true,
                "hostedPartiesCount": 3,
                "attendedPartiesCount": 8,
                "hostRating": 4.8,
                "guestRating": 4.9,
                "hostRatingsCount": 15,
                "guestRatingsCount": 12,
                "totalEarnings": 150.0,
                "totalSpent": 89.0,
                "totalLikesReceived": 24,
                "createdAt": Timestamp(date: Date()),
                "lastActiveAt": Timestamp(date: Date())
            ]
            
            print("🔄 Creating demo user profile in Firestore...")
            self.db.collection("users").document(user.uid).setData(userData, merge: true) { error in
                if let error = error {
                    print("❌ Error creating demo user data: \(error.localizedDescription)")
                    completion(.failure(.serverError))
                    return
                }
                print("✅ Demo user profile created successfully")
                completion(.success(user))
            }
        }
    }
    
    // Helper function for Apple Sign In nonce
    private func randomNonceString(length: Int = 32) -> String? {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // MARK: - Sign Out
    
    func signOut() -> Result<Void, AuthError> {
        do {
            try auth.signOut()
            return .success(())
        } catch {
            
            return .failure(.unknownError)
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(for email: String, completion: @escaping (Result<Void, AuthError>) -> Void) {
        guard !email.isEmpty else {
            completion(.failure(.missingEmail))
            return
        }
        
        auth.sendPasswordReset(withEmail: email) { error in
            if let error = error as NSError? {
                let authError = self.handleAuthError(error)
                completion(.failure(authError))
                return
            }
            
            completion(.success(()))
        }
    }
    
    // MARK: - User Management
    
    func getCurrentUser() -> User? {
        return auth.currentUser
    }
    
    func isUserLoggedIn() -> Bool {
        return auth.currentUser != nil
    }
    
    func isEmailVerified() -> Bool {
        return auth.currentUser?.isEmailVerified ?? false
    }
    
    func resendVerificationEmail(completion: @escaping (Result<Void, AuthError>) -> Void) {
        guard let user = auth.currentUser else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        user.sendEmailVerification { error in
            if let error = error {
                
                completion(.failure(.serverError))
                return
            }
            
            completion(.success(()))
        }
    }
    
    func updateUserProfile(displayName: String? = nil, photoURL: URL? = nil, completion: @escaping (Result<Void, AuthError>) -> Void) {
        guard let user = auth.currentUser else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        let changeRequest = user.createProfileChangeRequest()
        
        if let displayName = displayName {
            changeRequest.displayName = displayName
        }
        
        if let photoURL = photoURL {
            changeRequest.photoURL = photoURL
        }
        
        changeRequest.commitChanges { error in
            if let error = error {
                
                completion(.failure(.serverError))
                return
            }
            
            // Also update Firestore
            var userData: [String: Any] = [:]
            
            if let displayName = displayName {
                userData["name"] = displayName
            }
            
            if let photoURL = photoURL {
                userData["photoURL"] = photoURL.absoluteString
            }
            
            if !userData.isEmpty {
                self.db.collection("users").document(user.uid).updateData(userData) { error in
                    if let error = error {
                        
                        completion(.failure(.serverError))
                        return
                    }
                    
                    completion(.success(()))
                }
            } else {
                completion(.success(()))
            }
        }
    }
    
    func updatePhoneNumber(phoneNumber: String, completion: @escaping (Result<Void, AuthError>) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        db.collection("users").document(userId).updateData([
            "phoneNumber": phoneNumber
        ]) { error in
            if let error = error {
                
                completion(.failure(.serverError))
                return
            }
            
            completion(.success(()))
        }
    }
    
    func fetchUserData(completion: @escaping (Result<[String: Any], AuthError>) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            completion(.failure(.notLoggedIn))
            return
        }
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                
                completion(.failure(.serverError))
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(.failure(.userNotFound))
                return
            }
            
            completion(.success(data))
        }
    }
    
    // MARK: - Helper Methods
    
    private func signInWithCredential(credential: AuthCredential, completion: @escaping (Result<User, AuthError>) -> Void) {
        auth.signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                let authError = self.handleAuthError(error)
                completion(.failure(authError))
                return
            }
            
            guard let user = authResult?.user else {
                completion(.failure(.userNotFound))
                return
            }
            
            self.updateUserLastLogin(userId: user.uid)
            completion(.success(user))
        }
    }
    
    private func updateUserLastLogin(userId: String) {
        db.collection("users").document(userId).updateData([
            "lastLogin": Timestamp()
        ]) { error in
            if let error = error {
                
            }
        }
    }
    
    private func handleAuthError(_ error: NSError) -> AuthError {
        let authErrorCode = AuthErrorCode(_bridgedNSError: error)
        
        guard let errorCode = authErrorCode else {
            
            return .unknownError
        }
        
        switch errorCode.code {
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .invalidCredentials
        case .networkError:
            return .networkError
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .invalidEmail:
            return .invalidEmail
        case .userDisabled:
            return .userDisabled
        default:
            
            return .unknownError
        }
    }
    
    // MARK: - User Roles
    
    func isVendorOrAdmin() -> Bool {
        guard let userId = auth.currentUser?.uid else {
            return false
        }
        
        // First check if we have a cached value for performance
        let cacheKey = "isVendorOrAdmin_\(userId)"
        if let cachedResult = UserDefaults.standard.object(forKey: cacheKey) as? Bool {
            return cachedResult
        }
        
        // For testing purposes, allow specific hardcoded IDs to be vendors/admins
        // In production, this should be removed
        let testVendorId = "KmUvYL9B1Sc4BwMwmrXdpCITmwm1" // Replace with your actual test user ID
        if userId == testVendorId {
            // Cache the result
            UserDefaults.standard.set(true, forKey: cacheKey)
            return true
        }
        
        // For production use - synchronous check (not ideal but necessary for UI rendering)
        var isVendorOrAdmin = false
        let semaphore = DispatchSemaphore(value: 0)
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            defer {
                semaphore.signal()
            }
            
            if let data = snapshot?.data(),
               let roleString = data["role"] as? String,
               let role = AppUser.UserRole(rawValue: roleString) {
                isVendorOrAdmin = (role == .vendor || role == .admin)
            }
        }
        
        // Wait for the result with a timeout
        _ = semaphore.wait(timeout: .now() + 3.0)
        
        // Cache the result
        UserDefaults.standard.set(isVendorOrAdmin, forKey: cacheKey)
        return isVendorOrAdmin
    }
}
