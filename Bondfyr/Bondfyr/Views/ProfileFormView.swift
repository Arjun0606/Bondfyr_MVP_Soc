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
    @State private var isUploadingImage: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Form fields
    @State private var username: String = ""
    @State private var selectedGender: String = ""
    @State private var customGender: String = ""
    @State private var bio: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var profileImageURL: String = ""
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()

    // Instagram
    @State private var showInstagramSheet = false
    @State private var instagramConnected = false
    @State private var instagramHandle: String = ""

    // Snapchat
    @State private var snapchatConnected = false

    // UI state
    @State private var showImagePicker = false
    @State private var showProfileSavedAlert = false
    @State private var isInitialLoad = true
    @State private var authCheckCompleted = false

    // Auto-detect city
    @StateObject private var locationManager = LocationManager()
    
    // Profile completion check
    private var canContinue: Bool {
        let genderValid = !selectedGender.isEmpty && (selectedGender != "custom" || !customGender.isEmpty)
        let ageValid = isOver18(dob: dob)
        return !username.isEmpty && genderValid && ageValid
    }
    
    // Age verification helper
    private func isOver18(dob: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        return (ageComponents.year ?? 0) >= 18
    }
    
    // Check if this is editing mode
    private var isEditingMode: Bool {
        authViewModel.currentUser != nil && authViewModel.isProfileComplete
    }

    // Profile image view to avoid complex expression compilation
    private var profileImageView: some View {
        ZStack {
            if let image = profileImage {
                profileImageContent(image: image)
            } else if !profileImageURL.isEmpty {
                asyncImageContent
            } else {
                defaultImageContent
            }
            
            // Upload indicator
            if isUploadingImage {
                uploadIndicator
                        }
                    }
                }

    private func profileImageContent(image: UIImage) -> some View {
                        Image(uiImage: image)
                            .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.pink, lineWidth: 2))
    }
    
    private var asyncImageContent: some View {
                                AsyncImage(url: URL(string: profileImageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        )
                                }
                                .frame(width: 100, height: 100)
                            .clipShape(Circle())
                                .overlay(Circle().stroke(Color.pink, lineWidth: 2))
    }
    
    private var defaultImageContent: some View {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                            Image(systemName: "camera.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            }
                            
    private var uploadIndicator: some View {
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isEditingMode ? "Edit Profile" : "Complete Your Profile")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(isEditingMode ? "Update your Bondfyr profile" : "Create your unique Bondfyr profile")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .safeTopPadding(16)
    }
    
    @ViewBuilder
    private var googleInfoSection: some View {
        if !isEditingMode {
            VStack(alignment: .leading, spacing: 16) {
                Text("Account Information")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let user = Auth.auth().currentUser {
                    InfoRow(title: "Email", value: user.email ?? "Not provided")
                    InfoRow(title: "Name", value: user.displayName ?? "Not provided")
                } else {
                    // Show loading state while auth state loads
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Loading account info...")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding()
                }
            }
        }
    }
    
    private var profilePictureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile Picture")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: { showImagePicker = true }) {
                profileImageView
                    }
                    .disabled(isUploadingImage)
        }
                }

    private var usernameSection: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose Username *")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter your username", text: $username)
                    .padding()
                    .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(username.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    
                    if username.isEmpty {
                        Text("Username is required")
                            .font(.caption)
                            .foregroundColor(.red)
            }
                    }
                }

    private var genderSection: some View {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Gender *")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if isEditingMode {
                            Spacer()
                            Text("Cannot be changed after creation")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
            genderButtons
            customGenderField
            genderErrors
        }
    }
    
    private var genderButtons: some View {
                    HStack(spacing: 16) {
                        ForEach(["male", "female", "custom"], id: \.self) { gender in
                            Button(action: { 
                                if !isEditingMode {
                                    selectedGender = gender
                                    if gender != "custom" {
                                        customGender = ""
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedGender == gender ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedGender == gender ? .pink : .gray)
                                    Text(gender.capitalized)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedGender == gender ? Color.pink.opacity(0.2) : Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .opacity(isEditingMode ? 0.6 : 1.0)
                            }
                            .disabled(isEditingMode)
            }
                        }
                    }
                    
    @ViewBuilder
    private var customGenderField: some View {
                    if selectedGender == "custom" {
                        TextField("Enter your gender", text: $customGender)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .autocapitalization(.words)
                            .disabled(isEditingMode)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedGender == "custom" && customGender.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
        }
                    }
                    
    @ViewBuilder
    private var genderErrors: some View {
                    if selectedGender.isEmpty {
                        Text("Gender is required for party gender ratio calculations")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if selectedGender == "custom" && customGender.isEmpty {
                        Text("Please specify your gender")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

    private var bioSection: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Bio (Optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextEditor(text: $bio)
                        .frame(height: 80)
                        .padding(8)
                    .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                    
                    Text("Tell people a bit about yourself")
                        .font(.caption)
                        .foregroundColor(.gray)
        }
                }

    private var dobSection: some View {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Date of Birth")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if isEditingMode {
                            Spacer()
                            Text("Cannot be changed after creation")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                        .datePickerStyle(WheelDatePickerStyle())
                        .colorScheme(.dark)
                        .disabled(isEditingMode)
                        .opacity(isEditingMode ? 0.6 : 1.0)
                    
                    // Age verification warning
                    if !isOver18(dob: dob) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("You must be 18 or older to use Bondfyr")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Age verified")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 4)
                    }
        }
                }

    private var locationSection: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Location")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.pink)
                        Text(locationManager.currentCity ?? "Detecting location...")
                            .foregroundColor(.white)
                        Spacer()
                        if locationManager.currentCity == nil {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                                .scaleEffect(0.8)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    Text("Location is auto-detected for party discovery")
                        .font(.caption)
                        .foregroundColor(.gray)
        }
                }

    private var socialMediaSection: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Connect Social Media (Optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Connect to verify your identity and build trust")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
            instagramButton
            snapchatButton
        }
    }
    
    private var instagramButton: some View {
                    Button(action: { showInstagramSheet = true }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.pink)
                            VStack(alignment: .leading) {
                                Text(instagramConnected ? "Instagram Connected ✓" : "Connect Instagram")
                                    .foregroundColor(.white)
                                if instagramConnected && !instagramHandle.isEmpty {
                                    Text("@\(instagramHandle)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                Spacer()
                            Image(systemName: instagramConnected ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundColor(instagramConnected ? .green : .gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
        }
                    }
                    
    private var snapchatButton: some View {
                    Button(action: { snapchatConnected.toggle() }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.yellow)
                            Text(snapchatConnected ? "Snapchat Connected ✓" : "Connect Snapchat")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: snapchatConnected ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundColor(snapchatConnected ? .green : .gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }

    private var saveButtonSection: some View {
                Button(action: saveProfile) {
                    HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if !authCheckCompleted {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Verifying...")
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                            Text(isEditingMode ? "Save Changes" : "Complete Profile")
                            .font(.system(size: 16, weight: .semibold))
                        }
                    }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    }
                .disabled(!canContinue || isSaving || isUploadingImage || !authCheckCompleted)
                .background((canContinue && authCheckCompleted) ? Color.pink : Color.gray.opacity(0.3))
                .cornerRadius(12)
                .padding(.bottom, 30)
            }
    
    private var backgroundGradient: some View {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(hex: "1A1A1A")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection
                googleInfoSection
                profilePictureSection
                usernameSection
                genderSection
                bioSection
                dobSection
                locationSection
                socialMediaSection
                saveButtonSection
            }
            .padding(.horizontal)
            .background(backgroundGradient)
        }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        .alert("Profile Updated!", isPresented: $showProfileSavedAlert) {
            Button("OK") {
                dismiss()
            }
            } message: {
            Text("Your profile has been updated successfully.")
            }
        .sheet(isPresented: $showImagePicker) {
            LegacyImagePicker(image: $profileImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showInstagramSheet) {
            InstagramOAuthView(
                onSuccess: { handle, profileURL in
                    instagramConnected = true
                    instagramHandle = handle
                    showInstagramSheet = false
                },
                onManual: {
                    instagramConnected = true
                    instagramHandle = ""
                    showInstagramSheet = false
                                    }
            )
        }
        .onChange(of: profileImage) { newImage in
            if let image = newImage {
                uploadProfileImage(image)
            }
        }
        .onAppear {
            loadExistingData()
            checkAuthState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidLogin"))) { _ in
            checkAuthState()
        }
    }

    private func checkAuthState() {
        // Wait a bit for auth state to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let user = Auth.auth().currentUser {
                self.authCheckCompleted = true
                print("✅ Auth state confirmed - user is signed in: \(user.uid)")
            } else {
                print("❌ Auth state check - no user found, retrying...")
                // Retry after additional delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let user = Auth.auth().currentUser {
                        self.authCheckCompleted = true
                        print("✅ Auth state confirmed on retry - user is signed in: \(user.uid)")
                    } else {
                        // Final retry after 2 more seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if let user = Auth.auth().currentUser {
                                self.authCheckCompleted = true
                                print("✅ Auth state confirmed on final retry - user is signed in: \(user.uid)")
                            } else {
                                print("❌ Auth state check failed after all retries")
                                self.errorMessage = "Authentication session expired. Please sign in again."
                                self.showError = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadExistingData() {
        guard isInitialLoad else { return }
        isInitialLoad = false
        
        // Load existing user data if available
        if let user = authViewModel.currentUser {
            username = user.username ?? ""
            let userGender = user.gender ?? ""
            
            // Handle custom gender: if it's not "male" or "female", treat as custom
            if userGender == "male" || userGender == "female" {
                selectedGender = userGender
                customGender = ""
            } else if !userGender.isEmpty {
                selectedGender = "custom"
                customGender = userGender
            }
            
            bio = user.bio ?? ""
            profileImageURL = user.avatarURL ?? ""
            dob = user.dob
            instagramHandle = user.instagramHandle ?? ""
            instagramConnected = !instagramHandle.isEmpty
            snapchatConnected = user.snapchatHandle?.isEmpty == false
        }
    }

    private func uploadProfileImage(_ image: UIImage) {
        isUploadingImage = true
        
        authViewModel.uploadProfileImage(image) { result in
            DispatchQueue.main.async {
                isUploadingImage = false
                
                switch result {
                case .success(let url):
                    profileImageURL = url
                    // Profile image uploaded successfully
                case .failure(let error):
                    errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    showError = true
                    profileImage = nil
                }
            }
        }
    }

    private func saveProfile() {
        // Wait for auth state to be confirmed before proceeding
        if !authCheckCompleted {
            // If auth check isn't complete, wait and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.saveProfile()
            }
            return
        }
        
        // Check if user is authenticated first
        guard Auth.auth().currentUser != nil else {
            errorMessage = "Authentication required. Please sign in again."
            showError = true
            return
        }
        
        isSaving = true
        
        // Prepare data for update
        let city = locationManager.currentCity ?? "Location Not Available"
        let instagram = instagramConnected ? instagramHandle : ""
        let snapchat = snapchatConnected ? "connected" : ""
        
        // Determine final gender value: use custom text if "custom" is selected, otherwise use selected gender
        let finalGender: String?
        if selectedGender == "custom" {
            finalGender = customGender.isEmpty ? nil : customGender
        } else {
            finalGender = selectedGender.isEmpty ? nil : selectedGender
        }
        
        // Use AuthViewModel's updateProfile method
        authViewModel.updateProfile(
            username: username,
            gender: finalGender,
            bio: bio.isEmpty ? nil : bio,
            instagramHandle: instagram,
            snapchatHandle: snapchat,
            avatarURL: profileImageURL.isEmpty ? nil : profileImageURL,
            city: city,
            dob: dob
        ) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success:
                    // Persist completion locally for fast subsequent sign-ins
                    if let uid = Auth.auth().currentUser?.uid {
                        UserDefaults.standard.set(true, forKey: "profileCompleted_\(uid)")
                    }
                    // Always notify completion so Splash can advance
                    NotificationCenter.default.post(name: NSNotification.Name("UserProfileCompleted"), object: nil)
                    if self.isEditingMode {
                        self.showProfileSavedAlert = true
                    } else {
                        self.dismiss()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
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

