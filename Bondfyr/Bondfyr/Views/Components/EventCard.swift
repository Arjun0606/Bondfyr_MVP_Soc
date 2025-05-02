import SwiftUI

struct EventCard: View {
    let event: Event
    @StateObject private var savedEventsManager = SavedEventsManager.shared
    
    private var isSaved: Bool {
        guard let firestoreId = event.firestoreId else { return false }
        return savedEventsManager.savedEvents.contains(where: { $0.firestoreId == firestoreId })
    }
    
    var body: some View {
        // Debug print to check IDs
        let _ = {
            print("[EventCard] Current event: \(event.eventName), firestoreId: \(event.firestoreId ?? "nil")")
            for saved in savedEventsManager.savedEvents {
                print("[EventCard] Saved event: \(saved.eventName), firestoreId: \(saved.firestoreId ?? "nil")")
            }
        }()
        VStack(alignment: .leading, spacing: 8) {
            // Event name at the top, bold
            Text(event.eventName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Club name below event name, white, bold
            Text(event.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Area/location above date/time
            Text(event.location)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 2)
            
            HStack {
                // Date
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.pink)
                    Text(event.date)
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
                
                Spacer()
                
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.pink)
                    Text(event.time)
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
            }
            .padding(.bottom, 8)
            
            // Event image with venue logo overlay and save button
            ZStack(alignment: .bottomLeading) {
                // Event poster image
                Image(event.eventPosterImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(12)
                
                // Venue logo in bottom corner
                Image(event.venueLogoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(10)
                
                // Save button in top right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: toggleSave) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .foregroundColor(isSaved ? .pink : .white)
                                .font(.system(size: 22))
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(10)
                    }
                    Spacer()
                }
            }
            
            // Contest badge if active
            if event.photoContestActive {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                    Text("Photo Contest Active!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.pink)
                .cornerRadius(10)
                .padding(.top, 8)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
    
    private func toggleSave() {
        if isSaved {
            savedEventsManager.unsaveEvent(event) { _ in }
        } else {
            savedEventsManager.saveEvent(event) { _ in }
        }
    }
} 