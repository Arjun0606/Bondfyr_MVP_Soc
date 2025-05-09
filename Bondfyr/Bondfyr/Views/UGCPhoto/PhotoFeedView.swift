import SwiftUI
import Kingfisher
import Bondfyr

struct PhotoFeedView: View {
    @StateObject private var photoService = UGCPhotoService()
    @State private var selectedScope: PhotoScope = .city
    @State private var showCamera = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Scope selector
                    Picker("Scope", selection: $selectedScope) {
                        Text("City").tag(PhotoScope.city)
                        Text("Country").tag(PhotoScope.country)
                        Text("World").tag(PhotoScope.world)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Photo grid
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            let photos = selectedPhotos
                            if photos.isEmpty && !isLoading {
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    Text("No photos yet")
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 100)
                            } else {
                                ForEach(photos) { photo in
                                    PhotoCard(photo: photo, onLike: { likePhoto(photo) })
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .refreshable {
                        await refreshPhotos()
                    }
                }
            }
            .navigationTitle("Daily Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCamera = true }) {
                        Image(systemName: "camera.fill")
                    }
                    .disabled(photoService.hasUploadedToday)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await refreshPhotos()
        }
        .onChange(of: selectedScope) { _ in
            Task {
                await refreshPhotos()
            }
        }
    }
    
    private var selectedPhotos: [UGCPhoto] {
        switch selectedScope {
        case .city:
            return photoService.cityPhotos
        case .country:
            return photoService.countryPhotos
        case .world:
            return photoService.worldPhotos
        }
    }
    
    private func refreshPhotos() async {
        isLoading = true
        do {
            try await photoService.fetchPhotos(scope: selectedScope)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    private func likePhoto(_ photo: UGCPhoto) {
        Task {
            do {
                try await photoService.likePhoto(photo)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct PhotoCard: View {
    let photo: UGCPhoto
    let onLike: () -> Void
    @State private var imageHeight: CGFloat = 300
    @State private var showFullScreen = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Photo
            KFImage(URL(string: photo.photoURL))
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: imageHeight)
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .cornerRadius(12)
                .onTapGesture {
                    showFullScreen = true
                }
            
            // User info and likes
            HStack {
                Text("@\(photo.userHandle)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: photo.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundColor(photo.isLikedByCurrentUser ? .pink : .white)
                        Text("\(photo.likes)")
                            .foregroundColor(.white)
                    }
                }
                .disabled(photo.isLikedByCurrentUser)
            }
            
            // Time remaining
            Text(photo.formattedTimestamp)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPhotoView(photo: photo, onLike: onLike)
        }
    }
}

struct FullScreenPhotoView: View {
    let photo: UGCPhoto
    let onLike: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    KFImage(URL(string: photo.photoURL))
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("@\(photo.userHandle)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                onLike()
                                if !photo.isLikedByCurrentUser {
                                    // Add haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: photo.isLikedByCurrentUser ? "heart.fill" : "heart")
                                        .foregroundColor(photo.isLikedByCurrentUser ? .pink : .white)
                                    Text("\(photo.likes)")
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(photo.isLikedByCurrentUser)
                        }
                        
                        Text(photo.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(photo.city), \(photo.country)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
} 