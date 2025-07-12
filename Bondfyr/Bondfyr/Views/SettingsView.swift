import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @AppStorage("eventReminders") private var eventReminders = true
    @AppStorage("partyUpdates") private var partyUpdates = true
    
    @State private var showDeleteAccountAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showHelpFAQ = false
    @State private var showingNotificationTest = false
    @State private var showingNotificationStatus = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Location & Permissions section  
                        SettingsSection(title: "Required Permissions") {
                            SettingsLinkRow(title: "Location Access", icon: "location.fill") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.pink)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Location access is required for Bondfyr to function properly.")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("Without location, you won't be able to discover parties near you or create events.")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        
                        // Notifications section
                        SettingsSection(title: "Notifications") {
                            SettingsToggleRow(
                                title: "Event Reminders",
                                icon: "calendar.badge.clock",
                                isOn: $eventReminders
                            )
                            .overlay(
                                VStack {
                                    Spacer()
                                    Text("Get notified before events you're attending")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                        .padding(.bottom, 4)
                                }
                            )
                            
                            SettingsToggleRow(
                                title: "Party Updates",
                                icon: "bell.fill",
                                isOn: $partyUpdates
                            )
                            .overlay(
                                VStack {
                                    Spacer()
                                    Text("Receive updates about parties you've joined")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                        .padding(.bottom, 4)
                                }
                            )
                        }
                        
                        // Notification Settings Section
                        Section("🔔 Notifications") {
                            Toggle("Event Reminders", isOn: $eventReminders)
                                .onChange(of: eventReminders) { value in
                                    UserDefaults.standard.set(value, forKey: "eventReminders")
                                    print("🔔 SETTINGS: Event reminders \(value ? "enabled" : "disabled")")
                                }
                            
                            Toggle("Party Updates", isOn: $partyUpdates)
                                .onChange(of: partyUpdates) { value in
                                    UserDefaults.standard.set(value, forKey: "partyUpdates")
                                    print("🔔 SETTINGS: Party updates \(value ? "enabled" : "disabled")")
                                }
                            
                            // Test Notifications Button
                            Button(action: {
                                print("🧪 TESTING: User requested notification test")
                                NotificationManager.shared.testAllNotifications()
                                showingNotificationTest = true
                            }) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                        .foregroundColor(.blue)
                                    Text("Test Notifications")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text("Tap to test")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Notification Status Info
                            Button(action: {
                                NotificationManager.shared.checkNotificationStatus()
                                showingNotificationStatus = true
                            }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.orange)
                                    Text("Check Notification Status")
                                        .foregroundColor(.orange)
                                }
                            }
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
                                // Open email to developer
                                if let url = URL(string: "mailto:karjunvarma2001@gmail.com?subject=Bondfyr%20Support%20Request") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            
                            SettingsLinkRow(title: "Emergency Contact", icon: "phone.fill") {
                                // Call developer for urgent issues
                                if let url = URL(string: "tel://+919403783265") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            
                            SettingsLinkRow(title: "Follow on X/Twitter", icon: "message.fill") {
                                // Open Twitter profile
                                let twitterAppURL = URL(string: "twitter://user?screen_name=Arjun06061")
                                let twitterWebURL = URL(string: "https://x.com/Arjun06061")
                                
                                if let appURL = twitterAppURL, UIApplication.shared.canOpenURL(appURL) {
                                    UIApplication.shared.open(appURL)
                                } else if let webURL = twitterWebURL {
                                    UIApplication.shared.open(webURL)
                                }
                            }
                            
                            SettingsLinkRow(title: "Help & FAQ", icon: "questionmark.circle.fill") {
                                showHelpFAQ = true
                            }
                        }
                        
                        // Account actions - Only Delete Account now (removed Logout button)
                        VStack(spacing: 16) {
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
                        VStack(spacing: 8) {
                            Text("Bondfyr")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("Designed for the ultimate party experience")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                
                            EasterEggText()
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
            .sheet(isPresented: $showHelpFAQ) {
                HelpFAQView()
            }
            .alert("Notification Test", isPresented: $showingNotificationTest) {
                Button("OK") { }
            } message: {
                Text("Test notifications have been scheduled! You should receive 4 test notifications over the next 8 seconds to verify the system is working.")
            }
            .alert("Notification Status", isPresented: $showingNotificationStatus) {
                Button("Settings", action: openNotificationSettings)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Check the console output for detailed notification status. If notifications aren't working, enable them in Settings.")
            }
        }
    }
    
    private func deleteUserAccount() {
        // First, dismiss the current view
        self.presentationMode.wrappedValue.dismiss()
        
        // Use the improved delete account method
        authViewModel.deleteAccount { error in
            // Silent error handling for production
        }
    }

    // MARK: - Helper Methods
    
    private func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Debug Notification Section

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
                    
                    Text("At Bondfyr, we take your privacy seriously. This Privacy Policy explains how we collect, use, and protect your information when you use our mobile application.")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Updated policy sections
                    Group {
                        PolicySection(title: "Information We Collect", content: "We collect information that you provide directly to us when you create an account or use our features. This includes your name, email address, location data, and profile information. We also collect usage data to improve our services.")
                        
                        PolicySection(title: "How We Use Your Information", content: "We use your information solely to provide and improve our services, connect you with local events, ensure user safety, and communicate important updates. We do not sell, rent, or trade your personal information.")
                        
                        PolicySection(title: "Information Sharing", content: "We only share your information when necessary to provide our services (such as showing your profile to event hosts) or as required by law. We never sell your data to third parties for marketing purposes.")
                        
                        PolicySection(title: "Data Security", content: "We implement industry-standard security measures to protect your personal information. Your data is stored securely and access is limited to authorized personnel only.")
                        
                        PolicySection(title: "Your Rights", content: "You have the right to access, correct, or delete your personal information at any time through the app settings. You can also contact us directly for data-related requests.")
                        
                        PolicySection(title: "Location Data", content: "Location access is essential for finding nearby events and connecting with your local party community. You can disable location services in your device settings, though this may limit app functionality.")
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
                    
                    // Updated terms sections
                    Group {
                        PolicySection(title: "Acceptance of Terms", content: "By accessing or using our services, you agree to be bound by these Terms and our Privacy Policy.")
                        
                        PolicySection(title: "User Accounts", content: "You are responsible for safeguarding your account and for all activities that occur under your account. You must provide accurate information when creating your account.")
                        
                        PolicySection(title: "Event Discovery", content: "Bondfyr helps you discover and connect with local events. All event information is provided by hosts and we strive to ensure accuracy, but cannot guarantee all details.")
                        
                        PolicySection(title: "Code of Conduct", content: "Users must behave respectfully when using our platform and attending events. Harassment, discrimination, or illegal activities are strictly prohibited.")
                        
                        PolicySection(title: "Safety", content: "While we implement safety features, users are responsible for their own safety when attending events. Always meet in public places and trust your instincts.")
                        
                        PolicySection(title: "Content", content: "Users are responsible for all content they post. We reserve the right to remove content that violates our community standards.")
                        
                        PolicySection(title: "Service Availability", content: "We strive to maintain service availability but cannot guarantee uninterrupted access. We may modify or discontinue features with notice.")
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

struct EasterEggText: View {
    @State private var tapCount = 0
    @State private var showSecretText = false
    
    var body: some View {
        Button(action: {
            tapCount += 1
            if tapCount >= 5 && !showSecretText {
                withAnimation(.spring()) {
                    showSecretText = true
                }
            }
        }) {
            Text(showSecretText ? "AA😋" : "Made on Earth c-137 👽")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help & FAQ View

struct HelpFAQView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var expandedFAQ: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Quick Support Actions
                        quickSupportSection
                        
                        // Contact Information
                        contactSection
                        
                        // FAQ Section
                        faqSection
                        
                        // Developer Info
                        developerSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            
            Text("Need Help?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("We're here to help you have the best party experience!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    private var quickSupportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Support")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                QuickSupportButton(
                    icon: "envelope.fill",
                    title: "Email Support",
                    subtitle: "Get help via email",
                    action: emailSupport
                )
                
                QuickSupportButton(
                    icon: "phone.fill",
                    title: "Emergency Call",
                    subtitle: "For urgent safety issues",
                    action: callSupport
                )
                
                QuickSupportButton(
                    icon: "message.fill",
                    title: "Follow on X",
                    subtitle: "Get updates and support",
                    action: openTwitter
                )
            }
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ContactRow(icon: "envelope.fill", label: "Email", value: "karjunvarma2001@gmail.com")
                ContactRow(icon: "phone.fill", label: "Phone", value: "+91 9403783265")
                ContactRow(icon: "globe", label: "X/Twitter", value: "@Arjun06061")
            }
        }
    }
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Frequently Asked Questions")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                FAQRow(
                    id: "create-party",
                    question: "How do I create a party?",
                    answer: "1. Tap 'Host Party' in the bottom tab\n2. Fill in your party details, location, and price\n3. Set your vibe tags and guest limit\n4. Accept legal responsibility\n5. Your party goes live immediately!",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "join-party",
                    question: "How do I join a party?",
                    answer: "1. Browse parties on the main feed\n2. Tap 'Request to Join' on a party you like\n3. Write a brief intro message\n4. Wait for host approval\n5. Once approved, you'll get the party details!",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "verification",
                    question: "How do I get verified?",
                    answer: "• Host Verification: Successfully host 4 parties\n• Guest Verification: Attend 8 parties\n• Verified users get special badges and priority in the app",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "location",
                    question: "Why does the app need location access?",
                    answer: "Location access is essential for Bondfyr to work:\n• Find parties near you\n• Show distance to events\n• Allow hosts to create location-based parties\n• Connect you with your local party community",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "safety",
                    question: "How is safety ensured?",
                    answer: "• All users go through verification\n• Rating system for hosts and guests\n• 24/7 emergency support available\n• Report system for inappropriate behavior\n• Location-based safety features",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "host-approval",
                    question: "How does the approval process work?",
                    answer: "• Hosts can set manual or automatic approval\n• Manual: Host reviews each request individually\n• Automatic: First-come-first-serve with optional gender ratios\n• You'll get notified when your request is approved or denied",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "community",
                    question: "How do I build my reputation?",
                    answer: "• Attend parties and get positive ratings\n• Host successful events with good reviews\n• Be respectful and follow community guidelines\n• Verified users get special badges and benefits",
                    expandedFAQ: $expandedFAQ
                )
            }
        }
    }
    
    private var developerSection: some View {
        VStack(spacing: 12) {
            Text("Built by Arjun")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Bondfyr v1.0.0")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Making party connections easier, one event at a time 🎉")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Actions
    
    private func emailSupport() {
        if let url = URL(string: "mailto:karjunvarma2001@gmail.com?subject=Bondfyr%20Support%20Request&body=Hi%20Arjun,%0A%0AI%20need%20help%20with:%0A%0A") {
            UIApplication.shared.open(url)
        }
    }
    
    private func callSupport() {
        if let url = URL(string: "tel://+919403783265") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTwitter() {
        let twitterAppURL = URL(string: "twitter://user?screen_name=Arjun06061")
        let twitterWebURL = URL(string: "https://x.com/Arjun06061")
        
        if let appURL = twitterAppURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = twitterWebURL {
            UIApplication.shared.open(webURL)
        }
    }
    
    // MARK: - Debug Notification Section
    
}

// MARK: - Supporting Views for Help & FAQ

struct QuickSupportButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.pink)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
}

struct ContactRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.pink)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundColor(.white)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}

struct FAQRow: View {
    let id: String
    let question: String
    let answer: String
    @Binding var expandedFAQ: String?
    
    private var isExpanded: Bool {
        expandedFAQ == id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    expandedFAQ = isExpanded ? nil : id
                }
            }) {
                HStack {
                    Text(question)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}

// MARK: - Debug Notification Section

 
