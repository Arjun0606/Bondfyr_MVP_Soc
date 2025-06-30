import SwiftUI
import MessageUI

struct HelpSupportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showingMailComposer = false
    @State private var showingFeedbackForm = false
    @State private var showingBugReport = false
    @State private var canSendMail = MFMailComposeViewController.canSendMail()
    @State private var showingMailAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Contact Information
                        contactInformationSection
                        
                        // FAQs
                        faqSection
                        
                        // Social Media
                        socialMediaSection
                        
                        // App Information
                        appInfoSection
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
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(
                subject: "Bondfyr Support Request",
                recipients: ["karjunvarma2001@gmail.com"],
                messageBody: "Hi Arjun,\n\nI need help with the following issue:\n\n"
            )
        }
        .sheet(isPresented: $showingFeedbackForm) {
            FeedbackFormView()
        }
        .sheet(isPresented: $showingBugReport) {
            BugReportView()
        }
        .alert("Mail Not Available", isPresented: $showingMailAlert) {
            Button("Copy Email", action: copyEmailToClipboard)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Mail is not configured on this device. Would you like to copy the support email to your clipboard?")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            
            Text("How can we help you?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("We're here to make your Bondfyr experience amazing!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                SupportActionButton(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    subtitle: "Get help from our team",
                    action: contactSupport
                )
                
                SupportActionButton(
                    icon: "megaphone.fill",
                    title: "Send Feedback",
                    subtitle: "Help us improve the app",
                    action: { showingFeedbackForm = true }
                )
                
                SupportActionButton(
                    icon: "ant.fill",
                    title: "Report a Bug",
                    subtitle: "Found something broken?",
                    action: { showingBugReport = true }
                )
                
                SupportActionButton(
                    icon: "phone.fill",
                    title: "Emergency Contact",
                    subtitle: "For urgent safety issues",
                    action: callEmergencySupport
                )
            }
        }
    }
    
    private var contactInformationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ContactInfoRow(
                    icon: "envelope.fill",
                    title: "Email Support",
                    subtitle: "karjunvarma2001@gmail.com",
                    action: contactSupport
                )
                
                ContactInfoRow(
                    icon: "phone.fill",
                    title: "Phone Support",
                    subtitle: "+91 9403783265",
                    action: callEmergencySupport
                )
                
                ContactInfoRow(
                    icon: "globe",
                    title: "Follow Us",
                    subtitle: "@https://x.com/Arjun06061",
                    action: openTwitter
                )
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
                FAQItem(
                    question: "How do I create a party?",
                    answer: "Tap the 'Host Party' tab at the bottom, set your details, price, and location. Your party will be live immediately!"
                )
                
                FAQItem(
                    question: "How do refunds work?",
                    answer: "If a party is cancelled by the host, all guests receive automatic refunds within 3-5 business days."
                )
                
                FAQItem(
                    question: "How is my safety ensured?",
                    answer: "All hosts and guests are verified through our reputation system. We also have 24/7 emergency support."
                )
                
                FAQItem(
                    question: "What fees does Bondfyr charge?",
                    answer: "Bondfyr takes a 12% fee from each ticket sale. Hosts keep 88% of their ticket revenue."
                )
                
                FAQItem(
                    question: "How do I get verified?",
                    answer: "Host 4 successful parties for Host verification, or attend 8 parties for Guest verification."
                )
            }
        }
    }
    
    private var socialMediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect With Us")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                SocialMediaButton(
                    icon: "message.fill",
                    platform: "Twitter/X",
                    handle: "@Arjun06061",
                    action: openTwitter
                )
                
                Spacer()
            }
        }
    }
    
    private var appInfoSection: some View {
        VStack(spacing: 12) {
            Text("Bondfyr v1.0.0")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Built with ❤️ for the party community")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("© 2025 Bondfyr. All rights reserved.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Actions
    
    private func contactSupport() {
        if canSendMail {
            showingMailComposer = true
        } else {
            showingMailAlert = true
        }
    }
    
    private func callEmergencySupport() {
        guard let phoneURL = URL(string: "tel://+919403783265") else { return }
        if UIApplication.shared.canOpenURL(phoneURL) {
            UIApplication.shared.open(phoneURL)
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
    
    private func copyEmailToClipboard() {
        UIPasteboard.general.string = "karjunvarma2001@gmail.com"
    }
}

// MARK: - Supporting Views

struct SupportActionButton: View {
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
                    .frame(width: 32, height: 32)
                
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

struct ContactInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.pink)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
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
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}

struct SocialMediaButton: View {
    let icon: String
    let platform: String
    let handle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.pink)
                
                Text(platform)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(handle)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let recipients: [String]
    let messageBody: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setSubject(subject)
        mailComposer.setToRecipients(recipients)
        mailComposer.setMessageBody(messageBody, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Feedback Form

struct FeedbackFormView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var feedbackText = ""
    @State private var rating = 5
    @State private var feedbackCategory = "General"
    
    let categories = ["General", "Bug Report", "Feature Request", "Party Experience", "Safety Concern"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Rating
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Rate your experience")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: { rating = star }) {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .foregroundColor(.pink)
                                            .font(.title2)
                                    }
                                }
                                Spacer()
                            }
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Feedback Category")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Picker("Category", selection: $feedbackCategory) {
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .accentColor(.pink)
                        }
                        
                        // Feedback text
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your feedback")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $feedbackText)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        
                        // Submit button
                        Button(action: submitFeedback) {
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(feedbackText.isEmpty ? Color.gray : Color.pink)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(feedbackText.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
    
    private func submitFeedback() {
        // Here you would typically send the feedback to your backend
        print("Feedback submitted: \(feedbackText)")
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Bug Report

struct BugReportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var bugDescription = ""
    @State private var stepsToReproduce = ""
    @State private var deviceInfo = UIDevice.current.model
    @State private var iosVersion = UIDevice.current.systemVersion
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Bug description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Describe the bug")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $bugDescription)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        
                        // Steps to reproduce
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Steps to reproduce")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $stepsToReproduce)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        
                        // Device info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Device Information")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Device: \(deviceInfo)")
                                    .foregroundColor(.gray)
                                Text("iOS Version: \(iosVersion)")
                                    .foregroundColor(.gray)
                                Text("App Version: 1.0.0")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                        
                        // Submit button
                        Button(action: submitBugReport) {
                            Text("Submit Bug Report")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(bugDescription.isEmpty ? Color.gray : Color.pink)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(bugDescription.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Report Bug")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
    
    private func submitBugReport() {
        // Here you would typically send the bug report to your backend
        print("Bug report submitted: \(bugDescription)")
        presentationMode.wrappedValue.dismiss()
    }
} 