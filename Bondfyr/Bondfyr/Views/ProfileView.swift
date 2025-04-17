//
//  ProfileView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Define the EventHistory struct that was missing
struct EventHistory: Identifiable {
    let id = UUID()
    let venue: String
    let date: String
    let imageName: String
    var ticketCount: Int = 1 // Added ticket count
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showErrorAlert = false
    @State private var errorMessage = "An error occurred"
    @State private var navigateToLogin = false
    
    // Mock event history with ticket counts
    let attendedEvents = [
        EventHistory(venue: "Qora", date: "March 10, 2025", imageName: "event1", ticketCount: 3),
        EventHistory(venue: "High Spirits", date: "Feb 24, 2025", imageName: "event2", ticketCount: 1),
        EventHistory(venue: "Vault", date: "Jan 15, 2025", imageName: "event3", ticketCount: 2)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile header
                        VStack(spacing: 16) {
                            // Profile image
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [.pink, .purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 100, height: 100)
                                
                                Text(getInitials(from: authViewModel.currentUser?.name ?? "Guest"))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(radius: 8)
                            
                            // Name and username
                            VStack(spacing: 4) {
                                Text(authViewModel.currentUser?.name ?? "Guest")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(authViewModel.currentUser?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // Edit profile button
                            Button(action: {
                                showEditProfile = true
                            }) {
                                Text("Edit Profile")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.pink)
                                    .cornerRadius(25)
                            }
                        }
                        .padding(.top, 16)
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.horizontal)
                        
                        // Event History
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Event History")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            if attendedEvents.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "ticket.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.6))
                                    
                                    Text("No event history yet")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                    
                                    Text("Your attended events will show up here")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(attendedEvents) { event in
                                        EventHistoryRowWithTickets(event: event)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Settings button
                        Button(action: {
                            showSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Settings")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitle("Profile", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white)
            })
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(isPresented: $showEditProfile)
                    .environmentObject(authViewModel)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onDisappear {
            // Check if we need to navigate to login
            if navigateToLogin {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let windowScene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                       let window = windowScene.windows.first {
                        
                        // Clear user defaults if needed
                        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
                        
                        // Reset to login view
                        window.rootViewController = UIHostingController(
                            rootView: GoogleSignInView()
                                .environmentObject(AuthViewModel())
                                .environmentObject(TabSelection())
                        )
                        window.makeKeyAndVisible()
                    }
                }
            }
        }
    }
    
    // Get initials from name
    private func getInitials(from name: String) -> String {
        let nameComponents = name.components(separatedBy: " ")
        let firstInitial = nameComponents.first?.first?.uppercased() ?? ""
        let lastInitial = nameComponents.count > 1 ? String(nameComponents.last?.first ?? Character("")) : ""
        return "\(firstInitial)\(lastInitial)"
    }

    func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        
        // First delete user data from Firestore
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).delete { error in
            if let error = error {
                self.errorMessage = "Failed to delete user data: \(error.localizedDescription)"
                self.showErrorAlert = true
                return
            }
            
            // Then delete the account
            user.delete { error in
                if let error = error {
                    print("❌ Failed to delete account: \(error.localizedDescription)")
                    
                    // Check for authentication error - might need to reauthenticate
                    if let authError = error as? AuthErrorCode, 
                       authError.code == .requiresRecentLogin {
                        // We set a flag to navigate to login after view disappears
                        self.errorMessage = "For security reasons, you need to log in again before deleting your account"
                        self.showErrorAlert = true
                        
                        // First logout the user
                        self.authViewModel.logout()
                        self.resetToSplashScreen()
                    } else {
                        self.errorMessage = "Failed to delete account: \(error.localizedDescription)"
                        self.showErrorAlert = true
                    }
                } else {
                    print("✅ Account deleted successfully.")
                    self.authViewModel.logout()
                    self.resetToSplashScreen()
                }
            }
        }
    }
    
    // Helper function to reset to splash screen
    func resetToSplashScreen() {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first {
            
            // Reset to splash view
            window.rootViewController = UIHostingController(
                rootView: SplashView()
                    .environmentObject(AuthViewModel())
                    .environmentObject(TabSelection())
            )
            window.makeKeyAndVisible()
        }
    }
}

// Event history row with ticket count
struct EventHistoryRowWithTickets: View {
    let event: EventHistory
    
    var body: some View {
        HStack(spacing: 16) {
            // Event image (using a placeholder since we don't have actual images)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.pink.opacity(0.5), .purple.opacity(0.5)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.venue)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(event.date)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Ticket count
                HStack(spacing: 4) {
                    Image(systemName: "ticket.fill")
                        .font(.caption)
                        .foregroundColor(.pink)
                    
                    Text("\(event.ticketCount) \(event.ticketCount == 1 ? "ticket" : "tickets") booked")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile picture
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.pink, .purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                            
                            if let name = authViewModel.currentUser?.name {
                                Text(getInitials(from: name))
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("?")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            // Edit overlay
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .fill(Color.pink)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 35, y: 35)
                                )
                        }
                        .padding(.top, 20)
                        
                        // Form fields
                        VStack(spacing: 20) {
                            // Name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                                
                                TextField("", text: $name)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Email field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                                
                                TextField("", text: $email)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disabled(true) // Email can't be changed after account creation
                                    .opacity(0.7)
                            }
                            
                            // Phone field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                                
                                TextField("", text: $phone)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .keyboardType(.phonePad)
                            }
                            
                            Spacer(minLength: 30)
                            
                            // Save button
                            Button(action: {
                                saveProfile()
                            }) {
                                ZStack {
                                    Text("Save Changes")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.pink)
                                        .cornerRadius(10)
                                        .opacity(isLoading ? 0 : 1)
                                    
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    }
                                }
                            }
                            .disabled(isLoading || name.isEmpty || phone.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                }
                .onAppear(perform: loadUserData)
            }
            .navigationBarTitle("Edit Profile", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .foregroundColor(.blue)
                }
            )
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text("Profile Updated"),
                    message: Text("Your profile has been successfully updated."),
                    dismissButton: .default(Text("OK")) {
                        isPresented = false
                    }
                )
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func loadUserData() {
        if let user = authViewModel.currentUser {
            name = user.name
            email = user.email
            phone = user.phoneNumber ?? ""
        }
    }
    
    private func saveProfile() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Name cannot be empty"
            showErrorAlert = true
            return
        }
        
        guard !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Phone number cannot be empty"
            showErrorAlert = true
            return
        }
        
        isLoading = true
        
        // In a real implementation, this would update the Firestore database
        // For this mock, we'll simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Update the Auth ViewModel by creating a new user instance
            if let currentUser = authViewModel.currentUser {
                // Create updated user data
                let updatedUser = AppUser(
                    uid: currentUser.uid,
                    name: self.name,
                    email: currentUser.email,
                    dob: currentUser.dob,
                    phoneNumber: self.phone
                )
                
                // Update the Auth ViewModel with the new user
                authViewModel.updateCurrentUser(updatedUser)
                
                // In a real implementation, update would be persisted to Firestore here
                showSuccessAlert = true
            } else {
                errorMessage = "Failed to update profile: User not found"
                showErrorAlert = true
            }
            
            isLoading = false
        }
    }
    
    // Helper function to get initials from name
    private func getInitials(from name: String) -> String {
        let nameComponents = name.components(separatedBy: " ")
        let firstInitial = nameComponents.first?.first?.uppercased() ?? ""
        let lastInitial = nameComponents.count > 1 ? String(nameComponents.last?.first ?? Character("")) : ""
        return "\(firstInitial)\(lastInitial)"
    }
}
