import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @AppStorage("eventReminders") private var eventReminders = true
    
    @State private var showDeleteAccountAlert = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showHelpFAQ = false
    
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
                            
                            SettingsToggleRow(
                                title: "Party Updates",
                                icon: "bell.fill",
                                isOn: .constant(true)
                            )
                            
                            SettingsToggleRow(
                                title: "Safety Alerts",
                                icon: "shield.fill",
                                isOn: .constant(true)
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
        }
    }
    
    private func deleteUserAccount() {
        print("Deleting user account")
        
        // First, dismiss the current view
        self.presentationMode.wrappedValue.dismiss()
        
        // Use the improved delete account method
        authViewModel.deleteAccount { error in
            if let error = error {
                print("❌ Error deleting account: \(error.localizedDescription)")
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
            Text(showSecretText ? "🐯TG🍻RK☀️" : "Made on Earth c-137 👽")
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
                    id: "pricing",
                    question: "How does pricing work?",
                    answer: "You set your ticket price (minimum $5). Bondfyr takes a 12% platform fee, so you keep 88% of each ticket sale. There's no maximum price limit - charge what your party is worth!",
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
                    id: "refunds",
                    question: "What's the refund policy?",
                    answer: "• Host cancellations: Full automatic refund within 3-5 days\n• Guest cancellations: No refunds (tickets are final sale)\n• Safety issues: Case-by-case review",
                    expandedFAQ: $expandedFAQ
                )
                
                FAQRow(
                    id: "payment",
                    question: "How do payments work?",
                    answer: "• Guests pay when requesting to join\n• Hosts receive payouts after successful parties\n• All payments processed securely through Stripe\n• Hosts get paid within 2-3 business days",
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
