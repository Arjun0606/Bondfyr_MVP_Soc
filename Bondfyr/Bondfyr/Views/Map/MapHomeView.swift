import SwiftUI
import MapKit

struct Venue: Identifiable {
    let id = UUID()
    let name: String
    let city: String
    let coordinate: CLLocationCoordinate2D
    let genre: String
    let crowdLevel: CrowdLevel
}

enum CrowdLevel: String {
    case low, medium, high
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    var description: String {
        switch self {
        case .low: return "Quiet"
        case .medium: return "Moderate"
        case .high: return "Packed"
        }
    }
}

struct MapHomeView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567), // Pune
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    @State private var selectedVenue: VenueWithCrowd? = nil
    @ObservedObject var mapManager = MapFirestoreManager.shared
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: mapManager.venues) { venue in
                MapAnnotation(coordinate: venue.coordinate) {
                    Circle()
                        .fill(venue.crowdLevel.color)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .onTapGesture {
                            selectedVenue = venue
                        }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear { mapManager.startListening() }
            .onDisappear { mapManager.stopListening() }
            
            if let venue = selectedVenue {
                VenueDetailCard(venue: venue, onClose: { selectedVenue = nil })
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
    }
}

struct VenueDetailCard: View {
    let venue: VenueWithCrowd
    let onClose: () -> Void
    @State private var ugcPosts: [UGCPost] = []
    @State private var isLoadingUGC = false
    @State private var checkInSuccess: Bool = false
    @State private var checkInError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(venue.name)
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            Text(venue.city)
                .foregroundColor(.secondary)
            Text("Genre: \(venue.genre)")
                .foregroundColor(.white)
            HStack {
                Text("Crowd: ")
                    .foregroundColor(.white)
                Text(venue.crowdLevel.description)
                    .foregroundColor(venue.crowdLevel.color)
                    .bold()
                if let count = venue.currentCrowdEstimate {
                    Text("(est. ~\(count) people)")
                        .foregroundColor(.gray)
                }
            }
            if let updated = venue.updatedAt {
                Text("Updated: \(relativeDateString(from: updated))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            // Check In button
            Button(action: checkIn) {
                Text(checkInSuccess ? "Checked In!" : "Check In")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(checkInSuccess ? Color.green : Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(checkInSuccess)
            if let error = checkInError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            // UGC preview
            if isLoadingUGC {
                ProgressView().padding(.top, 8)
            } else if !ugcPosts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ugcPosts) { post in
                            UGCThumbnailView(post: post)
                        }
                    }
                }
                .frame(height: 60)
            } else {
                Text("No recent photos/videos yet.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(BlurView(style: .systemMaterialDark))
        .cornerRadius(16)
        .padding()
        .shadow(radius: 10)
        .frame(maxWidth: 350)
        .frame(maxHeight: 280)
        .position(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height - 180)
        .onAppear { fetchUGC() }
    }
    func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    func fetchUGC() {
        isLoadingUGC = true
        VenueUGCManager.shared.fetchRecentUGC(for: venue.id) { posts in
            ugcPosts = posts
            isLoadingUGC = false
        }
    }
    func checkIn() {
        checkInError = nil
        CheckInManager.shared.checkInToVenue(venueId: venue.id) { result in
            switch result {
            case .success:
                checkInSuccess = true
            case .failure(let error):
                checkInError = error.localizedDescription
            }
        }
    }
}

struct UGCThumbnailView: View {
    let post: UGCPost
    var body: some View {
        if post.type == "photo" {
            AsyncImage(url: URL(string: post.mediaURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if post.type == "video" {
            ZStack {
                Color.black.opacity(0.7)
                Image(systemName: "video.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Preview
struct MapHomeView_Previews: PreviewProvider {
    static var previews: some View {
        MapHomeView()
            .preferredColorScheme(.dark)
    }
} 