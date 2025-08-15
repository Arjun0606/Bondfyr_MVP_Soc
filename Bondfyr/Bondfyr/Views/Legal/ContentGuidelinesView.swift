import SwiftUI

struct ContentGuidelinesView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Community Guidelines")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.bottom)
                        
                        Text("Keep Bondfyr Safe and Fun for Everyone")
                            .font(.title2)
                            .foregroundColor(.pink)
                            .padding(.bottom)
                        
                        guidelineSection(
                            icon: "heart.fill",
                            title: "Be Respectful",
                            content: """
                            • Treat all users with kindness and respect
                            • No harassment, bullying, or discriminatory language
                            • Respect cultural and personal differences
                            • Communicate clearly and honestly with hosts and guests
                            """
                        )
                        
                        guidelineSection(
                            icon: "shield.fill",
                            title: "Stay Safe",
                            content: """
                            • Meet in public or well-known locations when possible
                            • Trust your instincts - leave if you feel uncomfortable
                            • Don't share personal information like home addresses publicly
                            • Report suspicious or concerning behavior immediately
                            """
                        )
                        
                        guidelineSection(
                            icon: "checkmark.circle.fill",
                            title: "Host Responsibly",
                            content: """
                            • Provide accurate event details and location information
                            • Set clear expectations for your event
                            • Manage guest capacity responsibly for safety
                            • Check local laws and regulations for hosting events
                            • Handle alcohol responsibly and verify ages when required
                            """
                        )
                        
                        guidelineSection(
                            icon: "person.3.fill",
                            title: "Be a Good Guest",
                            content: """
                            • RSVP honestly and show up if you commit to attending
                            • Follow house rules and respect the host's property
                            • Be social and contribute to a positive atmosphere
                            • Clean up after yourself and help when appropriate
                            """
                        )
                        
                        guidelineSection(
                            icon: "exclamationmark.triangle.fill",
                            title: "Prohibited Content & Behavior",
                            content: """
                            • No illegal activities or promotion of illegal substances
                            • No explicit sexual content or inappropriate imagery
                            • No spam, fake events, or misleading information
                            • No selling of regulated items (alcohol, tobacco, etc.)
                            • No events that violate local noise ordinances or laws
                            """
                        )
                        
                        guidelineSection(
                            icon: "flag.fill",
                            title: "Reporting Issues",
                            content: """
                            • Report inappropriate content, behavior, or safety concerns
                            • Use the report button on party cards or user profiles
                            • For emergencies, contact local authorities immediately
                            • We review all reports promptly and take appropriate action
                            """
                        )
                        
                        VStack(alignment: .center, spacing: 12) {
                            Text("Questions or Concerns?")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Contact us at karjunvarma2001@gmail.com")
                                .font(.subheadline)
                                .foregroundColor(.pink)
                            
                            Text("Together, we can keep Bondfyr a safe and enjoyable platform for everyone!")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.top)
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Community Guidelines", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.pink)
            )
        }
    }
    
    private func guidelineSection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.pink)
                    .frame(width: 30)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 42)
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    ContentGuidelinesView()
}
