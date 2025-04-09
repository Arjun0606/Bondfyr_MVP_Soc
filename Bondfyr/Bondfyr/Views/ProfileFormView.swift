//
//  ProfileFormView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 25/03/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct ProfileFormView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var name: String = ""
    @State private var dob: Date = Date()
    @State private var phone: String = ""
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Complete Your Profile")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            TextField("Full Name", text: $name)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)

            DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)

            TextField("Phone Number", text: $phone)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)

            Text("Phone number is required for venue contact and event updates.")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: saveProfile) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Save & Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid() ? Color.pink : Color.gray)
                        .cornerRadius(10)
                }
            }
            .disabled(!isFormValid())

            Spacer()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("Failed to save your profile. Please try again."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func isFormValid() -> Bool {
        return !name.isEmpty && !phone.isEmpty
    }

    private func saveProfile() {
        guard let user = Auth.auth().currentUser else { return }

        isSaving = true

        let profile = AppUser(
            uid: user.uid,
            name: name,
            email: user.email ?? "",
            dob: dob,
            phoneNumber: phone
        )

        do {
            try Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .setData(from: profile) { error in
                    isSaving = false
                    if let error = error {
                        print("❌ Firestore Save Error: \(error.localizedDescription)")
                        showError = true
                    } else {
                        DispatchQueue.main.async {
                            authViewModel.currentUser = profile
                            authViewModel.isLoggedIn = true
                        }
                    }
                }
        } catch {
            print("❌ Encoding Error: \(error.localizedDescription)")
            isSaving = false
            showError = true
        }
    }
}
