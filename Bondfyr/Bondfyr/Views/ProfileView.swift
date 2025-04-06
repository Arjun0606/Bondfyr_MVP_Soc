//
//  ProfileView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showDeleteAlert = false
    @State private var showReauthAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = "An error occurred"
    @State private var navigateToLogin = false
    
    // Mock event history – replace with Firestore data later
    let attendedEvents = [
        ("Qora", "March 10, 2025"),
        ("High Spirits", "Feb 24, 2025"),
        ("Vault", "Jan 15, 2025")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Icon + Name
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.pink)
                        .shadow(radius: 8)

                    Text(authViewModel.currentUser?.name ?? "Guest")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // Profile Details
                VStack(alignment: .leading, spacing: 10) {
                    ProfileField(title: "Email", value: authViewModel.currentUser?.email ?? "-")
                    ProfileField(title: "Date of Birth", value: formatDate(authViewModel.currentUser?.dob))
                    ProfileField(title: "Phone Number", value: authViewModel.currentUser?.phoneNumber ?? "-")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                // Event History
                VStack(alignment: .leading, spacing: 10) {
                    Text("Event History")
                        .font(.headline)
                        .foregroundColor(.white)

                    ForEach(attendedEvents, id: \.0) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.0)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text(event.1)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
                .padding(.top)

                // Logout Button
                Button(action: {
                    authViewModel.logout()
                    resetToSplashScreen()
                }) {
                    Text("Logout")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                // Delete Account Button
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Text("Delete Account")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("Delete Account"),
                        message: Text("This will permanently delete your account and cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteAccount()
                        },
                        secondaryButton: .cancel()
                    )
                }

                Spacer()
            }
            .padding()
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

struct ProfileField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.white)
        }
    }
}
