import SwiftUI
import CoreLocation
import Foundation

enum Vibe: String, CaseIterable { case hot = "Hot", mid = "Mid", chill = "Chill" }
enum VenueSort: String, CaseIterable { case buzz = "Most Buzzing", distance = "Distance" }

struct VenueListView: View {
    // MARK: - Properties
    @ObservedObject var cityManager = CityManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var googleVenues: [SimpleVenue] = []
    @State private var isFetchingGoogleVenues = false
    @State private var showCityPicker = false
    @State private var isRefreshing = false
    @Namespace private var sortBarNamespace
    @State private var locationDenied: Bool = false
    @State private var searchText: String = ""
    @State private var selectedSort: VenueSort = .buzz
    @State private var nextPageToken: String? = nil
    @State private var isLoadingNextPage: Bool = false
    @State private var totalFetched: Int = 0
    @State private var selectedVenue: SimpleVenue? = nil
    @State private var errorMessage: String? = nil
    
    // MARK: - View Lifecycle
    init() {
        print("📱 VenueListView initialized")
    }
    
    var body: some View {
        print("📱 VenueListView.body evaluation started")
        debugState(from: "body evaluation")
        
        return NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    Group {
                        cityHeader
                            .padding(.horizontal)
                            .padding(.top)
                            .onAppear { print("📱 City header appeared") }
                        
                        if locationDenied {
                            Text("Location access is required for distance-based sorting. Please enable location in Settings.")
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }
                        
                        sortFilterBar
                            .onAppear { print("📱 Sort filter bar appeared") }
                        searchBar
                            .onAppear { print("📱 Search bar appeared") }
                    }
                    
                    // Content Section with improved state tracking
                    Group {
                        if isFetchingGoogleVenues {
                            loadingView
                                .onAppear { 
                                    print("📱 Loading view appeared")
                                    debugState(from: "loadingView appear")
                                }
                        } else if let error = errorMessage {
                            errorView(message: error)
                                .onAppear { 
                                    print("📱 Error view appeared: \(error)")
                                    debugState(from: "errorView appear")
                                }
                        } else if googleVenues.isEmpty {
                            emptyStateView
                                .onAppear { 
                                    print("📱 Empty state view appeared")
                                    debugState(from: "emptyStateView appear")
                                }
                        } else {
                            venueListView
                                .onAppear { 
                                    print("📱 Venue list view appeared with \(googleVenues.count) venues")
                                    debugState(from: "venueListView appear")
                                }
                        }
                    }
                    .onChange(of: isFetchingGoogleVenues) { newValue in
                        print("🔄 isFetchingGoogleVenues changed to: \(newValue)")
                        debugState(from: "isFetchingGoogleVenues change")
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                print("📱 VenueListView task started")
                debugState(from: "view task")
                if cityManager.selectedCity == nil {
                    print("⚠️ No city selected, detecting user's city")
                    cityManager.detectUserCity { city in
                        if let city = city {
                            print("📱 Detected user's city: \(city)")
                            DispatchQueue.main.async {
                                cityManager.selectedCity = city
                            }
                        }
                    }
                } else {
                    print("📱 City already selected: \(cityManager.selectedCity ?? "nil")")
                }
                await fetchGoogleVenuesForSelectedCity()
            }
            .onChange(of: cityManager.selectedCity) { newCity in
                print("📱 Selected city changed to: \(newCity ?? "nil")")
                debugState(from: "city change")
                // Reset state immediately
                googleVenues = []
                nextPageToken = nil
                totalFetched = 0
                // Then fetch new venues
                Task {
                    await fetchGoogleVenuesForSelectedCity()
                }
            }
            .onAppear {
                print("📱 VenueListView root appeared")
                debugState(from: "root onAppear")
            }
        }
        .sheet(isPresented: $showCityPicker) {
            CitySelectionView { selectedCity in
                print("📱 City selected from picker: \(selectedCity)")
                cityManager.selectedCity = selectedCity
                showCityPicker = false
            }
        }
    }
    
    // MARK: - Debug Helpers
    private func debugState(from location: String) {
        print("""
        🔍 VenueListView State [\(location)]:
        - isFetchingGoogleVenues: \(isFetchingGoogleVenues)
        - Venues count: \(googleVenues.count)
        - isLoadingNextPage: \(isLoadingNextPage)
        - totalFetched: \(totalFetched)
        - selectedCity: \(cityManager.selectedCity ?? "nil")
        - errorMessage: \(errorMessage ?? "nil")
        """)
    }

    private var cityHeader: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(.pink)
                .shadow(color: .pink.opacity(0.7), radius: 6, x: 0, y: 0)
            Text(cityManager.selectedCity?.components(separatedBy: ",").first ?? "No City Selected")
                .font(.headline)
                .foregroundColor(.white)
                .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 0)
            Spacer()
        }
        .padding()
        .background(
            Color.white.opacity(0.05)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pink.opacity(0.5), lineWidth: 1.5)
                .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 0)
        )
        .cornerRadius(12)
        .onTapGesture {
            showCityPicker = true
        }
    }

    private var sortFilterBar: some View {
        HStack(spacing: 16) {
            Button(action: { 
                selectedSort = .buzz
                // Reset location error state when switching to buzz
                locationDenied = false
            }) {
                Text("Most Buzzing")
                    .fontWeight(selectedSort == .buzz ? .bold : .regular)
                    .foregroundColor(selectedSort == .buzz ? .pink : .purple.opacity(0.7))
                    .shadow(color: selectedSort == .buzz ? .pink.opacity(0.7) : .clear, radius: 4, x: 0, y: 0)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(selectedSort == .buzz ? Color.pink.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
            }
            Button(action: { 
                selectedSort = .distance
                // Check location permission when switching to distance
                if locationManager.userLocation == nil {
                    locationDenied = true
                }
            }) {
                Text("Distance")
                    .fontWeight(selectedSort == .distance ? .bold : .regular)
                    .foregroundColor(selectedSort == .distance ? .pink : .purple.opacity(0.7))
                    .shadow(color: selectedSort == .distance ? .pink.opacity(0.7) : .clear, radius: 4, x: 0, y: 0)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(selectedSort == .distance ? Color.pink.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.pink)
            TextField("Search venues...", text: $searchText)
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
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 90, height: 90)
                    .shadow(color: .pink.opacity(0.3), radius: 16, x: 0, y: 0)
                Image(systemName: "building.2.crop.circle")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.pink)
                    .shadow(color: .pink.opacity(0.7), radius: 8, x: 0, y: 0)
            }
            Text("No venues found in your city.")
                .foregroundColor(.white)
                .font(.headline)
                .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 0)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Finding the best venues...")
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                print("🔄 Retry button tapped")
                Task {
                    await fetchGoogleVenuesForSelectedCity()
                }
            }
            .foregroundColor(.pink)
            .padding()
            .background(Color.pink.opacity(0.2))
            .cornerRadius(8)
            Spacer()
        }
        .padding()
    }

    private var venueListView: some View {
        let sortedVenues = sortVenues(filteredGoogleVenues)
        
        print("📱 Building venueListView with \(sortedVenues.count) venues")
        
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedVenues.indices, id: \.self) { index in
                    let venue = sortedVenues[index]
                    VStack(spacing: 0) {
                        SimpleGoogleVenueRow(
                            venue: venue,
                            isBuzzing: index < 5,
                            rank: index + 1
                        )
                        .onTapGesture { 
                            print("📱 Selected venue: \(venue.name)")
                            selectedVenue = venue 
                        }
                        .onAppear {
                            if index == sortedVenues.count - 5 && !isLoadingNextPage {
                                print("📱 Near end of list, loading more venues")
                                if let token = nextPageToken {
                                    fetchNextGoogleVenuesPage(token: token)
                                }
                            }
                        }
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
                
                if isLoadingNextPage {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.top, 8)
        }
        .refreshable {
            print("🔄 Manual refresh triggered")
            await fetchGoogleVenuesForSelectedCity()
        }
        .sheet(item: $selectedVenue) { venue in
            VenueDetailView(venue: venue) {
                selectedVenue = nil
            }
        }
    }

    private var filteredGoogleVenues: [SimpleVenue] {
        print("📱 Filtering \(googleVenues.count) venues with search: '\(searchText)'")
        if searchText.isEmpty { return googleVenues }
        let filtered = googleVenues.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        print("📱 Found \(filtered.count) venues matching search")
        return filtered
    }

    private func sortVenues(_ venues: [SimpleVenue]) -> [SimpleVenue] {
        venues.sorted { (v1: SimpleVenue, v2: SimpleVenue) -> Bool in
            switch selectedSort {
            case .buzz:
                // Pure rating × reviews scoring
                let score1 = v1.rating * Double(v1.reviews)
                let score2 = v2.rating * Double(v2.reviews)
                return score1 > score2
                
            case .distance:
                // Pure distance-based sorting
                guard let userLocation = locationManager.userLocation,
                      let loc1 = v1.location,
                      let loc2 = v2.location else {
                    // If we can't calculate distance, put this venue last
                    return false
                }
                let dist1 = CLLocation(latitude: loc1.lat, longitude: loc1.lng).distance(from: userLocation)
                let dist2 = CLLocation(latitude: loc2.lat, longitude: loc2.lng).distance(from: userLocation)
                return dist1 < dist2
            }
        }
    }

    private func fetchGoogleVenuesForSelectedCity() async {
        guard let city = cityManager.selectedCity, !isFetchingGoogleVenues else { 
            print("⚠️ Skipping fetch - no city selected or already fetching")
            debugState(from: "fetchGoogleVenuesForSelectedCity - guard")
            return 
        }
        
        print("🔄 Starting venue fetch for \(city)")
        debugState(from: "fetchGoogleVenuesForSelectedCity - before")
        
        await MainActor.run {
            isFetchingGoogleVenues = true
            googleVenues = []
            nextPageToken = nil
            totalFetched = 0
            errorMessage = nil
            print("📱 Reset venue state and started loading")
            debugState(from: "fetchGoogleVenuesForSelectedCity - after reset")
        }
        
        do {
            let (venues, token) = try await fetchGoogleVenues(for: city, pageToken: nil, accumulated: [])
            
            await MainActor.run {
                print("✅ Fetch completed with \(venues.count) venues")
                self.googleVenues = venues
                self.nextPageToken = token
                self.totalFetched = venues.count
                self.isFetchingGoogleVenues = false
                if venues.isEmpty {
                    self.errorMessage = "No venues found in \(city). Please try a different search."
                }
                print("📱 Updated UI with \(venues.count) venues")
                debugState(from: "fetchGoogleVenuesForSelectedCity - completion")
            }
        } catch {
            await MainActor.run {
                print("❌ Venue fetch error: \(error.localizedDescription)")
                self.errorMessage = "Failed to load venues: \(error.localizedDescription)"
                self.isFetchingGoogleVenues = false
                debugState(from: "fetchGoogleVenuesForSelectedCity - error")
            }
        }
    }

    private func fetchNextGoogleVenuesPage(token: String) {
        guard !isLoadingNextPage else { return }
        print("🔄 Loading next page with token: \(token)")
        
        isLoadingNextPage = true
        
        let apiKey = "AIzaSyAuPBQCEYfG9C0wwH5MoHRbNe4xJ8Y_3zk"
        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?pagetoken=\(token)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid next page URL")
            isLoadingNextPage = false
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                
                if response.status != "OK" {
                    print("⚠️ Next page API response status not OK: \(response.status)")
                    if let error = response.error_message {
                        print("⚠️ Next page API error: \(error)")
                    }
                    await MainActor.run {
                        isLoadingNextPage = false
                    }
                    return
                }
                
                let newVenues = response.results.filter { place in
                    guard let types = place.types else { return false }
                    
                    let isNightlifeVenue = types.contains { type in
                        ["bar", "night_club", "restaurant"].contains(type.lowercased())
                    }
                    
                    let hasRating = place.rating ?? 0 > 0
                    let hasReviews = (place.user_ratings_total ?? 0) > 0
                    
                    return isNightlifeVenue && hasRating && hasReviews
                }.map { place in
                    SimpleVenue(
                        id: place.place_id,
                        name: place.name,
                        rating: place.rating ?? 0.0,
                        reviews: place.user_ratings_total ?? 0,
                        types: place.types ?? [],
                        location: place.geometry?.location,
                        address: place.formatted_address ?? "",
                        photos: place.photos?.map { $0.photo_reference } ?? [],
                        priceLevel: place.price_level,
                        isOpenNow: place.opening_hours?.open_now
                    )
                }
                
                await MainActor.run {
                    print("✅ Found \(newVenues.count) venues in next page")
                    var updatedVenues = Set(googleVenues)
                    updatedVenues.formUnion(newVenues)
                    googleVenues = Array(updatedVenues).sorted { (v1: SimpleVenue, v2: SimpleVenue) -> Bool in
                        let score1 = v1.rating * Double(v1.reviews)
                        let score2 = v2.rating * Double(v2.reviews)
                        return score1 > score2
                    }
                    totalFetched = googleVenues.count
                    nextPageToken = response.next_page_token
                    isLoadingNextPage = false
                    print("✅ Total venues after next page: \(googleVenues.count)")
                }
            } catch {
                print("❌ Error fetching next page: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingNextPage = false
                }
            }
        }
    }

    private func fetchGoogleVenues(for city: String, pageToken: String?, accumulated: [SimpleVenue]) async throws -> ([SimpleVenue], String?) {
        print("🔍 Starting venue fetch for \(city) with \(accumulated.count) accumulated venues")
        
        let apiKey = "AIzaSyAuPBQCEYfG9C0wwH5MoHRbNe4xJ8Y_3zk"
        
        let searchStrategies = [
            "nightlife in \(city)",
            "bars in \(city)",
            "clubs in \(city)",
            "pubs in \(city)",
            "nightclubs in \(city)"
        ]
        
        var allVenues = Set<SimpleVenue>()
        var nextToken: String? = nil
        
        for strategy in searchStrategies {
            print("🔍 Using search strategy: \(strategy)")
            
            let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(strategy.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&key=\(apiKey)"
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL for strategy: \(strategy)")
                continue
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                
                if response.status != "OK" {
                    print("⚠️ API response status not OK: \(response.status)")
                    if let error = response.error_message {
                        print("⚠️ API error: \(error)")
                    }
                    continue
                }
                
                let venues = response.results.filter { place in
                    guard let types = place.types else { return false }
                    
                    // Exclude unwanted venue types
                    let excludedTypes = ["country_club", "sports_club", "golf_course", "gym", "fitness_center"]
                    if types.contains(where: { excludedTypes.contains($0.lowercased()) }) {
                        return false
                    }
                    
                    // Check for nightlife venue types
                    let nightlifeTypes = ["bar", "night_club"]
                    let isNightlifeVenue = types.contains { type in
                        nightlifeTypes.contains(type.lowercased())
                    }
                    
                    // Additional checks for name to exclude likely non-nightlife venues
                    let excludedNameKeywords = ["country club", "sports club", "golf club", "fitness", "gym"]
                    let containsExcludedKeyword = excludedNameKeywords.contains { place.name.lowercased().contains($0) }
                    
                    let hasRating = place.rating ?? 0 > 0
                    let hasEnoughReviews = (place.user_ratings_total ?? 0) >= 50
                    
                    return isNightlifeVenue && hasRating && hasEnoughReviews && !containsExcludedKeyword
                }.map { place in
                    SimpleVenue(
                        id: place.place_id,
                        name: place.name,
                        rating: place.rating ?? 0.0,
                        reviews: place.user_ratings_total ?? 0,
                        types: place.types ?? [],
                        location: place.geometry?.location,
                        address: place.formatted_address ?? "",
                        photos: place.photos?.map { $0.photo_reference } ?? [],
                        priceLevel: place.price_level,
                        isOpenNow: place.opening_hours?.open_now
                    )
                }
                
                print("✅ Found \(venues.count) venues for strategy: \(strategy)")
                allVenues.formUnion(venues)
                
                if let token = response.next_page_token {
                    nextToken = token
                }
                
                // Reduced delay to 0.5 seconds
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                print("❌ Error fetching venues for strategy \(strategy): \(error.localizedDescription)")
                continue
            }
        }
        
        // Sort venues by rating × reviews
        let sortedVenues = Array(allVenues).sorted { (v1: SimpleVenue, v2: SimpleVenue) -> Bool in
            let score1 = v1.rating * Double(v1.reviews)
            let score2 = v2.rating * Double(v2.reviews)
            return score1 > score2
        }
        
        print("✅ Total unique venues found: \(sortedVenues.count)")
        return (sortedVenues, nextToken)
    }
}

