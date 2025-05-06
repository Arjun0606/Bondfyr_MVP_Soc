//
//  ProfileFormView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 25/03/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import PhotosUI
import FirebaseStorage

struct ProfileFormView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Instagram
    @State private var instagramHandle: String = ""
    @State private var showInstagramSheet = false
    @State private var instagramConnected = false

    // Snapchat
    @State private var snapchatHandle: String = ""
    @State private var snapchatConnected = false

    // Profile Picture
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var profileImageURL: String? = nil

    // City Selection
    @State private var showCitySelector = false

    // Add @State private var showProfileSavedAlert = false
    @State private var showProfileSavedAlert = false

    // Add DOB state
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()

    // Navigation state
    @State private var showCitySelection = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Text("Set Up Your Profile")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 60)

                // Profile Picture
                Button(action: { showImagePicker = true }) {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.pink, lineWidth: 3))
                    } else {
                        ZStack {
                            Circle().fill(Color.gray.opacity(0.2)).frame(width: 80, height: 80)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.pink)
                        }
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(image: $profileImage)
                }

                // Instagram Handle
                TextField("Instagram username", text: $instagramHandle)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .disabled(!snapchatHandle.isEmpty)

                // Snapchat Handle
                TextField("Snapchat username", text: $snapchatHandle)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .disabled(!instagramHandle.isEmpty)

                // DOB Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date of Birth")
                        .foregroundColor(.white)
                        .font(.headline)
                    DatePicker("Select your date of birth", selection: $dob, in: ...Calendar.current.date(byAdding: .year, value: -16, to: Date())!, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                .padding(.horizontal)

                Spacer()

                Button(action: saveProfile) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    } else {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    }
                }
                .disabled(!canContinue)
                .background(canContinue ? Color.pink : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .padding(.bottom, 30)
            }
            .padding(.horizontal)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(hex: "1A1A1A")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Profile saved!", isPresented: $showProfileSavedAlert) {
                Button("OK") { showCitySelection = true }
            } message: {
                Text("Your social handle has been linked. Continue to select your city.")
            }
            .fullScreenCover(isPresented: $showCitySelection) {
                CitySelectionView { selectedCity in
                    if let user = Auth.auth().currentUser {
                        let db = Firestore.firestore()
                        db.collection("users").document(user.uid).setData([
                            "city": selectedCity,
                            "lastUpdated": Timestamp()
                        ], merge: true) { error in
                            if let error = error {
                                print("Failed to save city: \(error.localizedDescription)")
                            } else {
                                print("Selected city saved: \(selectedCity)")
                                authViewModel.fetchUserProfile { _ in
                                    // Only dismiss city selection if profile is now complete
                                    let hasSocial = (authViewModel.currentUser?.instagramHandle?.isEmpty == false) || (authViewModel.currentUser?.snapchatHandle?.isEmpty == false)
                                    let hasCity = (authViewModel.currentUser?.city?.isEmpty == false)
                                    if hasSocial && hasCity {
                                        showCitySelection = false
                                    }
                                }
                            }
                        }
                    }
                }.environmentObject(authViewModel)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var canContinue: Bool {
        let is16OrOlder = Calendar.current.date(byAdding: .year, value: 16, to: dob)! <= Date()
        let hasSocial = (instagramHandle.isEmpty != snapchatHandle.isEmpty)
        let hasProfilePic = profileImage != nil
        return hasProfilePic && hasSocial && is16OrOlder && !isSaving
    }

    private func saveProfile() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No authenticated user found"
            showError = true
            return
        }
        if instagramHandle.isEmpty && snapchatHandle.isEmpty {
            errorMessage = "You must enter at least one social handle to continue."
            showError = true
            return
        }
        isSaving = true
        // Upload profile image if selected
        if let image = profileImage {
            uploadProfileImage(image) { url in
                self.profileImageURL = url
                self.saveProfileToFirestore(user: user)
            }
        } else {
            self.saveProfileToFirestore(user: user)
        }
    }

    private func uploadProfileImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { completion(nil); return }
        let storageRef = Storage.storage().reference().child("profile_pics/")
            .child(UUID().uuidString + ".jpg")
        storageRef.putData(data, metadata: nil) { _, error in
            if let error = error {
                self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                self.showError = true
                completion(nil)
                return
            }
            storageRef.downloadURL { url, _ in
                completion(url?.absoluteString)
            }
        }
    }

    private func saveProfileToFirestore(user: User) {
        let db = Firestore.firestore()
        // Use the social handle as the name
        let name = !instagramHandle.isEmpty ? instagramHandle : snapchatHandle
        let data: [String: Any] = [
            "uid": user.uid,
            "name": name ?? "User",
            "email": user.email ?? "",
            "phoneNumber": "",
            "role": "user",
            "instagramHandle": instagramHandle.isEmpty ? nil : instagramHandle,
            "snapchatHandle": snapchatHandle.isEmpty ? nil : snapchatHandle,
            "avatarURL": profileImageURL,
            "dob": Timestamp(date: dob)
        ]
        
        db.collection("users").document(user.uid).setData(data, merge: true) { error in
            isSaving = false
            if let error = error {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
                showError = true
            } else {
                // Trigger city selection after profile is saved
                showProfileSavedAlert = true
                authViewModel.fetchUserProfile { _ in }  // Refresh user data
            }
        }
    }
}

// Helper view for displaying pre-filled Google info
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(.gray)
                .font(.caption)
            Text(value)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

