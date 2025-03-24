//
//  AuthViewModel.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation
import FirebaseAuth
import Firebase
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift

class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser? = nil
    @Published var isLoggedIn: Bool = false

    private var auth = Auth.auth()
    private var db = Firestore.firestore()

    init() {
        self.isLoggedIn = auth.currentUser != nil
    }

    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("❌ Login error: \(error.localizedDescription)")
                completion(false)
                return
            }

            self.isLoggedIn = true
            completion(true)
        }
    }

    func signUp(name: String, email: String, password: String, dob: Date, completion: @escaping (Bool) -> Void) {
        auth.createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                print("❌ Sign up error: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let user = result?.user else {
                completion(false)
                return
            }
            let uid = user.uid

            let appUser = AppUser(uid: uid, name: name, email: email, dob: dob)


            do {
                try self.db.collection("users").document(uid).setData(from: appUser)
                self.currentUser = appUser

                self.isLoggedIn = true
                completion(true)
            } catch {
                print("❌ Firestore error: \(error.localizedDescription)")
                completion(false)
            }
        }
    }

    func logout() {
        do {
            try auth.signOut()
            self.isLoggedIn = false
            self.currentUser = nil
        } catch {
            print("❌ Logout error: \(error.localizedDescription)")
        }
    }

    func signInWithGoogle(presenting: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing client ID"]))
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { result, error in
            if let error = error {
                completion(false, error)
                return
            }

            guard let user = result?.user else {
                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user returned from Google Sign-In"]))
                return
            }

            guard let idToken = user.idToken?.tokenString else {
                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing ID Token"]))
                return
            }
            let accessToken = user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    completion(false, error)
                } else {
                    DispatchQueue.main.async {
                        self.isLoggedIn = true
                    }
                    completion(true, nil)
                }
            }
        }
    }
}
