import SwiftUI
import CoreLocation

enum Vibe: String, CaseIterable { case hot = "Hot", mid = "Mid", chill = "Chill" }
enum VenueSort: String, CaseIterable { case az = "A-Z", buzz = "Most Buzzing", distance = "Distance" }

struct VenueListView: View {
    @ObservedObject var mapManager = MapFirestoreManager.shared
    @ObservedObject var cityManager = CityManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var selectedVibe: Vibe = .hot
    @State private var busyOnly: Bool = false
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .hot
    @State private var showCityPicker = false
    @State private var isRefreshing = false
    @State private var selectedSort: VenueSort = .buzz
    @Namespace private var sortBarNamespace
    @State private var locationDenied: Bool = false
    
    let genres = ["All", "Bar", "Club"]
    
    enum SortOption: String, CaseIterable {
        case hot = "Hot", az = "A-Z"
    }
    
    private var hasConnectedSocial: Bool {
        authViewModel.currentUser?.instagramHandle != nil
    }
    
    // Always show all venues for the city, even if no crowd data
    private var allVenues: [VenueWithCrowd] {
        guard let selectedCity = cityManager.selectedCity else { return [] }
        return mapManager.venues.filter { $0.city == selectedCity }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search venues...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
        }
        .padding(10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var sortFilterBar: some View {
        let sorts: [VenueSort] = locationDenied ? [.az, .buzz] : VenueSort.allCases
        return HStack(spacing: 16) {
            ForEach(sorts, id: \ .self) { sort in
                Button(action: { selectedSort = sort }) {
                    VStack(spacing: 4) {
                        Text(sort.rawValue)
                            .fontWeight(selectedSort == sort ? .bold : .regular)
                            .foregroundColor(selectedSort == sort ? .pink : .gray)
                        if selectedSort == sort {
                            Capsule()
                                .fill(Color.pink)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "underline", in: sortBarNamespace)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var filteredVenues: [VenueWithCrowd] {
        let venues = allVenues.filter { searchText.isEmpty || $0.name.lowercased().contains(searchText.lowercased()) }
        switch selectedSort {
        case .az:
            return venues.sorted { (a: VenueWithCrowd, b: VenueWithCrowd) in a.name < b.name }
        case .buzz:
            return venues.sorted { (a: VenueWithCrowd, b: VenueWithCrowd) in (a.busynessScore ?? 0) > (b.busynessScore ?? 0) }
        case .distance:
            return venues.sorted { (a: VenueWithCrowd, b: VenueWithCrowd) in (a.distance ?? Double.greatestFiniteMagnitude) < (b.distance ?? Double.greatestFiniteMagnitude) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                BackgroundGradientView()
                
                VStack(spacing: 0) {
                    // City Selection Header
                    cityHeader
                        .padding(.horizontal)
                        .padding(.top)
                    if locationDenied {
                        Text("Location access is required for distance-based sorting. Please enable location in Settings.")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                    sortFilterBar
                    searchBar
                    
                    // Venue List
                    if cityManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredVenues.isEmpty {
                        emptyStateView
                    } else {
                        venueList
                    }
                }
                .navigationTitle("Nightlife Venues")
                .navigationBarHidden(true)
            }
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(
                selectedCity: Binding(
                    get: { cityManager.selectedCity ?? "" },
                    set: { cityManager.selectedCity = $0 }
                ),
                cities: cityManager.cities
            )
        }
        .onAppear {
            mapManager.startListening()
            if cityManager.selectedCity == nil {
                cityManager.detectUserCity { _ in }
            }
            checkLocationPermission()
        }
        .onDisappear {
            mapManager.stopListening()
        }
    }
    
    private var cityHeader: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(.pink)
            Text(cityManager.selectedCity ?? "No City Selected")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "building.2.crop.circle")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)
            Text("No venues found in your city.")
                .foregroundColor(.gray)
                .font(.headline)
            if cityManager.selectedCity == nil {
                Button(action: { showCityPicker = true }) {
                    Text("Select a City")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.pink)
                        .cornerRadius(8)
                }
            }
            Spacer()
        }
    }
    
    private var venueList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredVenues) { venue in
                    VenueCardView(venue: venue, hasConnectedSocial: hasConnectedSocial)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
        .refreshable {
            isRefreshing = true
            mapManager.refreshVenues()
            isRefreshing = false
        }
    }
    
    private func vibeColor(_ vibe: Vibe) -> Color {
        switch vibe {
        case .hot: return .red
        case .mid: return .orange
        case .chill: return .blue
        }
    }
    
    private func checkLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        if status == .denied || status == .restricted {
            locationDenied = true
            if selectedSort == .distance {
                selectedSort = .buzz
            }
        } else {
            locationDenied = false
        }
    }
}

struct VenueCardView: View {
    let venue: VenueWithCrowd
    let hasConnectedSocial: Bool
    
    @State private var ugcThumb: String? = nil
    @State private var checkInSuccess: Bool = false
    @State private var checkInError: String? = nil
    @State private var showingSocialPrompt = false
    
    var body: some View {
        ZStack {
            BlurView(style: .systemMaterialDark)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 8)
            
            VStack(spacing: 12) {
                // Venue Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(venue.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let estimate = venue.currentCrowdEstimate {
                            Text("\(estimate) people here now")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Genre badge
                    Text(venue.genre)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.pink.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Social Features Section
                if hasConnectedSocial {
                    socialFeaturesView
                } else {
                    connectSocialPrompt
                }
                
                // Action Buttons
                HStack {
                    Button(action: checkIn) {
                        Text("Check In")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.pink)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    AnimatedCrowdIndicator(score: venue.busynessScore ?? 0)
                }
            }
            .padding()
        }
        .alert("Connect Social", isPresented: $showingSocialPrompt) {
            Button("Connect Now", role: .none) {
                // Navigate to profile
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Connect Instagram to see where your friends are headed!")
        }
    }
    
    private var socialFeaturesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friends Here")
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                // Friend avatars would go here
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                Text("No friends here yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
    }
    
    private var connectSocialPrompt: some View {
        Button(action: { showingSocialPrompt = true }) {
            HStack {
                Image(systemName: "person.2")
                Text("Connect social to see friends")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.caption)
            .foregroundColor(.gray)
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func checkIn() {
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
}

struct CityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCity: String
    let cities: [String]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(cities, id: \.self) { city in
                    Button(action: {
                        selectedCity = city
                        dismiss()
                    }) {
                        HStack {
                            Text(city)
                            Spacer()
                            if city == selectedCity {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.pink)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select City")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct AnimatedCrowdIndicator: View {
    let score: Double
    @State private var animate = false
    
    var color: Color {
        switch score {
        case 0..<0.33: return .green
        case 0.33..<0.66: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .shadow(color: color.opacity(0.7), radius: animate ? 10 : 2)
            .scaleEffect(animate ? 1.2 : 1.0)
            .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
            .onAppear { animate = true }
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

// MARK: - Preview
struct VenueListView_Previews: PreviewProvider {
    static var previews: some View {
        VenueListView()
            .preferredColorScheme(.dark)
    }
} 