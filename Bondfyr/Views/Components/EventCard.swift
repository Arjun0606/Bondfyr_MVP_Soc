import SwiftUI

struct EventCard: View {
    let event: Event
    @StateObject private var savedEventsManager = SavedEventsManager.shared
    
    private var isSaved: Bool {
        let eventId = event.id.uuidString
        return savedEventsManager.savedEvents.contains(where: { $0.id.uuidString == eventId })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Event name at the top, bold
            Text(event.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Club name below event name, white, bold
            Text(event.name)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Area/location above date/time
            Text(event.venue)
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
                AsyncImage(url: URL(string: event.coverPhoto)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
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
            
            // Contest badge removed since photoContestActive property doesn't exist in Event model
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