struct SimpleGoogleVenueRow: View {
    let venue: SimpleVenue
    let isBuzzing: Bool
    let rank: Int?
    
    var buzzColor: Color {
        if venue.buzz >= 0.66 { return .red }
        if venue.buzz >= 0.33 { return .orange }
        return .yellow
    }
    
    var buzzText: String {
        if venue.buzz >= 0.66 { return "🔥 Hot" }
        if venue.buzz >= 0.33 { return "☀️ Warm" }
        return "😑 Meh"
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Venue Image
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 54, height: 54)
                if let ref = venue.photoReference {
                    AsyncImage(url: URL(string: "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(ref)&key=AIzaSyAuPBQCEYfG9C0wwH5MoHRbNe4xJ8Y_3zk")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else if phase.error != nil {
                            Image(systemName: "photo").resizable().scaledToFit().foregroundColor(.gray)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.pink)
                }
            }
            
            // Venue Details
            VStack(alignment: .leading, spacing: 4) {
                // Name and Badge
                HStack(spacing: 6) {
                    Text(venue.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let isOpen = venue.isOpenNow {
                        if !isOpen {
                            Text("🔒 Closed")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(6)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        } else {
                            Text(buzzText)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(buzzColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [buzzColor.opacity(0.2), buzzColor.opacity(0.1)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(6)
                                .shadow(color: buzzColor.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                
                // Rating and Price
                HStack(spacing: 8) {
                    Text(String(format: "%.1f ★", venue.rating))
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                    Text("(\(venue.reviews))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let price = venue.priceLevel {
                        Text(String(repeating: "$", count: price))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(Color.clear)
    }
}

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

extension VenueWithCrowd {
    var vibe: Vibe {
        guard let score = busynessScore else { return .chill }
        if score >= 0.66 { return .hot }
        if score >= 0.33 { return .mid }
        return .chill
    }
}

struct VenueDetailView: View {
    let venue: SimpleVenue
    let onClose: () -> Void
    @State private var isPlanning = false
    @State private var showShareSheet = false
    @State private var showPlanningSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(venue.name)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                
                // Venue Image
                if let ref = venue.photoReference {
                    AsyncImage(url: URL(string: "https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photoreference=\(ref)&key=AIzaSyAuPBQCEYfG9C0wwH5MoHRbNe4xJ8Y_3zk")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "photo").resizable().scaledToFit().foregroundColor(.gray)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Stats
                HStack(spacing: 8) {
                    Text(String(format: "%.1f ★", venue.rating))
                        .font(.title3)
                        .foregroundColor(.yellow)
                    Text("(\(venue.reviews))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    if let price = venue.priceLevel {
                        Text(String(repeating: "$", count: price))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Planning and Share Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        isPlanning = true
                        // Add planning logic here
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showPlanningSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showShareSheet = true
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: isPlanning ? "checkmark.circle.fill" : "calendar.badge.plus")
                            Text(isPlanning ? "Added to Plans!" : "I'm Planning")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPlanning ? Color.green : Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: (isPlanning ? Color.green : Color.pink).opacity(0.3), radius: 8)
                    }
                    .disabled(isPlanning)
                    
                    if showPlanningSuccess {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Plans")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: Color.purple.opacity(0.3), radius: 8)
                        }
                    }
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
            .background(BlurView(style: .systemMaterialDark))
            .cornerRadius(20)
            .padding()
            .shadow(radius: 16)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showShareSheet) {
            SharePlanView(venue: venue)
        }
    }
}

struct SharePlanView: View {
    let venue: SimpleVenue
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlatform: SocialPlatform = .instagram
    
    enum SocialPlatform: String, CaseIterable {
        case instagram = "Instagram"
        case snapchat = "Snapchat"
        case messages = "Messages"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preview Card
                VStack(spacing: 16) {
                    if let ref = venue.photoReference {
                        AsyncImage(url: URL(string: "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=\(ref)&key=AIzaSyAuPBQCEYfG9C0wwH5MoHRbNe4xJ8Y_3zk")) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I'm going to")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text(venue.name)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        HStack {
                            if let isOpen = venue.isOpenNow {
                                if isOpen {
                                    Text(venue.buzz >= 0.66 ? "Hot" : (venue.buzz >= 0.33 ? "Mid" : "Chill"))
                                        .font(.caption)
                                        .bold()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(venue.buzz >= 0.66 ? Color.red : (venue.buzz >= 0.33 ? Color.orange : Color.yellow))
                                        .cornerRadius(12)
                                }
                            }
                            Text("\(venue.rating, specifier: "%.1f") ★")
                                .foregroundColor(.yellow)
                            Text("(\(venue.reviews))")
                                .foregroundColor(.gray)
                        }
                        Text("Join me on Bondfyr!")
                            .font(.subheadline)
                            .foregroundColor(.pink)
                    }
                    .padding()
                }
                .background(Color.black)
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding()
                
                // Platform Selection
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(SocialPlatform.allCases, id: \.self) { platform in
                        Text(platform.rawValue).tag(platform)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Share Button
                Button(action: {
                    shareToSocialMedia()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share to \(selectedPlatform.rawValue)")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Share Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareToSocialMedia() {
        // Here we'll implement the actual sharing logic
        // For now, we'll just dismiss the sheet
        dismiss()
    }
}

// MARK: - Preview
struct VenueListView_Previews: PreviewProvider {
    static var previews: some View {
        VenueListView()
            .preferredColorScheme(.dark)
    }
}

struct SimpleVenue: Identifiable, Hashable {
    let id: String
    let name: String
    let rating: Double
    let reviews: Int
    let types: [String]
    let location: GooglePlacesResponse.Place.Location?
    let address: String
    let photos: [String]
    let buzz: Double
    let photoReference: String?
    let priceLevel: Int?
    let isOpenNow: Bool?
    
    var effectiveBuzz: Double {
        // If venue is closed, return a low buzz score
        if let isOpen = isOpenNow, !isOpen {
            return 0.1 // This will ensure it shows as "Chill"
        }
        return buzz
    }
    
    init(
        id: String,
        name: String,
        rating: Double,
        reviews: Int,
        types: [String],
        location: GooglePlacesResponse.Place.Location?,
        address: String,
        photos: [String],
        priceLevel: Int? = nil,
        isOpenNow: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.rating = rating
        self.reviews = reviews
        self.types = types
        self.location = location
        self.address = address
        self.photos = photos
        self.photoReference = photos.first
        self.priceLevel = priceLevel
        self.isOpenNow = isOpenNow
        
        // Calculate buzz score based on rating × reviews
        let score = rating * Double(reviews)
        // Normalize to 0-1 range assuming max score of 5 × 1000
        self.buzz = (score / (5.0 * 1000.0)).clamped(to: 0...1)
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SimpleVenue, rhs: SimpleVenue) -> Bool {
        return lhs.id == rhs.id
    }
}

struct GooglePlacesTextSearchResponse: Decodable {
    let results: [GooglePlace]
    let next_page_token: String?
}

struct GooglePlacePhoto: Decodable {
    let photo_reference: String
}

struct GooglePlace: Decodable {
    let place_id: String
    let name: String
    let types: [String]
    let rating: Double?
    let user_ratings_total: Int?
    let photos: [GooglePlacePhoto]?
    let opening_hours: OpeningHours?
    let price_level: Int?
}

struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]
}

struct GeocodingResult: Decodable {
    let geometry: Geometry
}

struct Geometry: Decodable {
    let location: Location
}

struct Location: Decodable {
    let lat: Double
    let lng: Double
}

struct OpeningHours: Decodable {
    let open_now: Bool
}

// MARK: - Models
struct GooglePlacesResponse: Decodable {
    let results: [Place]
    let status: String
    let next_page_token: String?
    let error_message: String?
    
    struct Place: Decodable {
        let place_id: String
        let name: String
        let rating: Double?
        let user_ratings_total: Int?
        let types: [String]?
        let geometry: Geometry?
        let formatted_address: String?
        let photos: [Photo]?
        let price_level: Int?
        let opening_hours: OpeningHours?
        
        struct Geometry: Decodable {
            let location: Location
        }
        
        struct Location: Decodable {
            let lat: Double
            let lng: Double
        }
        
        struct Photo: Decodable {
            let photo_reference: String
        }
    }
}

// MARK: - Helper Extensions
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
} 