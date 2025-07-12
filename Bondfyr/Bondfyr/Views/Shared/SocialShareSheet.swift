import SwiftUI
import UIKit

// MARK: - Social Share Sheet for Quick RSVP Sharing
struct SocialShareSheet: View {
    let party: Afterparty
    @Binding var isPresented: Bool
    
    @State private var showingNativeShare = false
    @State private var customMessage = ""
    
    private var partyLink: String {
        // Generate deep link for the party
        "https://bondfyr.app/party/\(party.id)"
    }
    
    private var defaultMessage: String {
        "🎉 Epic party alert! \(party.title) at \(party.locationName)\n\nParty link in bio → RSVP now on Bondfyr\n\n#Bondfyr #Party #RSVP"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("📲 Share to Social")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Quick RSVP sharing for your followers")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top)
                
                // Party Preview Card
                PartyPreviewCard(party: party)
                
                // Message Editor
                MessageEditorSection(
                    message: $customMessage,
                    defaultMessage: defaultMessage
                )
                
                // Social Platform Buttons
                SocialPlatformButtons(
                    party: party,
                    message: customMessage.isEmpty ? defaultMessage : customMessage,
                    partyLink: partyLink,
                    showingNativeShare: $showingNativeShare
                )
                
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.white),
                trailing: Button("More") {
                    showingNativeShare = true
                }
                .foregroundColor(.pink)
            )
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingNativeShare) {
            ActivityViewController(
                activityItems: [customMessage.isEmpty ? defaultMessage : customMessage, partyLink]
            )
        }
        .onAppear {
            customMessage = defaultMessage
        }
    }
}

// MARK: - Party Preview Card
struct PartyPreviewCard: View {
    let party: Afterparty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("by @\(party.hostHandle)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("$\(Int(party.ticketPrice))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            HStack {
                Label(party.locationName, systemImage: "location.fill")
                Spacer()
                Label("\(party.confirmedGuestsCount)/\(party.maxGuestCount)", systemImage: "person.3.fill")
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Message Editor Section
struct MessageEditorSection: View {
    @Binding var message: String
    let defaultMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("✏️ Customize Message")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Reset") {
                    message = defaultMessage
                }
                .font(.caption)
                .foregroundColor(.pink)
            }
            
            TextEditor(text: $message)
                .frame(minHeight: 100)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .foregroundColor(.white)
            
            Text("\(message.count)/280 characters")
                .font(.caption)
                .foregroundColor(message.count > 280 ? .red : .gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Social Platform Buttons
struct SocialPlatformButtons: View {
    let party: Afterparty
    let message: String
    let partyLink: String
    @Binding var showingNativeShare: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("📱 Share to...")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Instagram Stories
                SocialPlatformButton(
                    title: "Instagram Stories",
                    icon: "camera.fill",
                    color: .purple,
                    gradientColors: [.purple, .pink]
                ) {
                    shareToInstagramStories()
                }
                
                // Snapchat
                SocialPlatformButton(
                    title: "Snapchat",
                    icon: "camera.aperture",
                    color: .yellow,
                    gradientColors: [.yellow, .orange]
                ) {
                    shareToSnapchat()
                }
                
                // Instagram Feed
                SocialPlatformButton(
                    title: "Instagram Feed",
                    icon: "square.and.arrow.up.fill",
                    color: .pink,
                    gradientColors: [.pink, .purple]
                ) {
                    shareToInstagramFeed()
                }
                
                // Copy Link
                SocialPlatformButton(
                    title: "Copy Link",
                    icon: "link",
                    color: .blue,
                    gradientColors: [.blue, .cyan]
                ) {
                    copyToClipboard()
                }
            }
            
            // Native Share (More Options)
            Button(action: { showingNativeShare = true }) {
                HStack {
                    Image(systemName: "ellipsis.circle.fill")
                    Text("More Sharing Options")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Social Platform Actions
    private func shareToInstagramStories() {
        guard let instagramURL = URL(string: "instagram-stories://share") else {
            openInstagramWebFallback()
            return
        }
        
        if UIApplication.shared.canOpenURL(instagramURL) {
            // Create a background image with party details
            let storyContent = createInstagramStoryContent()
            UIPasteboard.general.setData(storyContent, forPasteboardType: "public.jpeg")
            UIApplication.shared.open(instagramURL)
        } else {
            openInstagramWebFallback()
        }
    }
    
    private func shareToSnapchat() {
        let snapchatURL = URL(string: "snapchat://")
        
        if let url = snapchatURL, UIApplication.shared.canOpenURL(url) {
            // Copy message to clipboard for manual paste
            UIPasteboard.general.string = message
            UIApplication.shared.open(url)
            
            // Show helper alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSnapchatHelper()
            }
        } else {
            openSnapchatWebFallback()
        }
    }
    
    private func shareToInstagramFeed() {
        let instagramURL = URL(string: "instagram://app")
        
        if let url = instagramURL, UIApplication.shared.canOpenURL(url) {
            UIPasteboard.general.string = "\(message)\n\n\(partyLink)"
            UIApplication.shared.open(url)
        } else {
            openInstagramWebFallback()
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = "\(message)\n\n\(partyLink)"
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Helper Methods
    private func createInstagramStoryContent() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1920))
        let image = renderer.image { context in
            // Create gradient background
            let colors = [UIColor.purple.cgColor, UIColor.systemPink.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 1080, y: 1920),
                options: []
            )
            
            // Add party information text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
            
            party.title.draw(in: CGRect(x: 100, y: 600, width: 880, height: 200), withAttributes: titleAttributes)
            party.locationName.draw(in: CGRect(x: 100, y: 800, width: 880, height: 100), withAttributes: subtitleAttributes)
            "RSVP on Bondfyr".draw(in: CGRect(x: 100, y: 1200, width: 880, height: 100), withAttributes: titleAttributes)
        }
        
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
    
    private func showSnapchatHelper() {
        // This would show a toast/alert with instructions
        // For now, we'll just provide clipboard feedback
    }
    
    private func openInstagramWebFallback() {
        if let url = URL(string: "https://instagram.com") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSnapchatWebFallback() {
        if let url = URL(string: "https://snapchat.com") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Social Platform Button
struct SocialPlatformButton: View {
    let title: String
    let icon: String
    let color: Color
    let gradientColors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Activity View Controller Wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Exclude certain activities that aren't relevant
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .saveToCameraRoll
        ]
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 