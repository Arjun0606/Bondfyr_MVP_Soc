import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = true
    @AppStorage("eventReminders") private var eventReminders = true
    
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Account section
                        SettingsSection(title: "Account") {
                            SettingsLinkRow(title: "Payment Methods", icon: "creditcard.fill") {
                                // Navigate to payment methods
                            }
                        }
                        
                        // Notifications section
                        SettingsSection(title: "Notifications") {
                            SettingsToggleRow(
                                title: "Event Reminders",
                                icon: "calendar.badge.clock",
                                isOn: $eventReminders
                            )
                        }
                        
                        // Privacy section
                        SettingsSection(title: "Privacy") {
                            SettingsLinkRow(title: "Privacy Policy", icon: "lock.shield.fill") {
                                showPrivacyPolicy = true
                            }
                            
                            SettingsLinkRow(title: "Terms of Service", icon: "doc.text.fill") {
                                showTermsOfService = true
                            }
                        }
                        
                        // Support section
                        SettingsSection(title: "Support") {
                            SettingsLinkRow(title: "Contact Support", icon: "envelope.fill") {
                                // Open email
                                if let url = URL(string: "mailto:support@bondfyr.com") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        
                        // Account actions
                        VStack(spacing: 16) {
                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                Text("Logout")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.pink)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showDeleteAccountAlert = true
                            }) {
                                Text("Delete Account")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.top, 16)
                        
                        // App info
                        VStack(spacing: 4) {
                            Text("Bondfyr")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.gray)
                                
                            Text("Made on Earth c-137 👽")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                Text("Back")
                    .foregroundColor(.white)
            })
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("Logout"),
                    message: Text("Are you sure you want to log out?"),
                    primaryButton: .destructive(Text("Logout")) {
                        // Execute a clean logout process
                        performCleanLogout()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showDeleteAccountAlert) {
                Alert(
                    title: Text("Delete Account"),
                    message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteUserAccount()
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
        }
    }
    
    // Helper methods for clean logout and account deletion
    private func performCleanLogout() {
        print("Performing clean logout")
        
        // First, get a reference to the current auth user ID before logout
        let _ = Auth.auth().currentUser?.uid
        
        // Force reset the auth state immediately to make sign-out more aggressive
        DispatchQueue.main.async {
            self.authViewModel.currentUser = nil
            self.authViewModel.isLoggedIn = false
        }
        
        // Dismiss the current view first
        self.presentationMode.wrappedValue.dismiss()
        
        // Give time for the settings view to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Then notify the app about logout - this should trigger SplashView navigation
            NotificationCenter.default.post(
                name: NSNotification.Name("UserDidLogout"),
                object: nil
            )
            
            // Force dismiss any presented view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.dismiss(animated: true)
            }
            
            // After a small delay, perform the actual logout
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Try to forcibly sign out the user
                do {
                    try Auth.auth().signOut()
                } catch {
                    print("Error signing out: \(error)")
                }
                
                // Finally, call the view model logout to clear all state
                self.authViewModel.logout()
            }
        }
    }
    
    private func deleteUserAccount() {
        print("Deleting user account")
        
        // Dismiss the current view first
        self.presentationMode.wrappedValue.dismiss()
        
        // Give time for the settings view to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Notify about logout
            NotificationCenter.default.post(
                name: NSNotification.Name("UserDidLogout"),
                object: nil
            )
            
            // Then perform the deletion after notification has been processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let user = Auth.auth().currentUser {
                    // Get the uid before deleting
                    let uid = user.uid
                    
                    // Delete user data from Firestore first
                    let db = Firestore.firestore()
                    db.collection("users").document(uid).delete { error in
                        if let error = error {
                            print("Error deleting user data: \(error.localizedDescription)")
                        } else {
                            print("User data deleted successfully")
                        }
                        
                        // Then delete the Firebase Auth user
                        user.delete { error in
                            if let error = error {
                                print("Error deleting user: \(error.localizedDescription)")
                                // If we can't delete the user, at least log them out
                                authViewModel.logout()
                            } else {
                                print("User deleted successfully")
                                authViewModel.logout()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            VStack(spacing: 1) {
                content
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

struct SettingsLinkRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.pink)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.pink)
                .frame(width: 24, height: 24)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.pink)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}

struct SettingsInputRow: View {
    let title: String
    let icon: String
    @Binding var value: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.pink)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .foregroundColor(.white)
            }
            
            TextField(placeholder, text: $value)
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.white)
                .padding(.leading, 28)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)
                    
                    Text("Last Updated: April 6, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)
                    
                    Text("At Bondfyr, we take your privacy seriously. This Privacy Policy explains how we collect, use, and share your information when you use our mobile application.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Mock policy sections
                    Group {
                        PolicySection(title: "Information We Collect", content: "We collect information that you provide directly to us, such as when you create an account, purchase tickets, or use our chat features. This may include your name, email address, phone number, and payment information.")
                        
                        PolicySection(title: "How We Use Your Information", content: "We use your information to provide, maintain, and improve our services, process transactions, send notifications, and communicate with you.")
                        
                        PolicySection(title: "Information Sharing", content: "We may share your information with event organizers, service providers, and as required by law.")
                        
                        PolicySection(title: "Your Rights", content: "You have the right to access, correct, or delete your personal information at any time through the app settings.")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("Privacy Policy", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

struct TermsOfServiceView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)
                    
                    Text("Last Updated: April 6, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)
                    
                    Text("By using the Bondfyr app, you agree to these terms, which govern your use of our services.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Mock terms sections
                    Group {
                        PolicySection(title: "Acceptance of Terms", content: "By accessing or using our services, you agree to be bound by these Terms and our Privacy Policy.")
                        
                        PolicySection(title: "User Accounts", content: "You are responsible for safeguarding your account and for all activities that occur under your account.")
                        
                        PolicySection(title: "Ticket Purchases", content: "All ticket sales are final. No refunds or exchanges except as required by law.")
                        
                        PolicySection(title: "Code of Conduct", content: "Users must behave respectfully when using our platform and attending events.")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("Terms of Service", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
} 