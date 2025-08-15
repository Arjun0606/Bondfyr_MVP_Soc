import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @AppStorage("eventReminders") private var eventReminders = true
    @AppStorage("partyUpdates") private var partyUpdates = true
    
    @State private var showDeleteAccountAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showContentGuidelines = false
    @State private var showHelpFAQ = false
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
                        }
                        
                        // Legal & Privacy section
                        SettingsSection(title: "Legal & Privacy") {
                            SettingsLinkRow(title: "Privacy Policy", icon: "lock.shield.fill") {
                                showPrivacyPolicy = true
                            }
                            
                            SettingsLinkRow(title: "Terms of Service", icon: "doc.text.fill") {
                                showTermsOfService = true
                            }
                            
                            SettingsLinkRow(title: "Community Guidelines", icon: "shield.checkerboard") {
                                showContentGuidelines = true
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Keep Bondfyr safe for everyone")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("Report inappropriate content or behavior to help maintain a positive community.")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
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
                WebLegalView(title: "Privacy Policy", url: "https://bondfyr-da123.web.app/privacy-policy.html")
            }
            .sheet(isPresented: $showTermsOfService) {
                WebLegalView(title: "Terms of Service", url: "https://bondfyr-da123.web.app/terms-of-service.html")
            }
            .sheet(isPresented: $showContentGuidelines) {
                ContentGuidelinesView()
            }
            .sheet(isPresented: $showHelpFAQ) {
                HelpFAQView()
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



struct WebLegalView: View {
    let title: String
    let url: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.pink)
                    
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("For the most up-to-date version, please visit our website.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("Open in Browser") {
                        if let webURL = URL(string: url) {
                            UIApplication.shared.open(webURL)
                        }
                    }
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(
                trailing: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.pink)
            )
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
                    answer: "1. Tap the '+' button to create a party\n2. Fill in your party details, location, and price\n3. Pay the listing fee on our Host Web portal\n4. Your party goes live after payment!\n5. Guests pay you directly via Venmo/PayPal/Cash App",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "join-party",
                    question: "How do I join a party?",
                    answer: "1. Browse parties on the main feed\n2. Tap on a party card to see details\n3. Tap 'Request to Join'\n4. Wait for host approval\n5. Pay the host directly via their preferred method",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "payments",
                    question: "How do payments work?",
                    answer: "• Hosts pay listing fees to publish parties\n• Guests pay hosts directly (Venmo, PayPal, Cash App, Apple Pay)\n• Bondfyr doesn't handle guest-to-host payments\n• Listing fees are dynamic based on party size and price",
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
                    answer: "• Age verification (18+ only)\n• Report system for inappropriate content\n• Community guidelines enforcement\n• User reputation system\n• Report button on all party cards (flag icon)",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "reporting",
                    question: "How do I report inappropriate content?",
                    answer: "• Tap the flag icon on any party card\n• Choose report reason (inappropriate content, safety concern, fake/spam)\n• Reports are reviewed promptly\n• Help keep the community safe for everyone",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "contact",
                    question: "How do I get help or report issues?",
                    answer: "• Contact support via Settings → Help & Support\n• Send feedback or report bugs directly from the app\n• Email us at karjunvarma2001@gmail.com\n• Check community guidelines for content policies",
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

 
