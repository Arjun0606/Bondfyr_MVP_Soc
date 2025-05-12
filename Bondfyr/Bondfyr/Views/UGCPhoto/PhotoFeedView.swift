import SwiftUI
import FirebaseStorage
import FirebaseFirestore

// Remove the local PhotoScope enum and use the one from DailyPhotoModels
enum PhotoScope: String, CaseIterable {
    case city = "City"
    case country = "Country"
    case world = "World"
}

struct PhotoFeedView: View {
    @StateObject private var photoManager = PhotoManager.shared
    @State private var selectedScope: PhotoScope = .city
    @State private var showCamera = false
    @State private var searchText = ""
    @State private var selectedCity = "Pune"
    
    private var photos: [DailyPhoto] {
        switch selectedScope {
        case .city:
            return photoManager.cityPhotos
        case .country:
            return photoManager.countryPhotos
        case .world:
            return photoManager.worldPhotos
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // City Header
            cityHeader
            
            // Scope Selector
            scopeSelector
            
            // Search Bar
            searchBar
            
            // Content
            if photoManager.isLoading {
                loadingView
            } else {
                photoList
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .sheet(isPresented: $showCamera) {
            CameraView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCamera = true }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.pink)
                }
            }
        }
        .task {
            await photoManager.fetchPhotos(scope: DailyPhotoScope(rawValue: selectedScope.rawValue)!)
        }
    }
    
    private var cityHeader: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.pink)
            Text(selectedCity)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.black)
    }
    
    private var scopeSelector: some View {
        HStack(spacing: 0) {
            ForEach(PhotoScope.allCases, id: \.self) { scope in
                Button(action: { 
                    selectedScope = scope
                    Task {
                        await photoManager.fetchPhotos(scope: DailyPhotoScope(rawValue: scope.rawValue)!)
                    }
                }) {
                    Text(scope.rawValue)
                        .foregroundColor(selectedScope == scope ? .pink : .purple)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search photos...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }
    
    private var photoList: some View {
        ScrollView {
            if photos.isEmpty {
                VStack {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No photos yet")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(photos) { photo in
                        PhotoCard(photo: photo)
                    }
                }
                .padding()
            }
        }
    }
}

struct PhotoCard: View {
    let photo: DailyPhoto
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Photo
            if let url = URL(string: photo.photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipped()
                .cornerRadius(12)
            }
            
            // User info and likes
            HStack {
                Text("@\(photo.userHandle)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { isLiked.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .pink : .white)
                        Text("\(photo.likes)")
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Location and time
            Text("\(photo.city), \(photo.country)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
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