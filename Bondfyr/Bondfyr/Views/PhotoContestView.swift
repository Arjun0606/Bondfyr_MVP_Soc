import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

struct PhotoContestView: View {
    let eventId: String
    let eventName: String
    
    @State private var photos: [ContestPhoto] = []
    @State private var isLoading = true
    @State private var showCamera = false
    @State private var selectedPhoto: ContestPhoto?
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                } else if photos.isEmpty {
                    emptyStateView
                } else {
                    photosGridView
                }
            }
            .navigationTitle("\(eventName) Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCamera = true
                    }) {
                        Image(systemName: "camera")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                ContestPhotoCaptureView(eventId: eventId)
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
            .onAppear {
                loadPhotos()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No photos yet")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Be the first to capture a moment at this event!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showCamera = true
            }) {
                Text("Take Photo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .padding()
    }
    
    private var photosGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(photos) { photo in
                    photoCell(photo)
                        .onTapGesture {
                            selectedPhoto = photo
                        }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
        }
    }
    
    private func photoCell(_ photo: ContestPhoto) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: photo.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(ProgressView())
            }
            .frame(height: 180)
            .cornerRadius(10)
            .clipped()
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    
                    Text("\(photo.likeCount)")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(photo.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
            .padding(8)
        }
    }
    
    private func loadPhotos() {
        isLoading = true
        
        Firestore.firestore().collection("photo_contests")
            .whereField("eventId", isEqualTo: eventId)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let error = error {
                    print("Error loading photos: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                self.photos = documents.compactMap { document -> ContestPhoto? in
                    let data = document.data()
                    
                    guard let userId = data["userId"] as? String,
                          let imageUrl = data["imageUrl"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    
                    return ContestPhoto(
                        id: document.documentID,
                        userId: userId,
                        eventId: self.eventId,
                        imageUrl: imageUrl,
                        timestamp: timestamp,
                        likeCount: data["likeCount"] as? Int ?? 0
                    )
                }
            }
    }
}

// Model for a contest photo
struct ContestPhoto: Identifiable, Equatable {
    let id: String
    let userId: String
    let eventId: String
    let imageUrl: String
    let timestamp: Date
    let likeCount: Int
    
    static func == (lhs: ContestPhoto, rhs: ContestPhoto) -> Bool {
        return lhs.id == rhs.id
    }
}

// View for displaying a photo in detail
struct PhotoDetailView: View {
    let photo: ContestPhoto
    @State private var hasLiked = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                AsyncImage(url: URL(string: photo.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView())
                }
                .cornerRadius(12)
                .padding()
                
                HStack {
                    Button(action: {
                        toggleLike()
                    }) {
                        HStack {
                            Image(systemName: hasLiked ? "heart.fill" : "heart")
                                .foregroundColor(hasLiked ? .red : .white)
                            
                            Text("\(photo.likeCount + (hasLiked ? 1 : 0))")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Text(photo.timestamp.formatted())
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Close")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(10)
                        .padding()
                }
            }
        }
        .onAppear {
            checkIfLiked()
        }
    }
    
    private func checkIfLiked() {
        // In a real app, this would check if the current user has liked this photo
        // For now, just set to false
        hasLiked = false
    }
    
    private func toggleLike() {
        hasLiked.toggle()
        
        // In a real app, this would update the like count in Firestore
        // For demo purposes, just toggle the local state
    }
}

struct PhotoContestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PhotoContestView(eventId: "test-event-id", eventName: "Summer Party")
        }
    }
}
