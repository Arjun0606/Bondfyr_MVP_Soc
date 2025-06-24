import SwiftUI
import FirebaseAuth

// Extension for Event Detail View to add Photo Contest functionality
extension EventDetailView {
    
    // Photo Contest section that can be added to the event detail view
    func photoContestSection() -> some View {
        Section(header: Text("Photo Contest")) {
            photoContestButton()
            
            // Test button for vendors to trigger photo contest
            if AuthManager.shared.isVendorOrAdmin() {
                Button(action: {
                    triggerPhotoContest()
                }) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.orange))
                        
                        Text("Trigger Photo Contest Notification")
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // Photo Contest button that navigates to the Photo Contest view
    @ViewBuilder
    func photoContestButton() -> some View {
        NavigationLink(destination: PhotoContestView(eventId: event.id.uuidString, eventName: event.name)) {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.blue))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Photo Contest")
                        .font(.headline)
                    
                    Text("View & share photos from this event")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Check if user can upload photos to contest
    func checkUploadEligibility(completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        PhotoContestManager.shared.checkUploadEligibility(for: event.id.uuidString) { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }
    
    // Photo Contest Notification Banner that shows up when a user scans their ticket
    func photoContestNotificationBanner(isPresented: Binding<Bool>) -> some View {
        VStack {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Photo Contest Unlocked!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("You can now upload photos to the event contest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    isPresented.wrappedValue = false
                }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: isPresented.wrappedValue)
    }
    
    // Function to trigger the photo contest (for vendor use)
    private func triggerPhotoContest() {
        NotificationManager.shared.triggerPhotoContestForEvent(eventId: event.id.uuidString)
        
        // Create a feedback alert to confirm action
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // You can also show a confirmation alert or toast here
    }
}

// Customizable photo contest button with different styles
struct PhotoContestButton: View {
    let event: Event
    var style: ButtonStyle = .default
    var onTap: () -> Void
    
    enum ButtonStyle {
        case `default`
        case compact
        case featured
    }
    
    var body: some View {
        Button(action: onTap) {
            switch style {
            case .default:
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.blue))
                    
                    Text("Photo Contest")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
            case .compact:
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.blue)
                    
                    Text("Photos")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
                
            case .featured:
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.blue))
                    
                    Text("Event Photo Contest")
                        .fontWeight(.semibold)
                    
                    Text("Share and like photos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
    }
}

// Preview provider for the Photo Contest Button
struct PhotoContestButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PhotoContestButton(
                event: Event(
                    id: UUID(),
                    name: "Summer Party",
                    date: "2023-08-15",
                    time: "8:00 PM",
                    venue: "Beach Club",
                    description: "A fun summer party",
                    hostId: "host1",
                    host: "Beach Club",
                    coverPhoto: "",
                    ticketTiers: [],
                    venueLogoImage: ""
                ),
                style: .default
            ) {
                print("Default button tapped")
            }
            
            PhotoContestButton(
                event: Event(
                    id: UUID(),
                    name: "Summer Party",
                    date: "2023-08-15",
                    time: "8:00 PM",
                    venue: "Beach Club",
                    description: "A fun summer party",
                    hostId: "host1",
                    host: "Beach Club",
                    coverPhoto: "",
                    ticketTiers: [],
                    venueLogoImage: ""
                ),
                style: .compact
            ) {
                print("Compact button tapped")
            }
            
            PhotoContestButton(
                event: Event(
                    id: UUID(),
                    name: "Summer Party",
                    date: "2023-08-15",
                    time: "8:00 PM",
                    venue: "Beach Club",
                    description: "A fun summer party",
                    hostId: "host1",
                    host: "Beach Club",
                    coverPhoto: "",
                    ticketTiers: [],
                    venueLogoImage: ""
                ),
                style: .featured
            ) {
                print("Featured button tapped")
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
