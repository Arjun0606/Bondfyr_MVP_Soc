import SwiftUI
import FirebaseFirestore

struct ContestPhotoGalleryView: View {
    let eventId: String
    let eventName: String
    
    @StateObject private var photoManager = PhotoManager.shared
    @State private var selectedPhoto: EventPhoto?
    @State private var isShowingPhotoCapture = false
    @State private var contestStatus: ContestStatus = .checking
    @Environment(\.presentationMode) var presentationMode
    
    enum ContestStatus {
        case checking
        case active(timeRemaining: TimeInterval)
        case ended
        case noContest
    }
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header with event name and close button
                HStack {
                    Text("Contest Photos")
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
                .padding()
                
                // Contest Status Banner
                contestStatusView
                
                if photoManager.photos.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                        
                        Text("No contest photos yet.")
                            .foregroundColor(.gray)
                        
                        if case .active = contestStatus {
                            Button(action: {
                                isShowingPhotoCapture = true
                            }) {
                                Text("Take your contest photo")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.pink)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Leaders Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Leaderboard")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(topPhotos.enumerated()), id: \.element.id) { index, photo in
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
                                    .onTapGesture {
                                        selectedPhoto = photo
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    
                    // All Contest Photos
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Photos")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(photoManager.photos, id: \.id) { photo in
                                    VStack {
                                        AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(height: 160)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(height: 160)
                                                    .clipped()
                                            case .failure:
                                                Image(systemName: "exclamationmark.triangle")
                                                    .frame(height: 160)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            selectedPhoto = photo
                                        }
                                        
                                        HStack {
                                            Image(systemName: "heart.fill")
                                                .foregroundColor(.pink)
                                                .font(.caption)
                                            
                                            Text("\(photo.likes)")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // If contest is active, show button to take photo
                    if case .active = contestStatus {
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
                    }
                }
            }
        }
        .onAppear {
            photoManager.fetchPhotos(eventId: eventId, contestOnly: true)
            checkContestStatus()
        }
        .fullScreenCover(isPresented: $isShowingPhotoCapture) {
            ContestPhotoCaptureView(eventId: eventId)
        }
        .sheet(item: $selectedPhoto) { photo in
            ContestPhotoDetailView(photo: photo)
        }
    }
    
    private var contestStatusView: some View {
        Group {
            switch contestStatus {
            case .checking:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
            case .active(let timeRemaining):
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.red)
                    
                    Text("Contest active: \(timeString(from: timeRemaining))")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                .background(Color.pink.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
                
            case .ended:
                HStack {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(.green)
                    
                    Text("Contest ended - winners shown below")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
                
            case .noContest:
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.gray)
                    
                    Text("Showing all contest photos")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    private var topPhotos: [EventPhoto] {
        // Return top 3 photos by likes (or all if less than 3)
        let sorted = photoManager.photos.sorted { $0.likes > $1.likes }
        return Array(sorted.prefix(3))
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
    
    private func checkContestStatus() {
        if photoManager.contestActive && photoManager.contestEventId == eventId {
            if let timeRemaining = photoManager.getContestTimeRemaining() {
                contestStatus = .active(timeRemaining: timeRemaining)
            } else {
                contestStatus = .ended
            }
        } else {
            contestStatus = .noContest
        }
    }
    
    private func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct ContestPhotoDetailView: View {
    let photo: EventPhoto
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
                HStack {
                    Text("Contest Entry")
                        .font(.caption)
                        .padding(5)
                        .background(Color.pink.opacity(0.2))
                        .cornerRadius(5)
                        .foregroundColor(.pink)
                    
                    Spacer()
                    
                    HStack {
                        Text("\(photo.likes)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            if !isLiked {
                                isLiked = true
                                PhotoManager.shared.likePhoto(photoId: photo.id)
                            }
                        }) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .pink : .white)
                                .font(.title3)
                        }
                        .disabled(isLiked)
                    }
                }
                .padding()
            }
        }
    }
} 