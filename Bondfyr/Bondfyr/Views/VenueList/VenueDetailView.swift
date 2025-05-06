import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

struct VenueDetailView: View {
    let venue: VenueWithCrowd
    @State private var ugcPosts: [UGCPost] = []
    @State private var isLoadingUGC = false
    @State private var checkInSuccess: Bool = false
    @State private var checkInError: String? = nil
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Venue name and genre
                HStack {
                    Text(venue.name)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                }
                Text(venue.genre)
                    .font(.title3)
                    .foregroundColor(.pink)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                // Crowd info
                HStack(spacing: 10) {
                    Circle().fill(venue.crowdLevel.color).frame(width: 16, height: 16)
                    Text(venue.crowdLevel.description)
                        .foregroundColor(venue.crowdLevel.color)
                        .bold()
                    if let count = venue.currentCrowdEstimate {
                        Text("~\(count) people")
                            .foregroundColor(.gray)
                    }
                    if let updated = venue.updatedAt {
                        Text("Updated: \(relativeDateString(from: updated))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                // Check In button
                Button(action: checkIn) {
                    Text(checkInSuccess ? "Checked In!" : "Check In")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(checkInSuccess ? Color.green : Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.pink.opacity(0.3), radius: 8, x: 0, y: 2)
                }
                .disabled(checkInSuccess)
                if let error = checkInError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                // UGC feed
                Text("Recent Photos & Videos")
                    .font(.headline)
                    .foregroundColor(.white)
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
                    .frame(height: 80)
                } else {
                    Text("No recent photos/videos yet.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Divider().background(Color.gray)
                Text("Afterparty & More coming soon...")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .background(BlurView(style: .systemMaterialDark))
            .cornerRadius(20)
            .padding()
            .shadow(radius: 16)
        }
        .background(BackgroundGradientView())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fetchUGC() }
    }
    func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    func fetchUGC() {
        isLoadingUGC = true
        VenueUGCManager.shared.fetchRecentUGC(for: venue.id, limit: 10) { posts in
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
    func uploadMedia(item: PhotosPickerItem) {
        isUploading = true
        uploadError = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run { uploadError = "Failed to load media."; isUploading = false }
                    return
                }
                let type = item.supportedContentTypes.first?.identifier.contains("video") == true ? "video" : "photo"
                let fileName = UUID().uuidString + (type == "video" ? ".mov" : ".jpg")
                let storageRef = Storage.storage().reference().child("ugc/\(venue.id)/\(fileName)")
                _ = try await storageRef.putDataAsync(data)
                let url = try await storageRef.downloadURL()
                // Write metadata to Firestore
                let userId = Auth.auth().currentUser?.uid ?? ""
                let userDoc = try? await Firestore.firestore().collection("users").document(userId).getDocument()
                let userData = userDoc?.data() ?? [:]
                let city = userData["city"] as? String ?? ""
                let country = userData["country"] as? String ?? ""
                let continent = userData["continent"] as? String ?? ""
                let instagramHandle = userData["instagramHandle"] as? String ?? ""
                let avatarURL = userData["avatarURL"] as? String ?? nil
                let ugcData: [String: Any] = [
                    "userId": userId,
                    "venueId": venue.id,
                    "mediaURL": url.absoluteString,
                    "type": type,
                    "createdAt": FieldValue.serverTimestamp(),
                    "city": city,
                    "country": country,
                    "continent": continent,
                    "likeCount": 0,
                    "instagramHandle": instagramHandle,
                    "avatarURL": avatarURL ?? ""
                ]
                try await Firestore.firestore().collection("ugc").addDocument(data: ugcData)
                await MainActor.run {
                    isUploading = false
                    fetchUGC()
                }
            } catch {
                await MainActor.run {
                    uploadError = error.localizedDescription
                    isUploading = false
                }
            }
        }
    }
}

// Reuse UGCThumbnailView from MapHomeView 