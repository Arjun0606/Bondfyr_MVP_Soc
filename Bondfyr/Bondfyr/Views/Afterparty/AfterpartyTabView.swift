import SwiftUI
import CoreLocation
import FirebaseFirestore
import CoreLocationUI

// MARK: - Header Components
struct CityPickerView: View {
    let currentCity: String?
    let authorizationStatus: CLAuthorizationStatus
    let onLocationDenied: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.pink)
            if authorizationStatus == .denied {
                Text("Location Access Required")
                    .foregroundColor(.red)
            } else {
                Text(currentCity ?? "Loading...")
                    .font(.headline)
            }
            Spacer()
        }
        .padding(.horizontal)
        .onTapGesture {
            if authorizationStatus == .denied {
                onLocationDenied()
            }
        }
    }
}

struct SearchBarView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search afterparties...", text: $searchText)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct DistanceSliderView: View {
    @Binding var selectedRadius: Double
    let onRadiusChange: (Double) -> Void
    @State private var isEditing = false
    
    private var formattedDistance: String {
        if selectedRadius == 0 {
            return "Current location"
        } else if selectedRadius.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(selectedRadius)) miles"
        } else {
            return String(format: "%.1f miles", selectedRadius)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Distance: \(formattedDistance)")
                .font(.subheadline)
                .foregroundColor(.gray)
            Slider(
                value: $selectedRadius,
                in: 0...15,
                step: 0.5,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        // Only update when user finishes sliding
                        onRadiusChange(selectedRadius)
                    }
                }
            )
        }
        .padding(.horizontal)
    }
}

// First, make Afterparty conform to Equatable
extension Afterparty: Equatable {
    static func == (lhs: Afterparty, rhs: Afterparty) -> Bool {
        lhs.id == rhs.id
    }
}

struct CreateAfterpartyButton: View {
    let hasActiveParty: Bool
    let onCreateTap: () -> Void
    
