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
    @State private var searchText = ""
    @State private var showCountryPicker = false
    @State private var selectedCountry: String = "India" // Default country
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Location header based on scope
                Group {
                    switch selectedScope {
                    case .city:
                        CityHeader(cityName: CityManager.shared.selectedCity, onTap: {})
                    case .country:
                        CountryHeader(countryName: selectedCountry, onTap: { showCountryPicker = true })
                    case .world:
                        WorldHeader()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Scope selector
                HStack(spacing: 16) {
                    Button(action: { selectedScope = .city }) {
                        Text("City")
                            .fontWeight(selectedScope == .city ? .bold : .regular)
                            .foregroundColor(selectedScope == .city ? .pink : .purple.opacity(0.7))
                            .shadow(color: selectedScope == .city ? .pink.opacity(0.7) : .clear, radius: 4, x: 0, y: 0)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(selectedScope == .city ? Color.pink.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                    }
                    
                    Button(action: { selectedScope = .country }) {
                        Text("Country")
                            .fontWeight(selectedScope == .country ? .bold : .regular)
                            .foregroundColor(selectedScope == .country ? .pink : .purple.opacity(0.7))
                            .shadow(color: selectedScope == .country ? .pink.opacity(0.7) : .clear, radius: 4, x: 0, y: 0)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(selectedScope == .country ? Color.pink.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                    }
                    
                    Button(action: { selectedScope = .world }) {
                        Text("World")
                            .fontWeight(selectedScope == .world ? .bold : .regular)
                            .foregroundColor(selectedScope == .world ? .pink : .purple.opacity(0.7))
                            .shadow(color: selectedScope == .world ? .pink.opacity(0.7) : .clear, radius: 4, x: 0, y: 0)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(selectedScope == .world ? Color.pink.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.pink)
                    TextField("Search photos...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 1.2)
                        .shadow(color: .purple.opacity(0.3), radius: 6, x: 0, y: 0)
                )
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Photo grid
                ScrollView {
                    LazyVStack(spacing: 16) {
                        let photos = filteredPhotos
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCamera = true }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.pink)
                        .shadow(color: .pink.opacity(0.5), radius: 4, x: 0, y: 0)
                }
                .disabled(photoService.hasUploadedToday)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView()
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $selectedCountry)
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
        .onChange(of: selectedCountry) { _ in
            Task {
                await refreshPhotos()
            }
        }
    }
    
    private var filteredPhotos: [UGCPhoto] {
        let photos = selectedPhotos
        if searchText.isEmpty { return photos }
        return photos.filter { photo in
            photo.userHandle.localizedCaseInsensitiveContains(searchText) ||
            photo.city.localizedCaseInsensitiveContains(searchText)
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

// Helper view for city header
private struct CityHeader: View {
    let cityName: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.pink)
                    .shadow(color: .pink.opacity(0.7), radius: 6, x: 0, y: 0)
                Text(cityName?.components(separatedBy: ",").first ?? "No City Selected")
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 0)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.pink.opacity(0.5), lineWidth: 1.5)
                    .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 0)
            )
            .cornerRadius(12)
        }
    }
}

// Helper view for country header
private struct CountryHeader: View {
    let countryName: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.pink)
                    .shadow(color: .pink.opacity(0.7), radius: 6, x: 0, y: 0)
                Text(countryName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 0)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.pink)
                    .font(.system(size: 14))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.pink.opacity(0.5), lineWidth: 1.5)
                    .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 0)
            )
            .cornerRadius(12)
        }
    }
}

// Helper view for world header
private struct WorldHeader: View {
    var body: some View {
        HStack {
            Image(systemName: "globe.americas.fill")
                .foregroundColor(.pink)
                .shadow(color: .pink.opacity(0.7), radius: 6, x: 0, y: 0)
            Text("Earth C-137")
                .font(.headline)
                .foregroundColor(.white)
                .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 0)
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pink.opacity(0.5), lineWidth: 1.5)
                .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 0)
        )
        .cornerRadius(12)
    }
}

// Country picker view
private struct CountryPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCountry: String
    @State private var searchText = ""
    
    // Add more countries as needed
    private let countries = [
        "India", "United States", "United Kingdom", "Canada", "Australia",
        "Japan", "South Korea", "France", "Germany", "Italy",
        "Spain", "Brazil", "Mexico", "China", "Russia"
    ].sorted()
    
    private var filteredCountries: [String] {
        if searchText.isEmpty {
            return countries
        }
        return countries.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.pink)
                        TextField("Search countries...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Country list
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredCountries, id: \.self) { country in
                                Button(action: {
                                    selectedCountry = country
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(country)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if country == selectedCountry {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.pink)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
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