import SwiftUI

struct HostRatingDisplay: View {
    let hostId: String
    @State private var ratingData: HostRatingSummary?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else if let rating = ratingData {
                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating.starRating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= rating.starRating ? .yellow : .gray)
                    }
                }
                
                // Rating text
                Text(String(format: "%.1f", rating.displayRating))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                // Rating count
                Text("(\(rating.totalRatings))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            } else {
                Text("New Host")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadRating()
        }
    }
    
    private func loadRating() async {
        isLoading = true
        ratingData = await RatingManager.shared.getHostRating(for: hostId)
        isLoading = false
    }
}

// MARK: - Compact version for small spaces
struct CompactHostRating: View {
    let hostId: String
    @State private var ratingData: HostRatingSummary?
    
    var body: some View {
        HStack(spacing: 2) {
            if let rating = ratingData {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f", rating.displayRating))
                    .font(.caption2)
                    .fontWeight(.medium)
            } else {
                Text("NEW")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .task {
            ratingData = await RatingManager.shared.getHostRating(for: hostId)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HostRatingDisplay(hostId: "sample-host-id")
        CompactHostRating(hostId: "sample-host-id")
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
} 