    var body: some View {
        Button(action: onCreateTap) {
            HStack {
                Image(systemName: "plus.circle.fill")
                        Text("Create Afterparty")
            }
                                            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Group {
                    if hasActiveParty {
                        Color.gray
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [.pink, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .foregroundColor(.white)
            .cornerRadius(15)
            .opacity(hasActiveParty ? 0.7 : 1.0)
        }
        .padding(.horizontal)
        .disabled(hasActiveParty)
    }
}

// MARK: - Main View
struct AfterpartyTabView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingCreateSheet = false
    @State private var searchText = ""
    @State private var selectedRadius: Double = 5.0
    @State private var showLocationDeniedAlert = false
    @State private var showingActivePartyAlert = false
    @State private var hasActiveParty = false
    @State private var isUpdatingRadius = false
    @State private var lastFetchRadius: Double = 15.0 // Track the radius used for last fetch
    
    // MARK: - New Marketplace Features
    @State private var showingFilters = false
    @State private var marketplaceAfterparties: [Afterparty] = []
    @State private var currentFilters: MarketplaceFilters = MarketplaceFilters(
        priceRange: 5...200,
        vibes: [],
        timeFilter: .all,
        showOnlyAvailable: true,
        maxGuestCount: 200
    )
    @State private var isLoadingMarketplace = false
    
    private var filteredAfterparties: [Afterparty] {
        guard let userLocation = locationManager.location?.coordinate else {
            return afterpartyManager.nearbyAfterparties
        }
        
        return afterpartyManager.nearbyAfterparties.filter { afterparty in
            let afterpartyLocation = CLLocation(
                latitude: afterparty.coordinate.latitude,
                longitude: afterparty.coordinate.longitude
            )
            let userCLLocation = CLLocation(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            let distance = afterpartyLocation.distance(from: userCLLocation) / 1609.34 // Convert meters to miles
            return distance <= selectedRadius
        }
    }
    
    // Check if any filters are active (different from defaults)
    private var hasActiveFilters: Bool {
        return currentFilters.priceRange != 5...200 ||
               !currentFilters.vibes.isEmpty ||
               currentFilters.timeFilter != .all ||
               currentFilters.showOnlyAvailable != true ||
               currentFilters.maxGuestCount != 200
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // MARK: - Marketplace Header
                VStack(spacing: 12) {
                    // City and Filter Button
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Party Discovery")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.pink)
                                if locationManager.authorizationStatus == .denied {
                                    Text("Location Access Required")
                                        .foregroundColor(.red)
                                } else {
                                    Text(locationManager.currentCity ?? "Loading...")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Filter button with active indicator
                        Button(action: { showingFilters = true }) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text("Filter")
                                if hasActiveFilters {
                                    Circle()
                                        .fill(Color.pink)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(hasActiveFilters ? Color.pink : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                    }
                    
                    // Search and stats
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search parties...", text: $searchText)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        // Active parties count
                        VStack {
                            Text("\(marketplaceAfterparties.count)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("live")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                    .padding(.horizontal)
                
                DistanceSliderView(
                    selectedRadius: $selectedRadius,
                    onRadiusChange: { radius in
                        if radius > lastFetchRadius {
                            if let location = locationManager.location?.coordinate {
                                Task {
                                    await afterpartyManager.updateLocation(location)
                                    lastFetchRadius = radius
                                }
                            }
                        }
                    }
                )
                
                CreateAfterpartyButton(
                    hasActiveParty: hasActiveParty,
                    onCreateTap: {
                        if hasActiveParty {
                            showingActivePartyAlert = true
                        } else if locationManager.authorizationStatus == .denied {
                            showLocationDeniedAlert = true
                        } else {
                            showingCreateSheet = true
                        }
                    }
                )
                
                if isLoadingMarketplace {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else if marketplaceAfterparties.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 60))
                                .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("No paid parties yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text("Be the first to host a party in \(locationManager.currentCity ?? "your area") and start earning!")
                                .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        }
                        
                        Button("Host a Paid Party") {
                            if hasActiveParty {
                                showingActivePartyAlert = true
                            } else if locationManager.authorizationStatus == .denied {
                                showLocationDeniedAlert = true
                            } else {
                                showingCreateSheet = true
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                                .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(marketplaceAfterparties) { afterparty in
                                AfterpartyCard(afterparty: afterparty)
                            }
                        }
                                .padding()
                    }
                }
            }
            .background(Color.black)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreateSheet) {
            CreateAfterpartyView(
                currentLocation: locationManager.location?.coordinate,
                currentCity: locationManager.currentCity ?? ""
            )
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation?.coordinate {
                Task {
                    await afterpartyManager.updateLocation(location)
                    lastFetchRadius = 15.0 // Reset fetch radius when location changes
                }
            }
        }
        .onChange(of: afterpartyManager.nearbyAfterparties) { _ in
            Task {
                if let isActive = try? await afterpartyManager.hasActiveAfterparty() {
                    hasActiveParty = isActive
                }
            }
        }
        .task {
            if let isActive = try? await afterpartyManager.hasActiveAfterparty() {
                hasActiveParty = isActive
            }
        }
        .alert("Active Afterparty Exists", isPresented: $showingActivePartyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
            Text("You already have an active afterparty. Please wait for it to end or stop it before creating a new one.")
        }
        .alert("Location Access Required", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location services in Settings to use this feature.")
        }
        .sheet(isPresented: $showingFilters) {
            MarketplaceFiltersView(
                isPresented: $showingFilters,
                currentFilters: currentFilters
            ) { filters in
                currentFilters = filters
                Task {
                    await loadMarketplaceAfterparties(with: filters)
                }
            }
        }
        .task {
            await loadMarketplaceAfterparties()
        }
    }
    
    // MARK: - Marketplace Data Loading
    private func loadMarketplaceAfterparties(with filters: MarketplaceFilters? = nil) async {
        isLoadingMarketplace = true
        defer { isLoadingMarketplace = false }
        
        // Use provided filters or current filters
        let activeFilters = filters ?? currentFilters
        
        // Always show sample parties for demo, regardless of Firebase errors
        let sampleParties = createSampleParties()
        
        var afterparties: [Afterparty] = []
        
        // Try to get real parties, but don't fail if Firebase has issues
        do {
            afterparties = try await afterpartyManager.getMarketplaceAfterparties(
                priceRange: activeFilters.priceRange,
                vibes: activeFilters.vibes,
                timeFilter: activeFilters.timeFilter
            )
        } catch {
            print("Firebase error (showing sample data anyway): \(error)")
            // Continue with just sample parties
        }
        
        // Combine real parties with sample data for demo
        let allParties = afterparties + sampleParties
            
            // Apply additional client-side filters
            var filteredResults = allParties
            
            // Apply price range filter
            filteredResults = filteredResults.filter { afterparty in
                afterparty.ticketPrice >= activeFilters.priceRange.lowerBound &&
                afterparty.ticketPrice <= activeFilters.priceRange.upperBound
            }
            
            // Apply vibe filters
            if !activeFilters.vibes.isEmpty {
                filteredResults = filteredResults.filter { afterparty in
                    let partyVibes = afterparty.vibeTag.components(separatedBy: ", ")
                    return activeFilters.vibes.contains { selectedVibe in
                        partyVibes.contains { partyVibe in
                            partyVibe.localizedCaseInsensitiveContains(selectedVibe) ||
                            selectedVibe.localizedCaseInsensitiveContains(partyVibe)
                        }
                    }
                }
            }
            
            if activeFilters.showOnlyAvailable {
                filteredResults = filteredResults.filter { !$0.isSoldOut }
            }
            
            filteredResults = filteredResults.filter { $0.maxGuestCount <= activeFilters.maxGuestCount }
            
            // Apply search filter
            if !searchText.isEmpty {
                filteredResults = filteredResults.filter { afterparty in
                    afterparty.title.localizedCaseInsensitiveContains(searchText) ||
                    afterparty.locationName.localizedCaseInsensitiveContains(searchText) ||
                    afterparty.vibeTag.localizedCaseInsensitiveContains(searchText) ||
                    afterparty.hostHandle.localizedCaseInsensitiveContains(searchText)
                }
            }
            
            await MainActor.run {
                marketplaceAfterparties = filteredResults
            }
        
        await MainActor.run {
            marketplaceAfterparties = filteredResults
            print("🎉 Loaded \(filteredResults.count) parties (including \(sampleParties.count) sample parties)")
        }
    }
    
    // MARK: - Sample Data for Testing
    private func createSampleParties() -> [Afterparty] {
        let now = Date()
        let calendar = Calendar.current
        
        // Use current city and nearby coordinates
        let currentCity = locationManager.currentCity ?? "Pune"
        let baseCoordinate = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 18.4955, longitude: 73.9040)
        
        return [
            // 1. Rooftop Party - Premium pricing
            Afterparty(
                id: "sample-1",
                userId: "host-1",
                hostHandle: "mike_parties",
                coordinate: CLLocationCoordinate2D(latitude: baseCoordinate.latitude + 0.001, longitude: baseCoordinate.longitude + 0.001),
                radius: 1000,
                startTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 6, to: now) ?? now,
                city: currentCity,
                locationName: "Luxury Rooftop Loft",
                description: "Epic rooftop party with DJ, open bar, and amazing city views! Dress code enforced.",
                address: "123 MG Road, \(currentCity)",
                googleMapsLink: "https://maps.google.com/?q=123+MG+Road+\(currentCity)",
                vibeTag: "Rooftop, Dress Code, Dancing",
                activeUsers: ["user-1", "user-2", "user-3", "user-4", "user-5", "user-6", "user-7", "user-8", "user-9", "user-10", "user-11", "user-12", "user-13", "user-14", "user-15"],
                pendingRequests: ["guest-1"],
                createdAt: calendar.date(byAdding: .hour, value: -1, to: now) ?? now,
                title: "🌆 Skyline Rooftop Bash",
                ticketPrice: 45.0,
                coverPhotoURL: nil,
                maxGuestCount: 80,
                visibility: .publicFeed,
                approvalType: .manual,
                ageRestriction: 21,
                maxMaleRatio: 0.6,
                legalDisclaimerAccepted: true,
                venmoHandle: "@mike-rooftop",
                guestRequests: [
                    GuestRequest(userId: "guest-1", userName: "Sarah K", userHandle: "sarah_k", requestedAt: now, paymentStatus: .pending),
                    GuestRequest(userId: "guest-2", userName: "Alex M", userHandle: "alex_m", requestedAt: calendar.date(byAdding: .minute, value: -15, to: now) ?? now, paymentStatus: .paid)
                ]
            ),
            
            // 2. House Party - Mid-range pricing
            Afterparty(
                id: "sample-2", 
                userId: "host-2",
                hostHandle: "party_queen",
                coordinate: CLLocationCoordinate2D(latitude: baseCoordinate.latitude + 0.002, longitude: baseCoordinate.longitude - 0.001),
                radius: 1000,
                startTime: calendar.date(byAdding: .hour, value: 4, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 8, to: now) ?? now,
                city: currentCity,
                locationName: "Cozy Mission House",
                description: "Chill house party with beer pong, good vibes, and friendly crowd. BYOB welcome!",
                address: "456 FC Road, \(currentCity)",
                googleMapsLink: "https://maps.google.com/?q=456+FC+Road+\(currentCity)",
                vibeTag: "House Party, BYOB, Games",
                activeUsers: ["user-a", "user-b", "user-c", "user-d", "user-e", "user-f", "user-g", "user-h"],
                pendingRequests: [],
                createdAt: calendar.date(byAdding: .minute, value: -30, to: now) ?? now,
                title: "🏠 Mission House Vibes",
                ticketPrice: 15.0,
                coverPhotoURL: nil,
                maxGuestCount: 35,
                visibility: .publicFeed,
                approvalType: .automatic,
                ageRestriction: 18,
                maxMaleRatio: 0.7,
                legalDisclaimerAccepted: true,
                venmoHandle: "@party-queen",
                guestRequests: [
                    GuestRequest(userId: "guest-3", userName: "Jordan P", userHandle: "jordan_p", requestedAt: calendar.date(byAdding: .minute, value: -10, to: now) ?? now, paymentStatus: .paid)
                ]
            ),
            
            // 3. Pool Party - Higher capacity
            Afterparty(
                id: "sample-3",
                userId: "host-3", 
                hostHandle: "poolside_steve",
                coordinate: CLLocationCoordinate2D(latitude: baseCoordinate.latitude - 0.001, longitude: baseCoordinate.longitude + 0.002),
                radius: 1000,
                startTime: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .hour, value: 6, to: now) ?? now) ?? now,
                city: currentCity,
                locationName: "Private Pool Villa",
                description: "Day party by the pool! Bring swimwear, sunscreen, and good energy. Pool floaties provided!",
                address: "789 Koregaon Park, \(currentCity)", 
                googleMapsLink: "https://maps.google.com/?q=789+Koregaon+Park+\(currentCity)",
                vibeTag: "Pool, Backyard, Chill",
                activeUsers: ["user-x", "user-y", "user-z", "user-1a", "user-2a", "user-3a"],
                pendingRequests: ["guest-5"],
                createdAt: calendar.date(byAdding: .minute, value: -45, to: now) ?? now,
                title: "🏊‍♀️ Poolside Paradise",
                ticketPrice: 25.0,
                coverPhotoURL: nil,
                maxGuestCount: 60,
                visibility: .publicFeed,
                approvalType: .manual,
                ageRestriction: nil,
                maxMaleRatio: 0.5,
                legalDisclaimerAccepted: true,
                venmoHandle: "@poolside-steve",
                guestRequests: [
                    GuestRequest(userId: "guest-4", userName: "Emma R", userHandle: "emma_r", requestedAt: calendar.date(byAdding: .minute, value: -20, to: now) ?? now, paymentStatus: .paid),
                    GuestRequest(userId: "guest-5", userName: "Tyler B", userHandle: "tyler_b", requestedAt: calendar.date(byAdding: .minute, value: -5, to: now) ?? now, paymentStatus: .pending)
                ]
            ),
            
            // 4. Exclusive Party - Premium pricing
            Afterparty(
                id: "sample-4",
                userId: "host-4",
                hostHandle: "vip_nights", 
                coordinate: CLLocationCoordinate2D(latitude: baseCoordinate.latitude + 0.003, longitude: baseCoordinate.longitude + 0.003),
                radius: 1000,
                startTime: calendar.date(byAdding: .hour, value: 8, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 12, to: now) ?? now,
                city: currentCity,
                locationName: "Penthouse Suite",
                description: "Ultra-exclusive penthouse party. Bottle service, professional DJ, strict guest list. Limited spots!",
                address: "101 Bund Garden, \(currentCity)",
                googleMapsLink: "https://maps.google.com/?q=101+Bund+Garden+\(currentCity)",
                vibeTag: "Exclusive, Lounge, Dress Code",
                activeUsers: ["vip-1", "vip-2", "vip-3", "vip-4", "vip-5", "vip-6", "vip-7", "vip-8", "vip-9", "vip-10"],
                pendingRequests: [],
                createdAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                title: "💎 VIP Penthouse Experience",
                ticketPrice: 85.0,
                coverPhotoURL: nil,
                maxGuestCount: 25,
                visibility: .publicFeed,
                approvalType: .manual,
                ageRestriction: 21,
                maxMaleRatio: 0.4,
                legalDisclaimerAccepted: true,
                venmoHandle: "@vip-nights",
                guestRequests: [
                    GuestRequest(userId: "guest-6", userName: "Sophia L", userHandle: "sophia_l", requestedAt: calendar.date(byAdding: .minute, value: -25, to: now) ?? now, paymentStatus: .paid)
                ]
            ),
            
            // 5. Frat Party - Budget-friendly
            Afterparty(
                id: "sample-5",
                userId: "host-5",
                hostHandle: "kappa_kyle",
                coordinate: CLLocationCoordinate2D(latitude: baseCoordinate.latitude - 0.002, longitude: baseCoordinate.longitude - 0.002),
                radius: 1000,
                startTime: calendar.date(byAdding: .hour, value: 6, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 10, to: now) ?? now,
                city: currentCity, 
                locationName: "College Hostel",
                description: "Classic college party! Beer pong tournaments, loud music, and good times. Come ready to party!",
                address: "202 University Road, \(currentCity)",
                googleMapsLink: "https://maps.google.com/?q=202+University+Road+\(currentCity)",
                vibeTag: "Frat, Games, Dancing",
                activeUsers: Array(1...25).map { "frat-\($0)" },
                pendingRequests: [],
                createdAt: calendar.date(byAdding: .minute, value: -60, to: now) ?? now,
                title: "🍺 Sigma Chi Bash",
                ticketPrice: 8.0,
                coverPhotoURL: nil,
                maxGuestCount: 120,
                visibility: .publicFeed,
                approvalType: .automatic,
                ageRestriction: 18,
                maxMaleRatio: 0.8,
                legalDisclaimerAccepted: true,
                venmoHandle: "@kappa-kyle",
                guestRequests: []
            )
        ]
    }
}

