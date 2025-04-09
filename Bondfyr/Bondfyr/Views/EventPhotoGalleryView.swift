import SwiftUI
import FirebaseFirestore
import Combine
import FirebaseAuth

struct EventPhotoGalleryView: View {
    let eventId: String
    let eventName: String
    
    @StateObject private var photoManager = PhotoManager.shared
    @State private var selectedPhoto: GalleryPhoto?
    @State private var isShowingPhotoCapture = false
    @State private var showLikeLeaderboard = true
    @State private var hasCheckedIn = false
    @State private var isLoading = true
    @Environment(\.presentationMode) var presentationMode
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var topContestPhotos: [GalleryPhoto] {
        let sorted = photoManager.photos.sorted { $0.likes > $1.likes }
        return Array(sorted.prefix(3))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 8) {
                // Header with event name and close button
                HStack {
                    Text(eventName + " Contest")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Contest Status if applicable
                if photoManager.contestActive {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.pink)
                        
                        if let timeRemaining = photoManager.getContestTimeRemaining() {
                            Text("Contest active: \(timeString(from: timeRemaining))")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        } else {
                            Text("Contest active")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.pink.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    // Leaders Section for contest photos
                    if !topContestPhotos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Leaderboard")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    showLikeLeaderboard.toggle()
                                }) {
                                    Image(systemName: showLikeLeaderboard ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal)
                            
                            if showLikeLeaderboard {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(topContestPhotos.enumerated()), id: \.element.id) { index, photo in
                                            VStack {
                                                ZStack(alignment: .topLeading) {
                                                    AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                                                        switch phase {
                                                        case .empty:
                                                            ProgressView()
                                                                .frame(width: 150, height: 150)
                                                        case .success(let image):
                                                            image
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(width: 150, height: 150)
                                                                .clipped()
                                                        case .failure:
                                                            Image(systemName: "exclamationmark.triangle")
                                                                .frame(width: 150, height: 150)
                                                        @unknown default:
                                                            EmptyView()
                                                        }
                                                    }
                                                    .cornerRadius(8)
                                                    .onTapGesture {
                                                        selectedPhoto = photo
                                                    }
                                                    
                                                    // Position badge
                                                    ZStack {
                                                        Circle()
                                                            .fill(positionColor(for: index))
                                                            .frame(width: 30, height: 30)
                                                        
                                                        Text("\(index + 1)")
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                    }
                                                    .padding(6)
                                                }
                                                
                                                HStack {
                                                    Image(systemName: "heart.fill")
                                                        .foregroundColor(.pink)
                                                        .font(.caption)
                                                    
                                                    Text("\(photo.likes)")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if photoManager.photos.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                            
                            Text("No contest photos yet.")
                                .foregroundColor(.gray)
                            
                            if hasCheckedIn {
                                Button(action: {
                                    isShowingPhotoCapture = true
                                }) {
                                    Text("Take contest photo")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.pink)
                                        .cornerRadius(8)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.gray)
                                    
                                    Text("You must be at the venue to take contest photos")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                            
                            Spacer()
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Photo grid
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(photoManager.photos, id: \.id) { photo in
                                    ZStack(alignment: .topLeading) {
                                        AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(height: 180)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(height: 180)
                                                    .clipped()
                                            case .failure:
                                                Image(systemName: "exclamationmark.triangle")
                                                    .frame(height: 180)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .cornerRadius(8)
                                        .overlay(
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Image(systemName: "heart.fill")
                                                        .foregroundColor(.pink)
                                                    
                                                    Text("\(photo.likes)")
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                        .fontWeight(.bold)
                                                    
                                                    Spacer()
                                                }
                                                .padding(8)
                                                .background(Color.black.opacity(0.6))
                                            },
                                            alignment: .bottom
                                        )
                                        .onTapGesture {
                                            selectedPhoto = photo
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Contest photo button - only for checked in users
                        if hasCheckedIn {
                            Button(action: {
                                isShowingPhotoCapture = true
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Take Contest Photo")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.pink)
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .padding(.bottom)
                            }
                        } else {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.gray)
                                
                                Text("You must be at the venue to take contest photos")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                }
            }
        }
        .onAppear {
            checkUserStatus()
            photoManager.getPhotos(for: eventId) { photos in
                DispatchQueue.main.async {
                    self.photoManager.photos = photos.filter { $0.isContestEntry }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingPhotoCapture) {
            if hasCheckedIn {
                ContestPhotoCaptureView(eventId: eventId)
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            EventPhotoDetailView(photo: photo)
        }
    }
    
    private func checkUserStatus() {
        isLoading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            hasCheckedIn = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("check_ins")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    hasCheckedIn = true
                } else {
                    hasCheckedIn = false
                }
            }
    }
    
    private func positionColor(for index: Int) -> Color {
        switch index {
        case 0:
            return .yellow // Gold
        case 1:
            return .gray // Silver
        case 2:
            return .brown // Bronze
        default:
            return .pink
        }
    }
    
    private func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct EventPhotoDetailView: View {
    let photo: GalleryPhoto
    @State private var isLiked = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Photo
                AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    case .failure:
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    @unknown default:
                        EmptyView()
                    }
                }
                
                Spacer()
                
                // Info and interactions
                VStack(spacing: 15) {
                    ZStack {
                        Text("Contest Entry")
                            .font(.headline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.pink)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            isLiked.toggle()
                            if isLiked {
                                PhotoManager.shared.likePhoto(photo: photo)
                            } else {
                                PhotoManager.shared.unlikePhoto(photo: photo)
                            }
                        }) {
                            HStack {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(isLiked ? .pink : .white)
                                
                                Text("\(photo.likes + (isLiked ? 1 : 0))")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.bottom)
                }
                .padding()
            }
        }
        .onAppear {
            // Check if the user has already liked this photo
            PhotoManager.shared.checkIfUserLikedPhoto(photo: photo) { liked in
                isLiked = liked
            }
        }
    }
} 