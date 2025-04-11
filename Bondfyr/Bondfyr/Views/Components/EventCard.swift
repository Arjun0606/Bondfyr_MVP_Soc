import SwiftUI

struct EventCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event image with venue logo overlay
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
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(10)
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 8) {
                Text(event.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(event.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.pink)
                        Text(event.date)
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.pink)
                        Text(event.time)
                            .foregroundColor(.white)
                            .font(.caption)
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
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
} 