// MARK: - Action Buttons View (Extracted to fix type-checking)
struct ActionButtonsView: View {
    let afterparty: Afterparty
    let isHost: Bool
    @State private var isJoining = false
    @Binding var showingGuestList: Bool
    @Binding var showingEditSheet: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingShareSheet: Bool
    @Binding var showingContactHost: Bool
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            if isHost {
                hostControlsMenu
            } else {
                guestActionButton
            }
            
            shareButton
        }
    }
    
    private var hostControlsMenu: some View {
        Menu {
            Button(action: { showingGuestList = true }) {
                Label("Manage Guests (\(afterparty.guestRequests.count))", systemImage: "person.2.fill")
            }
            
            Button(action: { showingEditSheet = true }) {
                Label("Edit Party", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                Label("Cancel Party", systemImage: "xmark.circle")
                    .foregroundColor(.red)
            }
        } label: {
            HStack {
                Text("Manage")
                Image(systemName: "chevron.down")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }
    
    private var guestActionButton: some View {
        let userId = authViewModel.currentUser?.uid ?? ""
        let hasRequested = afterparty.guestRequests.contains { $0.userId == userId }
        let isConfirmed = afterparty.activeUsers.contains(userId)
        
        return Button(action: {
            if !hasRequested && !isConfirmed {
                // TESTFLIGHT VERSION: Show contact host sheet
                showingContactHost = true
            }
        }) {
            HStack {
                if isJoining {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    guestButtonContent(hasRequested: hasRequested, isConfirmed: isConfirmed)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(guestButtonBackground(hasRequested: hasRequested, isConfirmed: isConfirmed))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .disabled(isJoining || hasRequested || isConfirmed || afterparty.isSoldOut)
    }
    
    @ViewBuilder
    private func guestButtonContent(hasRequested: Bool, isConfirmed: Bool) -> some View {
        if isConfirmed {
            Image(systemName: "checkmark.circle.fill")
            Text("Going")
        } else if hasRequested {
            Image(systemName: "clock.fill")
            Text("Pending")
        } else if afterparty.isSoldOut {
            Image(systemName: "xmark.circle.fill")
            Text("Sold Out")
        } else {
            // TESTFLIGHT VERSION: Contact host for payment
            Image(systemName: "message.circle.fill")
            Text("Contact Host ($\(Int(afterparty.ticketPrice)))")
        }
    }
    
    private func guestButtonBackground(hasRequested: Bool, isConfirmed: Bool) -> AnyView {
        if isConfirmed {
            return AnyView(Color.green)
        } else if hasRequested {
            return AnyView(Color.orange)
        } else if afterparty.isSoldOut {
            return AnyView(Color.gray)
        } else {
            return AnyView(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
        }
    }
    
    private var shareButton: some View {
        Button(action: { showingShareSheet = true }) {
            Image(systemName: "square.and.arrow.up")
                .padding(8)
                .background(Color(.systemGray6))
                .foregroundColor(.white)
                .cornerRadius(20)
        }
    }
}

struct AfterpartyCard: View {
    let afterparty: Afterparty
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var showingGuestList = false
    @State private var showingEditSheet = false
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingContactHost = false // TESTFLIGHT: Contact host sheet
    
    private var isHost: Bool {
        afterparty.userId == authViewModel.currentUser?.uid
    }
    
    private var timeRemaining: String {
        let now = Date()
        let endTime = afterparty.endTime
        let creationTime = afterparty.createdAt
        
        // If more than 9 hours have passed since creation, show expired
        let nineHoursFromCreation = Calendar.current.date(byAdding: .hour, value: 9, to: creationTime) ?? Date()
        if now >= nineHoursFromCreation {
            return "Expired"
        }
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: nineHoursFromCreation)
        if let hours = components.hour, let minutes = components.minute {
            if hours > 0 {
                return "Expires in \(hours)h \(minutes)m"
            } else {
                return "Expires in \(minutes)m"
            }
        }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Cover Photo & Price Header
            ZStack(alignment: .topTrailing) {
                // Cover photo or placeholder
                if let coverURL = afterparty.coverPhotoURL {
                    AsyncImage(url: URL(string: coverURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemGray4)
                    }
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.purple.opacity(0.8),
                                    Color.pink.opacity(0.6),
                                    Color.orange.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150) // Increased height for more impact
                        .overlay(
                            VStack {
                                Image(systemName: "party.popper.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                Text(afterparty.title)
                        .font(.headline)
                        .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                        )
                }
                
                // Price tag
                VStack(spacing: 4) {
                    Text("$\(Int(afterparty.ticketPrice))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                
                    if isHost {
                        Text("$\(Int(afterparty.ticketPrice * 0.88))")
                    .font(.caption)
                            .foregroundColor(.green)
                            .overlay(
                                Text("your cut")
                                    .font(.caption2)
                                    .foregroundColor(.green.opacity(0.8))
                                    .offset(y: 12)
                            )
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(.trailing, 8)
                .padding(.top, 8)
            }
            
            // Party title and location
            VStack(alignment: .leading, spacing: 4) {
                Text(afterparty.title)
                    .font(.title3) // Larger font for more emphasis
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
            HStack {
                    Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                                    .foregroundColor(.gray)
                    Text(afterparty.locationName)
                        .font(.subheadline)
                                    .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            // Vibe tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(afterparty.vibeTag.components(separatedBy: ", "), id: \.self) { vibe in
                        Text(vibe)
                    .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.3))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 1)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Party stats and info
            HStack {
                // Guest capacity
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(afterparty.confirmedGuestsCount)/\(afterparty.maxGuestCount) Guests", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if afterparty.isSoldOut {
                        Text("SOLD OUT")
                            .font(.caption)
                            .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                }
                
                Spacer()
                
                // Host info
                VStack(alignment: .trailing, spacing: 4) {
                    Text("@\(afterparty.hostHandle)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text("Host")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Action buttons
            ActionButtonsView(
                afterparty: afterparty,
                isHost: isHost,
                showingGuestList: $showingGuestList,
                showingEditSheet: $showingEditSheet,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                showingShareSheet: $showingShareSheet,
                showingContactHost: $showingContactHost
            )
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingGuestList) {
            GuestListView(afterparty: afterparty)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAfterpartyView(afterparty: afterparty)
        }
        .sheet(isPresented: $showingShareSheet) {
            let message = isHost ? 
                "Hosting an afterparty at \(afterparty.locationName)! Join me!" :
                "Heading to \(afterparty.hostHandle)'s afterparty at \(afterparty.locationName)!"
            ShareSheet(activityItems: [message])
        }
        .sheet(isPresented: $showingContactHost) {
            ContactHostSheet(afterparty: afterparty, isJoining: $isJoining)
        }
        .alert("Stop Invitation?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                Task {
                    do {
                        try await afterpartyManager.deleteAfterparty(afterparty)
                    } catch {
                        print("Error stopping invitation: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to stop this invitation? This action cannot be undone.")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// Guest Row Views
struct AcceptedGuestRow: View {
    let userId: String
    let afterpartyId: String
    let onRemove: () -> Void
    
    var body: some View {
            HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.gray)
            Text(userId)
                    .foregroundColor(.white)
            
                Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

struct PendingGuestRow: View {
    let userId: String
    let onAccept: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
            HStack {
            Image(systemName: "person.circle.fill")
            .foregroundColor(.gray)
            Text(userId)
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Accept", action: onAccept)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            
            Button("Deny", action: onDeny)
                .buttonStyle(.bordered)
                .tint(.red)
        }
    }
}

struct AddGuestSheet: View {
    @Binding var isPresented: Bool
    @Binding var guestHandle: String
    let onAdd: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Guest")) {
                    TextField("Guest Handle", text: $guestHandle)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Add Guest")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Add", action: onAdd)
                    .disabled(guestHandle.isEmpty)
            )
        }
        .preferredColorScheme(.dark)
    }
}

struct GuestListView: View {
    let afterparty: Afterparty
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingAddGuestSheet = false
    @State private var newGuestHandle = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Accepted Guests (\(afterparty.activeUsers.count))") {
                    ForEach(afterparty.activeUsers, id: \.self) { userId in
                        AcceptedGuestRow(
                            userId: userId,
                            afterpartyId: afterparty.id
                        ) {
                            Task {
                                do {
                                    try await afterpartyManager.removeGuest(afterpartyId: afterparty.id, userId: userId)
                                    alertMessage = "Guest removed successfully!"
                                    showingAlert = true
                                } catch {
                                    alertMessage = "Failed to remove guest: \(error.localizedDescription)"
                                    showingAlert = true
                                }
                            }
                        }
                    }
                    
                    Button(action: { showingAddGuestSheet = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Guest")
                        }
                    }
                }
                
                Section("Pending Requests (\(afterparty.pendingRequests.count))") {
                    ForEach(afterparty.pendingRequests, id: \.self) { userId in
                        PendingGuestRow(
                            userId: userId,
                            onAccept: {
                                Task {
                                    do {
                                        try await afterpartyManager.approveRequest(afterpartyId: afterparty.id, userId: userId)
                                        alertMessage = "Guest approved successfully!"
                                        showingAlert = true
                                    } catch {
                                        alertMessage = "Failed to approve guest: \(error.localizedDescription)"
                                        showingAlert = true
                                    }
                                }
                            },
                            onDeny: {
                    Task {
                        do {
                                        try await afterpartyManager.denyRequest(afterpartyId: afterparty.id, userId: userId)
                                        alertMessage = "Request denied successfully!"
                                        showingAlert = true
                        } catch {
                                        alertMessage = "Failed to deny request: \(error.localizedDescription)"
                                        showingAlert = true
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Guest List")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() })
        }
        .preferredColorScheme(.dark)
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddGuestSheet) {
            AddGuestSheet(
                isPresented: $showingAddGuestSheet,
                guestHandle: $newGuestHandle
            ) {
                Task {
                    do {
                        try await afterpartyManager.addGuest(afterpartyId: afterparty.id, guestHandle: newGuestHandle)
                        showingAddGuestSheet = false
                        alertMessage = "Guest added successfully!"
                        showingAlert = true
                        newGuestHandle = ""
                    } catch {
                        alertMessage = "Failed to add guest: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        }
    }
}

struct EditAfterpartyView: View {
    let afterparty: Afterparty
    @Environment(\.presentationMode) var presentationMode
    @State private var description = ""
    @State private var address = ""
    @State private var googleMapsLink = ""
    @State private var showingSaveError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Address", text: $address)
                    TextField("Google Maps Link", text: $googleMapsLink)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
        }
        .onAppear {
                // Load existing values
                description = afterparty.description
                address = afterparty.address
                googleMapsLink = afterparty.googleMapsLink
            }
            .navigationTitle("Edit Afterparty")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    // TODO: Implement save functionality
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .preferredColorScheme(.dark)
    }
}

struct CreateAfterpartyView: View {
    let currentLocation: CLLocationCoordinate2D?
    let currentCity: String
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var selectedVibes: Set<String> = []
    @State private var startTime = Date().addingTimeInterval(3600)
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
    @State private var address = ""
    @State private var googleMapsLink = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedDay: String
    
    // MARK: - New Marketplace Fields
    @State private var title = ""
    @State private var ticketPrice: Double = 10.0
    @State private var coverPhotoURL: String = ""
    @State private var coverPhotoImage: UIImage? = nil
    @State private var maxGuestCount: Int = 25
    @State private var visibility: PartyVisibility = .publicFeed
    @State private var approvalType: ApprovalType = .manual
    @State private var ageRestriction: Int? = nil
    @State private var maxMaleRatio: Double = 1.0
    @State private var legalDisclaimerAccepted = false
    @State private var showImagePicker = false
    
    // MARK: - Enhanced Date/Time Selection
    @State private var selectedDate = Date()
    @State private var customStartTime = Date().addingTimeInterval(3600)
    @State private var customEndTime = Date().addingTimeInterval(3600 * 5)
    
    // MARK: - TESTFLIGHT: Payment Details
    @State private var venmoHandle = ""
    
    init(currentLocation: CLLocationCoordinate2D?, currentCity: String) {
        self.currentLocation = currentLocation
        self.currentCity = currentCity
        
        // Initialize selectedDay based on available slots
        let calendar = Calendar.current
        let now = Date()
        var nextHour = calendar.date(bySetting: .minute, value: 0, of: now) ?? now
        nextHour = calendar.date(byAdding: .hour, value: 1, to: nextHour) ?? now
        
        // Check if next hour is still today
        let isNextHourToday = calendar.isDate(nextHour, inSameDayAs: now)
        _selectedDay = State(initialValue: isNextHourToday ? "today" : "tomorrow")
    }
    
    let vibeOptions = [
        "BYOB",
        "Frat", 
        "420",
        "Pool",
        "Rooftop",
        "All-Girls",
        "Dress Code",
        "💊",
        "Lounge",
        "House Party",
        "Dorm Party",
        "Backyard",
        "Exclusive",
        "Games",
        "Dancing",
        "Chill"
    ]
    
    // Calculate available time slots based on current time
    private var timeSlots: [(Date, Bool)] {
        let calendar = Calendar.current
        let now = Date()
        
        var slots: [(Date, Bool)] = []
        
        // Round up to the next hour
        var nextHour = calendar.date(bySetting: .minute, value: 0, of: now) ?? now
        nextHour = calendar.date(byAdding: .hour, value: 1, to: nextHour) ?? now
        
        // Generate slots for exactly 9 hours from the next hour
        for hourOffset in 0...8 {
            if let slotTime = calendar.date(byAdding: .hour, value: hourOffset, to: nextHour) {
                // A time slot is considered "today" if it's on the same calendar day as now
                let isToday = calendar.isDate(slotTime, inSameDayAs: now)
                slots.append((slotTime, isToday))
            }
        }
        
        return slots
    }
    
    private var todaySlots: [Date] {
        timeSlots.filter { $0.1 }.map { $0.0 }
    }
    
    private var tomorrowSlots: [Date] {
        timeSlots.filter { !$0.1 }.map { $0.0 }
    }
    
    // MARK: - Form Validation
    private var isFormValid: Bool {
        return !title.isEmpty &&
               !selectedVibes.isEmpty &&
               !address.isEmpty &&
               !venmoHandle.isEmpty && // TESTFLIGHT: Require Venmo handle
               ticketPrice >= 5.0 && // Minimum $5
               maxGuestCount >= 5 && // Minimum 5 guests
               legalDisclaimerAccepted // Must accept legal responsibility
    }
    
    // MARK: - Computed Properties
    private var createButtonBackground: AnyView {
        if isFormValid {
            return AnyView(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                                        } else {
            return AnyView(LinearGradient(gradient: Gradient(colors: [.gray, .gray]), startPoint: .leading, endPoint: .trailing))
                                }
                            }
    
    var body: some View {
        NavigationView {
                ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Party Title & Price (Required)
                    PartyDetailsSection(
                        title: $title,
                        ticketPrice: $ticketPrice,
                        maxGuestCount: $maxGuestCount
                    )
                    
                    // MARK: - Payment Details (TestFlight)
                    VenmoPaymentSection(venmoHandle: $venmoHandle)
                    
                    // MARK: - Cover Photo
                    CoverPhotoSectionWithBinding(
                        coverPhotoURL: $coverPhotoURL,
                        showImagePicker: $showImagePicker,
                        coverPhotoImage: $coverPhotoImage
                    )
                    
                    // Vibe Tags
                    VibeTagsSection(
                        selectedVibes: $selectedVibes,
                        vibeOptions: vibeOptions
                    )
                    
                    // Enhanced Date & Time Selection
                    EnhancedDateTimeSection(
                        selectedDate: $selectedDate,
                        customStartTime: $customStartTime,
                        customEndTime: $customEndTime,
                        formatTime: formatTime
                    )
                    
                    // Location & Description
                    LocationDescriptionSection(
                        address: $address,
                        googleMapsLink: $googleMapsLink,
                        description: $description
                    )
                        
                        // MARK: - Party Settings
                        PartySettingsSection(
                            visibility: $visibility,
                            approvalType: $approvalType,
                            ageRestriction: $ageRestriction,
                            maxMaleRatio: $maxMaleRatio
                        )
                        
                        // MARK: - TestFlight Notice
                        TestFlightDisclaimerSection()
                        
                        // MARK: - Legal Disclaimer
                        LegalDisclaimerSection(legalDisclaimerAccepted: $legalDisclaimerAccepted)
                        
                    // Create Button
                    Button(action: createAfterparty) {
                        CreateButtonContent(
                            ticketPrice: ticketPrice,
                            isCreating: isCreating
                        )
                        }
                                .frame(maxWidth: .infinity)
                                .padding()
                    .background(createButtonBackground)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                    .disabled(isCreating || !isFormValid)
                    .padding(.top, 24)
                    }
                    .padding()
                }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Create Afterparty")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") { 
                    presentationMode.wrappedValue.dismiss() 
                    }
                    .foregroundColor(.white)
            )
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $coverPhotoImage, sourceType: .photoLibrary)
                    .onDisappear {
                        if let image = coverPhotoImage {
                            // Convert UIImage to URL string for cover photo
                            // In a real app, you'd upload this to Firebase Storage
                            // For now, we'll just use a placeholder that indicates an image was selected
                            coverPhotoURL = "local_image_selected"
                        }
                    }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatHourOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        return formatter.string(from: date)
    }
    
    private func createAfterparty() {
        guard let location = currentLocation else { return }
        
        isCreating = true
        Task {
            do {
                // Combine selected date with custom times
                let finalStartTime = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: customStartTime),
                    minute: Calendar.current.component(.minute, from: customStartTime),
                    second: 0,
                    of: selectedDate
                ) ?? customStartTime
                
                let finalEndTime = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: customEndTime),
                    minute: Calendar.current.component(.minute, from: customEndTime),
                    second: 0,
                    of: selectedDate
                ) ?? customEndTime
                
                try await afterpartyManager.createAfterparty(
                    hostHandle: authViewModel.currentUser?.name ?? "",
                    coordinate: location,
                    radius: 5000, // 5km radius
                    startTime: finalStartTime,
                    endTime: finalEndTime,
                    city: currentCity,
                    locationName: address,
                description: description,
                address: address,
                googleMapsLink: googleMapsLink,
                    vibeTag: Array(selectedVibes).joined(separator: ", "),
                    
                    // New marketplace parameters
                    title: title,
                    ticketPrice: ticketPrice,
                    coverPhotoURL: coverPhotoURL.isEmpty ? nil : coverPhotoURL,
                    maxGuestCount: maxGuestCount,
                    visibility: visibility,
                    approvalType: approvalType,
                    ageRestriction: ageRestriction,
                    maxMaleRatio: maxMaleRatio,
                    legalDisclaimerAccepted: legalDisclaimerAccepted,
                    
                    // TESTFLIGHT: Payment details
                    venmoHandle: venmoHandle.isEmpty ? nil : venmoHandle
            )
            await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
            }
        } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
            isCreating = false
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return computeSize(rows: rows, proposal: proposal)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        placeViews(rows: rows, in: bounds)
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentRow = 0
        var remainingWidth = proposal.width ?? 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(proposal)
            if size.width > remainingWidth {
                currentRow += 1
                rows.append([])
                remainingWidth = (proposal.width ?? 0) - size.width - spacing
            } else {
                remainingWidth -= size.width + spacing
            }
            rows[currentRow].append(subview)
        }
        return rows
    }
    
    private func computeSize(rows: [[LayoutSubviews.Element]], proposal: ProposedViewSize) -> CGSize {
        var height: CGFloat = 0
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(proposal).height }.max() ?? 0
            height += rowHeight + spacing
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    private func placeViews(rows: [[LayoutSubviews.Element]], in bounds: CGRect) {
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
}

struct AfterpartyActionButtons: View {
    let afterparty: Afterparty
    let currentUserId: String?
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            if afterparty.userId == currentUserId {
                Button(action: onDelete) {
                    Label("Delete Afterparty", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else if afterparty.activeUsers.contains(currentUserId ?? "") {
                Button(action: onLeave) {
                    Label("Leave Afterparty", systemImage: "person.fill.xmark")
                        .frame(maxWidth: .infinity)
                                .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                            }
            } else if afterparty.pendingRequests.contains(currentUserId ?? "") {
                Text("Request Pending")
                    .frame(maxWidth: .infinity)
                        .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            } else {
                Button(action: onJoin) {
                    Label("Join Afterparty", systemImage: "person.fill.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
}

struct AfterpartyDetailView: View {
    let afterparty: Afterparty
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingJoinConfirmation = false
    @State private var isJoining = false
    @State private var error: Error?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(afterparty.locationName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(afterparty.address)
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                // Time and Host Info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(formatTime(afterparty.startTime), systemImage: "clock.fill")
                            .foregroundColor(.pink)
                        Text("to \(formatTime(afterparty.endTime))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(afterparty.hostHandle, systemImage: "person.fill")
                            .foregroundColor(.white)
                        Text("Host")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
                
                // Vibe Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vibes")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(afterparty.vibeTag.components(separatedBy: ", "), id: \.self) { vibe in
                            Text(vibe)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.3))
                                .foregroundColor(.purple)
                                .cornerRadius(12)
                        }
                    }
                }
                
                // Description
                if !afterparty.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(afterparty.description)
                            .foregroundColor(.gray)
                    }
                }
                
                // Stats
                HStack(spacing: 24) {
                    VStack {
                        Text("\(afterparty.activeUsers.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Going")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("\(afterparty.pendingRequests.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Pending")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
                
                // Join Button
                if !afterparty.activeUsers.contains(authViewModel.currentUser?.uid ?? "") {
                    Button(action: {
                        showingJoinConfirmation = true
                    }) {
                        HStack {
                            Text("Join Afterparty")
                            if isJoining {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .disabled(isJoining)
                    .padding(.top)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Join Afterparty?", isPresented: $showingJoinConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Join") {
                joinAfterparty()
            }
        } message: {
            Text("Would you like to join this afterparty?")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func joinAfterparty() {
        isJoining = true
        Task {
            do {
                try await afterpartyManager.joinAfterparty(afterparty)
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                self.error = error
            }
            isJoining = false
        }
    }
}

struct AlertError: Identifiable {
    let id = UUID()
    let error: Error
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 

// MARK: - Extracted Form Sections to Fix Type-Checking

struct PartyDetailsSection: View {
    @Binding var title: String
    @Binding var ticketPrice: Double
    @Binding var maxGuestCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Party Details")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Party Title *")
                    .font(.body)
                    .foregroundColor(.white)
                
                TextField("Epic Rooftop Rager", text: $title)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
            
            // Ticket Price
            VStack(alignment: .leading, spacing: 8) {
                Text("Ticket Price * 💰")
                    .font(.body)
                    .foregroundColor(.white)
                
                HStack {
                    Text("$")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    TextField("10", text: Binding(
                        get: { ticketPrice == 0 ? "" : String(format: "%.0f", ticketPrice) },
                        set: { newValue in
                            if let value = Double(newValue), value >= 0 {
                                ticketPrice = value
                            } else if newValue.isEmpty {
                                ticketPrice = 0
                            }
                        }
                    ))
                        .keyboardType(.numberPad)
                        .padding()
                        .background(ticketPrice < 5.0 ? Color(.systemGray4) : Color(.systemGray6))
                        .cornerRadius(12)
                        .foregroundColor(ticketPrice < 5.0 ? .gray : .white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ticketPrice < 5.0 ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    
                    Text("per person")
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if ticketPrice >= 5.0 {
                        Text("You'll earn $\(String(format: "%.2f", ticketPrice * 0.88)) per ticket (12% Bondfyr fee)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("⚠️ Minimum $5 required to create party")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Text("No maximum price limit - charge what your party is worth!")
                        .font(.caption)
                        .foregroundColor(ticketPrice >= 5.0 ? .green : .gray)
                }
            }
            
            // Guest Limit
            VStack(alignment: .leading, spacing: 8) {
                Text("Max Guests")
                    .font(.body)
                    .foregroundColor(.white)
                
                HStack {
                    Button("-") {
                        if maxGuestCount > 5 {
                            maxGuestCount -= 5
                        }
                    }
                    .padding()
                    .background(maxGuestCount <= 5 ? Color(.systemGray4) : Color(.systemGray6))
                    .cornerRadius(8)
                    .foregroundColor(maxGuestCount <= 5 ? .gray : .white)
                    .disabled(maxGuestCount <= 5)
                    
                    Text("\(maxGuestCount) people")
                        .frame(minWidth: 100)
                        .foregroundColor(.white)
                    
                    Button("+") {
                        if maxGuestCount < 200 {
                            maxGuestCount += 5
                        }
                    }
                    .padding()
                    .background(maxGuestCount >= 200 ? Color(.systemGray4) : Color(.systemGray6))
                    .cornerRadius(8)
                    .foregroundColor(maxGuestCount >= 200 ? .gray : .white)
                    .disabled(maxGuestCount >= 200)
                }
            }
        }
    }
}

struct CoverPhotoSectionWithBinding: View {
    @Binding var coverPhotoURL: String
    @Binding var showImagePicker: Bool
    @Binding var coverPhotoImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cover Photo")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if coverPhotoImage != nil || !coverPhotoURL.isEmpty {
                    Button("Clear") {
                        coverPhotoImage = nil
                        coverPhotoURL = ""
                    }
                    .font(.subheadline)
                    .foregroundColor(.pink)
                }
            }
            
            Button(action: { showImagePicker = true }) {
                if let image = coverPhotoImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(12)
                } else if !coverPhotoURL.isEmpty {
                    AsyncImage(url: URL(string: coverPhotoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(.systemGray6)
                    }
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("Add Cover Photo")
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
        }
        .onChange(of: showImagePicker) { _ in
            // This will be handled by the parent view's ImagePicker
        }
    }
}

struct VibeTagsSection: View {
    @Binding var selectedVibes: Set<String>
    let vibeOptions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Vibes (Choose Multiple)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(vibeOptions, id: \.self) { vibe in
                    Button(action: {
                        if selectedVibes.contains(vibe) {
                            selectedVibes.remove(vibe)
                        } else {
                            selectedVibes.insert(vibe)
                        }
                    }) {
                        Text(vibe)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedVibes.contains(vibe) ? Color.pink : Color(.systemGray6))
                            .foregroundColor(selectedVibes.contains(vibe) ? .white : .primary)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

struct CreateButtonContent: View {
    let ticketPrice: Double
    let isCreating: Bool
    
    var body: some View {
        HStack {
            Text("Create Paid Party • $\(Int(ticketPrice))")
                .fontWeight(.semibold)
            if isCreating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
}

struct TimeSelectionSection: View {
    @Binding var selectedDay: String
    @Binding var startTime: Date
    let endTime: Date
    let todaySlots: [Date]
    let tomorrowSlots: [Date]
    let formatHourOnly: (Date) -> String
    let formatTime: (Date) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Time")
                .font(.title2)
                .foregroundColor(.white)
            
            // Day selection buttons
            DaySelectionButtons(
                selectedDay: $selectedDay,
                startTime: $startTime,
                todaySlots: todaySlots,
                tomorrowSlots: tomorrowSlots
            )
            
            // Time slot picker
            TimeSlotPicker(
                selectedDay: selectedDay,
                startTime: $startTime,
                todaySlots: todaySlots,
                tomorrowSlots: tomorrowSlots,
                formatHourOnly: formatHourOnly
            )
            
            Text("Ends at \(formatTime(endTime))")
                .foregroundColor(.gray)
        }
    }
}

struct DaySelectionButtons: View {
    @Binding var selectedDay: String
    @Binding var startTime: Date
    let todaySlots: [Date]
    let tomorrowSlots: [Date]
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                selectedDay = "today"
                if let firstTodaySlot = todaySlots.first {
                    startTime = firstTodaySlot
                }
            }) {
                Text("Today")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(todayButtonBackground)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(todaySlots.isEmpty)
            
            Button(action: {
                selectedDay = "tomorrow"
                if let firstTomorrowSlot = tomorrowSlots.first {
                    startTime = firstTomorrowSlot
                }
            }) {
                Text("Tomorrow")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(tomorrowButtonBackground)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(tomorrowSlots.isEmpty)
        }
    }
    
    private var todayButtonBackground: Color {
        (!todaySlots.isEmpty && selectedDay == "today") ? Color.pink : Color(.systemGray6)
    }
    
    private var tomorrowButtonBackground: Color {
        (!tomorrowSlots.isEmpty && selectedDay == "tomorrow") ? Color.pink : Color(.systemGray6)
    }
}

struct TimeSlotPicker: View {
    let selectedDay: String
    @Binding var startTime: Date
    let todaySlots: [Date]
    let tomorrowSlots: [Date]
    let formatHourOnly: (Date) -> String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                let availableSlots = selectedDay == "today" ? todaySlots : tomorrowSlots
                ForEach(availableSlots, id: \.self) { time in
                    Button(action: { startTime = time }) {
                        Text(formatHourOnly(time))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(timeSlotBackground(for: time))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func timeSlotBackground(for time: Date) -> Color {
        Calendar.current.isDate(time, equalTo: startTime, toGranularity: .hour) ? Color.pink : Color(.systemGray6)
    }
}

struct PartySettingsSection: View {
    @Binding var visibility: PartyVisibility
    @Binding var approvalType: ApprovalType
    @Binding var ageRestriction: Int?
    @Binding var maxMaleRatio: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Party Settings")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Visibility
            VisibilitySection(visibility: $visibility)
            
            // Approval Type
            ApprovalSection(approvalType: $approvalType)
            
            // Age Restriction
            AgeRestrictionSection(ageRestriction: $ageRestriction)
            
            // Gender Ratio Control
            GenderRatioSection(maxMaleRatio: $maxMaleRatio)
        }
    }
}

struct VisibilitySection: View {
    @Binding var visibility: PartyVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visibility")
                .font(.body)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(PartyVisibility.allCases, id: \.self) { option in
                    Button(action: { visibility = option }) {
                        Text(option.displayName)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(visibility == option ? Color.pink : Color(.systemGray6))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

struct ApprovalSection: View {
    @Binding var approvalType: ApprovalType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guest Approval")
                .font(.body)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                ForEach(ApprovalType.allCases, id: \.self) { option in
                    Button(action: { approvalType = option }) {
                        Text(option.displayName)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(approvalType == option ? Color.pink : Color(.systemGray6))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

struct AgeRestrictionSection: View {
    @Binding var ageRestriction: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Age Restriction (Optional)")
                .font(.body)
                .foregroundColor(.white)
            
            HStack {
                AgeRestrictionButton(title: "None", value: nil, current: ageRestriction) {
                    ageRestriction = nil
                }
                
                AgeRestrictionButton(title: "18+", value: 18, current: ageRestriction) {
                    ageRestriction = 18
                }
                
                AgeRestrictionButton(title: "21+", value: 21, current: ageRestriction) {
                    ageRestriction = 21
                }
                
                Spacer()
            }
        }
    }
}

struct AgeRestrictionButton: View {
    let title: String
    let value: Int?
    let current: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .padding()
        .background(current == value ? Color.pink : Color(.systemGray6))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

struct GenderRatioSection: View {
    @Binding var maxMaleRatio: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Max Male Ratio: \(Int(maxMaleRatio * 100))%")
                .font(.body)
                .foregroundColor(.white)
            
            Slider(value: $maxMaleRatio, in: 0.3...1.0, step: 0.1)
                .accentColor(.pink)
            
            Text("Controls gender balance at your party")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct LocationDescriptionSection: View {
    @Binding var address: String
    @Binding var googleMapsLink: String
    @Binding var description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Address (flat/house number, street, etc.)")
                    .font(.body)
                    .foregroundColor(.white)
                
                TextField("Enter address", text: $address)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                
                Text("Google Maps Link")
                    .font(.body)
                    .foregroundColor(.white)
                
                TextField("Paste Google Maps link", text: $googleMapsLink)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.body)
                    .foregroundColor(.white)
                
                TextEditor(text: $description)
                    .frame(height: 100)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
        }
    }
}

struct EnhancedDateTimeSection: View {
    @Binding var selectedDate: Date
    @Binding var customStartTime: Date
    @Binding var customEndTime: Date
    let formatTime: (Date) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date & Time")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Date Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Party Date")
                    .font(.body)
                    .foregroundColor(.white)
                
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .accentColor(.pink)
                    .colorScheme(.dark)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            // Start Time
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.body)
                    .foregroundColor(.white)
                
                DatePicker("Start Time", selection: $customStartTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .accentColor(.pink)
                    .colorScheme(.dark)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            // End Time
            VStack(alignment: .leading, spacing: 8) {
                Text("End Time")
                    .font(.body)
                    .foregroundColor(.white)
                
                DatePicker("End Time", selection: $customEndTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .accentColor(.pink)
                    .colorScheme(.dark)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .onChange(of: customEndTime) { newEndTime in
                        // Ensure end time is after start time
                        if newEndTime <= customStartTime {
                            customEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: customStartTime) ?? customStartTime
                        }
                    }
            }
            
            // Duration Display
            HStack {
                Text("Duration: \(formatDuration())")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
    }
    
    private func formatDuration() -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: customStartTime, to: customEndTime)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

struct LegalDisclaimerSection: View {
    @Binding var legalDisclaimerAccepted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal Responsibility")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(alignment: .top, spacing: 12) {
                Button(action: { legalDisclaimerAccepted.toggle() }) {
                    Image(systemName: legalDisclaimerAccepted ? "checkmark.square.fill" : "square")
                        .foregroundColor(legalDisclaimerAccepted ? .pink : .gray)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("I agree to take full responsibility for this event *")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text("You are legally responsible for your party, including guest safety, property damage, noise complaints, and local law compliance.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct VenmoPaymentSection: View {
    @Binding var venmoHandle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Payment Details")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Venmo Handle *")
                    .font(.body)
                    .foregroundColor(.white)
                
                TextField("@your-venmo-handle", text: $venmoHandle)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("💰 Guests will send payments to this Venmo")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("🔒 Only shown to approved guests")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("📱 Payment format: \"Party: [Your Party Name]\"")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct TestFlightDisclaimerSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("TestFlight Version")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("🧪 This is a test version to validate the concept")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Text("💰 Guests contact hosts directly for payment (Venmo/CashApp)")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Text("📊 We're tracking estimated transaction volumes for analytics")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Text("🚀 After validation, we'll launch with:")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("   • Automatic payment processing")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("   • 12% Bondfyr commission (88% to host)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("   • Secure dispute resolution")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct ContactHostSheet: View {
    let afterparty: Afterparty
    @Binding var isJoining: Bool
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingSuccess = false
    @State private var userRequestStatus: UserRequestStatus = .notRequested
    
    enum UserRequestStatus {
        case notRequested
        case pending
        case approved
        case confirmed
    }
    
    private var currentUserId: String {
        authViewModel.currentUser?.uid ?? ""
    }
    
    private var userRequest: GuestRequest? {
        afterparty.guestRequests.first { $0.userId == currentUserId }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.pink)
                    
                    Text("Join \(afterparty.title)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Hosted by @\(afterparty.hostHandle)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Status-based content
                switch userRequestStatus {
                case .notRequested:
                    notRequestedContent
                case .pending:
                    pendingContent
                case .approved:
                    approvedContent
                case .confirmed:
                    confirmedContent
                }
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .preferredColorScheme(.dark)
        .onAppear {
            updateUserStatus()
        }
        .alert("Request Sent!", isPresented: $showingSuccess) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your request has been sent to the host. They'll approve you once they review your request.")
        }
    }
    
    private var notRequestedContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("TestFlight Version")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text("Send a join request and wait for host approval. Once approved, you'll see payment details.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // Payment Info Preview
            VStack(alignment: .leading, spacing: 16) {
                Text("Payment Details")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Ticket Price:")
                    Spacer()
                    Text("$\(Int(afterparty.ticketPrice))")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                
                Text("Payment details will be revealed after host approval")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var pendingContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text("Request Pending")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text("Your request is pending host approval. You'll be notified when approved!")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var approvedContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Approved! Payment Required")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text("You've been approved! Send payment to secure your spot.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Venmo Payment Details
            if let venmoHandle = afterparty.venmoHandle {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Payment Instructions")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Send to:")
                            Spacer()
                            Text(venmoHandle)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Amount:")
                            Spacer()
                            Text("$\(Int(afterparty.ticketPrice))")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Payment message:")
                                .foregroundColor(.gray)
                            Text("\"Party: \(afterparty.title)\"")
                                .font(.monospaced(.body)())
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                    }
                    .foregroundColor(.white)
                    
                    Button("Open Venmo") {
                        if let venmoURL = URL(string: "venmo://paycharge?txn=pay&recipients=\(venmoHandle)&amount=\(Int(afterparty.ticketPrice))&note=Party: \(afterparty.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                            UIApplication.shared.open(venmoURL) { success in
                                if !success {
                                    // Fallback to Venmo website
                                    if let webURL = URL(string: "https://venmo.com/\(venmoHandle)") {
                                        UIApplication.shared.open(webURL)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var confirmedContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You're Going!")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text("Payment confirmed! See you at the party!")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            switch userRequestStatus {
            case .notRequested:
                Button(action: sendJoinRequest) {
                    HStack {
                        if isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Join Request")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isJoining)
                
            case .pending:
                Text("Waiting for host approval...")
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                
            case .approved:
                Text("Send payment via Venmo to confirm your spot")
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
                
            case .confirmed:
                Text("You're all set!")
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
            }
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.gray)
        }
    }
    
    private func updateUserStatus() {
        if afterparty.activeUsers.contains(currentUserId) {
            userRequestStatus = .confirmed
        } else if let request = userRequest {
            if request.paymentStatus == .paid {
                userRequestStatus = .confirmed
            } else {
                // In TestFlight, we'll treat all requests as "approved" for simplicity
                // In real version, host would need to manually approve first
                userRequestStatus = .approved
            }
        } else {
            userRequestStatus = .notRequested
        }
    }
    
    private func sendJoinRequest() {
        isJoining = true
        Task {
            do {
                // Track estimated transaction for analytics
                await afterpartyManager.trackEstimatedTransaction(
                    afterpartyId: afterparty.id,
                    estimatedValue: afterparty.ticketPrice
                )
                
                // Simple join request (no payment)
                try await afterpartyManager.requestFreeAccess(
                    to: afterparty,
                    userHandle: authViewModel.currentUser?.instagramHandle ?? authViewModel.currentUser?.snapchatHandle ?? authViewModel.currentUser?.name ?? "",
                    userName: authViewModel.currentUser?.name ?? ""
                )
                
                await MainActor.run {
                    userRequestStatus = .approved // Auto-approve for TestFlight
                    showingSuccess = true
                }
            } catch {
                print("Error requesting access: \(error)")
            }
            isJoining = false
        }
    }
}
 