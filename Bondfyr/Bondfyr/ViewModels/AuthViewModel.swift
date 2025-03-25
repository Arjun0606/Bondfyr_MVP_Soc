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
            completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing client ID"]))
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { result, error in
            if let error = error {
                completion(false, error)
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Google credentials"]))
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            self.auth.signIn(with: credential) { result, error in
                if let error = error {
                    completion(false, error)
                } else {
                    DispatchQueue.main.async {
                        self.isLoggedIn = true
                    }
                    self.fetchUserProfile { success in
                        completion(success, nil)
                    }
                }
            }
        }
    }

    func fetchUserProfile(completion: @escaping (Bool) -> Void) {
        guard let uid = auth.currentUser?.uid else {
            completion(false)
            return
        }

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let name = data["name"] as? String,
               let email = data["email"] as? String,
               let dobTimestamp = data["dob"] as? Timestamp,
               let phoneNumber = data["phoneNumber"] as? String {

                let dob = dobTimestamp.dateValue()
                let appUser = AppUser(uid: uid, name: name, email: email, dob: dob, phoneNumber: phoneNumber)

                DispatchQueue.main.async {
                    self.currentUser = appUser
                }
                completion(true)
            } else {
                DispatchQueue.main.async {
                    self.currentUser = nil
                }
                completion(false)
            }
        }
    }

    func logout() {
        do {
            try auth.signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.isLoggedIn = false
            }
        } catch {
            print("❌ Logout Error: \(error.localizedDescription)")
        }
    }
}
