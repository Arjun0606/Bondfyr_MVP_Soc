import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import BondfyrPhotos

// Remove the local PhotoScope enum since we're using the one from PhotoModels.swift

struct PhotoFeedView: View {
    @StateObject private var photoManager = PhotoManager.shared
    @State private var selectedScope: PhotoScope = .city
    @State private var showCamera = false
    @State private var selectedCity = "Pune"
    @State private var showingPhotoDetail = false
    @State private var selectedPhoto: CityPhoto?
    
    var filteredPhotos: [CityPhoto] {
        photoManager.cityPhotos
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 8) {
                // City Header
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.pink)
                    Text(selectedCity)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Scope Selector
                HStack(spacing: 24) {
                    ForEach(PhotoScope.allCases, id: \.self) { scope in
                        Button(action: { selectedScope = scope }) {
                            Text(scope.rawValue)
                                .font(.system(size: 16, weight: selectedScope == scope ? .semibold : .regular))
                                .foregroundColor(selectedScope == scope ? .pink : .gray)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // Content
                if photoManager.isLoading {
                    loadingView
                } else if filteredPhotos.isEmpty {
                    emptyStateView
                } else {
                    photoGrid
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCamera) {
            CityPhotoCamera(currentCity: selectedCity)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
        .onAppear {
            photoManager.startListeningToCityPhotos(city: selectedCity)
        }
        .onDisappear {
            photoManager.stopListeningToCityPhotos()
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "photo.stack")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No photos yet")
                .font(.title3)
                .foregroundColor(.white)
            
            Text("Be the first to share a photo in \(selectedCity)!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showCamera = true }) {
                Text("Take Photo")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 160)
                    .padding(.vertical, 12)
                    .background(Color.pink)
                    .cornerRadius(25)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
    }
    
    private var photoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1)
            ], spacing: 1) {
                ForEach(filteredPhotos) { photo in
                    PhotoGridItemView(photo: photo)
                        .onTapGesture {
                            selectedPhoto = photo
                        }
                }
            }
        }
    }
}

struct PhotoGridItemView: View {
    let photo: CityPhoto
    
    var body: some View {
        AsyncImage(url: URL(string: photo.imageUrl)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .background(Color.gray.opacity(0.2))
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .background(Color.gray.opacity(0.2))
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct PhotoDetailView: View {
    let photo: CityPhoto
    @StateObject private var photoManager = PhotoManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isLiking = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(photo.city)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(timeRemaining)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                // Photo
                GeometryReader { geometry in
                    AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Like button and count
                HStack {
                    Button(action: likePhoto) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(isLiking ? .gray : .pink)
                            .font(.title2)
                    }
                    .disabled(isLiking)
                    
                    Text("\(photo.likes) likes")
                        .foregroundColor(.white)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    private var timeRemaining: String {
        let remaining = photo.expiresAt.timeIntervalSince(Date())
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) / 60 % 60
        return "\(hours)h \(minutes)m remaining"
    }
    
    private func likePhoto() {
        guard !isLiking else { return }
        isLiking = true
        
        Task {
            do {
                try await photoManager.likePhoto(photo)
                isLiking = false
            } catch {
                isLiking = false
                print("Error liking photo: \(error)")
            }
        }
    }
}

struct Photo: Identifiable {
    let id: String
    let imageUrl: String
    let userHandle: String
    let likes: Int
    let location: String
    let timestamp: Date
} 