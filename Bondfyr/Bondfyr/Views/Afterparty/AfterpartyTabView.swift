import SwiftUI
import CoreLocation
import FirebaseFirestore
import FirebaseStorage
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
                        Color.pink
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
    @ObservedObject private var afterpartyManager = AfterpartyManager.shared
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
        maxGuestCount: 500
    )
    @State private var isLoadingMarketplace = false
    
    private var filteredAfterparties: [Afterparty] {
        var parties = marketplaceAfterparties
        
        // Apply search filter
        if !searchText.isEmpty {
            parties = parties.filter { afterparty in
                afterparty.title.localizedCaseInsensitiveContains(searchText) ||
                afterparty.description.localizedCaseInsensitiveContains(searchText) ||
                afterparty.vibeTag.localizedCaseInsensitiveContains(searchText) ||
                afterparty.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply distance filter
        guard let userLocation = locationManager.location?.coordinate else {
            return parties
        }
        
        let distanceFilteredParties = parties.filter { afterparty in
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
        
        // PIN USER'S ACTIVE PARTY TO TOP
        guard let currentUserId = authViewModel.currentUser?.uid else {
            return distanceFilteredParties
        }
        
        // Find user's active party
        let userActiveParties = distanceFilteredParties.filter { party in
            return party.userId == currentUserId && (party.completionStatus == nil || party.completionStatus == .ongoing)
        }
        let activePartyForUser = userActiveParties.first
        
        // If user has an active party, pin it to the top
        if let activeParty = activePartyForUser {
            var reorderedParties = distanceFilteredParties.filter { $0.id != activeParty.id }
            reorderedParties.insert(activeParty, at: 0)
            return reorderedParties
        }
        
        return distanceFilteredParties
    }
    
    // Check if any filters are active (different from defaults)
    private var hasActiveFilters: Bool {
        return currentFilters.priceRange != 5...200 ||
               !currentFilters.vibes.isEmpty ||
               currentFilters.timeFilter != .all ||
               currentFilters.showOnlyAvailable != true ||
               currentFilters.maxGuestCount != 500
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea(.all)
            
            VStack(spacing: 16) {
                // FIXED HEADER - NOT SCROLLABLE
                VStack(spacing: 12) {
                    // Title and Filter
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
                            .background(hasActiveFilters ? Color.pink : Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                    }
                    
                    // Search and live count
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search parties...", text: $searchText)
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        VStack {
                            Text("\(filteredAfterparties.count)")
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
                .padding(.top, 8)
                
                // Distance slider - FIXED
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
                
                // Create button - FIXED
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
                
                // SCROLLABLE CONTENT AREA ONLY
                if isLoadingMarketplace {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                    Spacer()
                } else if filteredAfterparties.isEmpty {
                    ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "party.popper.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.pink)
                            
                            VStack(spacing: 8) {
                                Text("🎉 Welcome to Bondfyr")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Create amazing parties and connect with people!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(16)
                        
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                            
                            VStack(spacing: 12) {
                                Text("Be the First Host in \(locationManager.currentCity ?? "Your City")")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                VStack(spacing: 4) {
                                    Text("• Early hosts get featured first")
                                    Text("• Build your reputation early")
                                    Text("• Secure payments via Dodo Payments")
                                    Text("• Simple party management tools")
                                }
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                

                            }
                            
                            Button("Create First Party") {
                                if hasActiveParty {
                                    showingActivePartyAlert = true
                                } else if locationManager.authorizationStatus == .denied {
                                    showLocationDeniedAlert = true
                                } else {
                                    showingCreateSheet = true
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.pink)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .fontWeight(.semibold)
                        }
                        .padding()
                    }
                    .padding()
                    }
                } else {
                    // ONLY PARTY CARDS SCROLL
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredAfterparties) { afterparty in
                                AfterpartyCard(afterparty: afterparty)
                            }
                        }
                                .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
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
        .onChange(of: afterpartyManager.nearbyAfterparties) {
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshMarketplaceData"))) { _ in
            Task {
                await loadMarketplaceAfterparties()
            }
        }
    }
    
    // MARK: - Marketplace Data Loading
    private func loadMarketplaceAfterparties(with filters: MarketplaceFilters? = nil) async {
        isLoadingMarketplace = true
        defer { isLoadingMarketplace = false }
        
        // Use provided filters or current filters
        let activeFilters = filters ?? currentFilters
        
        var afterparties: [Afterparty] = []
        
        // Load real parties from Firebase
        do {
            afterparties = try await afterpartyManager.getMarketplaceAfterparties(
                priceRange: activeFilters.priceRange,
                vibes: activeFilters.vibes,
                timeFilter: activeFilters.timeFilter
            )
        } catch {
            
            // Continue with empty array to show proper empty state
        }
        
        // Apply additional client-side filters
        var filteredResults = afterparties
        
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
    @Binding var showingPaymentSheet: Bool // NEW FLOW: Add payment sheet binding
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
                Label("Manage Guests (\(afterparty.pendingApprovalCount))", systemImage: "person.2.fill")
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
        let userRequest = afterparty.guestRequests.first { $0.userId == userId }
        let isConfirmed = afterparty.activeUsers.contains(userId)
        
        // Enhanced logging for debugging
        print("🔍 UI: guestActionButton computed for user \(userId)")
        print("🔍 UI: activeUsers count: \(afterparty.activeUsers.count)")
        print("🔍 UI: activeUsers contains current user: \(isConfirmed)")
        print("🔍 UI: guestRequests count: \(afterparty.guestRequests.count)")
        if let request = userRequest {
            print("🔍 UI: User has request - approvalStatus: \(request.approvalStatus), paymentStatus: \(request.paymentStatus)")
        } else {
            print("🔍 UI: User has no request")
        }
        
        // Determine button state based on user's status
        let buttonState: GuestButtonState
        if isConfirmed {
            buttonState = .going
        } else if let request = userRequest {
            switch request.approvalStatus {
            case .approved:
                // Check payment status to determine exact state
                if request.paymentStatus == .proofSubmitted {
                    buttonState = .proofSubmitted
                    print("🎯 PAYMENT DEBUG: User has submitted proof, awaiting verification")
                } else {
                buttonState = .approved
                print("🎯 PAYMENT DEBUG: User is APPROVED! Should show payment button")
                print("🎯 PAYMENT DEBUG: Request payment status: \(request.paymentStatus)")
                }
            case .pending:
                buttonState = .pending
            case .denied:
                buttonState = .denied
            }
        } else if afterparty.isSoldOut {
            buttonState = .soldOut
        } else {
            buttonState = .requestToJoin
        }
        
        print("🔍 UI: Button state determined: \(buttonState)")
        
        return Button(action: {
            handleGuestAction(currentState: buttonState)
        }) {
            HStack {
                if isJoining {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    guestButtonContent(state: buttonState)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(guestButtonBackground(state: buttonState))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .disabled(isJoining || buttonState == .pending || buttonState == .soldOut || buttonState == .denied)
    }
    
    // Enhanced button state enum
    private enum GuestButtonState {
        case going
        case approved
        case proofSubmitted // NEW: Payment proof submitted, awaiting verification
        case pending
        case denied
        case soldOut
        case requestToJoin
    }
    
    @ViewBuilder
    private func guestButtonContent(state: GuestButtonState) -> some View {
        switch state {
        case .going:
            Image(systemName: "checkmark.circle.fill")
            Text("Going")
        case .approved:
            Image(systemName: "creditcard.fill")
            Text("Complete Payment ($\(Int(afterparty.ticketPrice)))")
        case .proofSubmitted:
            Image(systemName: "hourglass")
            Text("Payment Pending Verification...")
        case .pending:
            Image(systemName: "clock.fill")
            Text("Pending")
        case .denied:
            Image(systemName: "xmark.circle.fill")
            Text("Request Denied")
        case .soldOut:
            Image(systemName: "xmark.circle.fill")
            Text("Sold Out")
        case .requestToJoin:
            Image(systemName: "person.badge.plus")
            Text("Request to Join")
        }
    }
    
    private func guestButtonBackground(state: GuestButtonState) -> AnyView {
        switch state {
        case .going:
            return AnyView(Color.green)
        case .approved:
            return AnyView(Color.blue)
        case .proofSubmitted:
            return AnyView(Color.yellow)
        case .pending:
            return AnyView(Color.orange)
        case .denied, .soldOut:
            return AnyView(Color.gray)
        case .requestToJoin:
            return AnyView(Color.pink)
        }
    }
    
    private func handleGuestAction(currentState: GuestButtonState) {
        switch currentState {
        case .requestToJoin:
            // TESTFLIGHT VERSION: Show contact host sheet
            showingContactHost = true
        case .approved:
            // NEW FLOW: Initiate Dodo payment for approved guest
            print("🔍 UI: Approved user initiating payment flow")
            initiatePaymentFlow()
        default:
            break
        }
    }
    
    // NEW FLOW: Payment initiation for approved guests
    private func initiatePaymentFlow() {
        guard let currentUserId = authViewModel.currentUser?.uid else {
            print("🔴 PAYMENT: No current user for payment")
            return
        }
        
        // Show payment sheet for Dodo payment processing
        showingPaymentSheet = true
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
    @State private var afterparty: Afterparty
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var showingGuestList = false
    @State private var showingEditSheet = false
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingContactHost = false // TESTFLIGHT: Contact host sheet
    @State private var isJoining = false // Missing state variable for ContactHostSheet
    @State private var showingHostInfo = false // Host profile sheet
    @State private var showingPaymentSheet = false // NEW FLOW: Payment sheet for approved guests
    @State private var showingManagementSheet = false // Party management sheet
    @State private var refreshTimer: Timer? // Add timer for periodic refresh
    
    // Computed property for formatted date/time
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d 'at' h:mm a"
        return formatter.string(from: afterparty.startTime)
    }
    
    // End Party Logic - matches management screen implementation
    private var canEndParty: Bool {
        let oneHourAfterStart = afterparty.startTime.addingTimeInterval(3600) // 1 hour = 3600 seconds
        return Date() >= oneHourAfterStart
    }
    
    private var timeUntilEndEnabled: String {
        let oneHourAfterStart = afterparty.startTime.addingTimeInterval(3600)
        let timeRemaining = oneHourAfterStart.timeIntervalSinceNow
        
        if timeRemaining <= 0 {
            return ""
        } else if timeRemaining < 3600 {
            return "\(Int(timeRemaining/60))m"
        } else {
            return "\(Int(timeRemaining/3600))h \(Int((timeRemaining.truncatingRemainder(dividingBy: 3600))/60))m"
        }
    }
    
    // CRITICAL FIX: Add initializer to set the @State property
    init(afterparty: Afterparty) {
        self._afterparty = State(initialValue: afterparty)
    }
    
    // Function to refresh marketplace data after request submission
    private func refreshAfterpartyData() {
        print("🔄 UI: refreshAfterpartyData() called for party \(afterparty.id)")
        Task {
            do {
                // Fetch updated party data from Firebase
                let updatedParty = try await afterpartyManager.getAfterpartyById(afterparty.id)
                
                await MainActor.run {
                    // Update the party data
                    self.afterparty = updatedParty
                    print("🔄 UI: Party data refreshed - activeUsers: \(updatedParty.activeUsers.count), guestRequests: \(updatedParty.guestRequests.count)")
                    
                    // Log current user status for debugging
                    let currentUserId = authViewModel.currentUser?.uid ?? ""
                    let isInActiveUsers = updatedParty.activeUsers.contains(currentUserId)
                    let userRequest = updatedParty.guestRequests.first { $0.userId == currentUserId }
                    
                    print("🔄 UI: Current user status after refresh:")
                    print("🔄 UI: - User ID: \(currentUserId)")
                    print("🔄 UI: - In activeUsers: \(isInActiveUsers)")
                    if let request = userRequest {
                        print("🔄 UI: - Request status: approval=\(request.approvalStatus), payment=\(request.paymentStatus)")
                    } else {
                        print("🔄 UI: - No request found")
                    }
                }
            } catch {
                print("🔴 UI: Error refreshing party data: \(error)")
            }
        }
    }
    
    private var isHost: Bool {
        afterparty.userId == authViewModel.currentUser?.uid
    }
    
    private var isUserApproved: Bool {
        guard let currentUserId = authViewModel.currentUser?.uid else { return false }
        return afterparty.activeUsers.contains(currentUserId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Cover Photo & Price Header
            ZStack(alignment: .topTrailing) {
                // Cover photo or placeholder - MUCH BIGGER and better image handling
                if let coverURL = afterparty.coverPhotoURL, !coverURL.isEmpty {
                    AsyncImage(url: URL(string: coverURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(4/3, contentMode: .fill) // 4:3 landscape ratio
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(16)
                        case .failure(_), .empty:
                            // Fallback to gradient on failure or loading
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.pink)
                                .aspectRatio(4/3, contentMode: .fit) // 4:3 landscape ratio
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "party.popper.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                        Text("Party Image")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                )
                        @unknown default:
                            // Default fallback
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.pink)
                                .aspectRatio(4/3, contentMode: .fit) // 4:3 landscape ratio
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    Image(systemName: "party.popper.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                } else {
                    // Default gradient placeholder when no image URL
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.pink)
                        .aspectRatio(4/3, contentMode: .fit) // 4:3 landscape ratio
                        .frame(maxWidth: .infinity)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "party.popper.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                Text("No Image")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                }
                
                // Price tag with demo indicator
                VStack(spacing: 4) {
                    // Demo indicator for sample parties
                    if afterparty.id.hasPrefix("demo-") {
                        Text("DEMO")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("$\(Int(afterparty.ticketPrice))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(.trailing, 12)
                .padding(.top, 12)
            }
            
            // Party title and location - below the image
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(afterparty.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Simple redirect arrow - no text, just navigation
                Button(action: {
                    if let url = URL(string: afterparty.googleMapsLink), !afterparty.googleMapsLink.isEmpty {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.right")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                }
            }
            
            // Date and Time Display
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundColor(.pink)
                Text(formattedDateTime)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 4)
            
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
                    Button(action: { showingHostInfo = true }) {
                        Text("@\(afterparty.hostHandle)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                    }
                    Text("Host")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // FIXED: Use new action button system
            if isHost {
                // Host controls with end party option - VISUAL DISTINCTION FOR PINNED PARTY
                VStack(spacing: 8) {
                    // "MY PARTY" Badge for visual distinction
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("MY PARTY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(6)
                    
                    // Consolidated Manage Party Button
                    Button(action: { showingManagementSheet = true }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Manage Party")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Share Party Button
                    Button(action: { showingShareSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Party")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // End Party Button (enabled 1 hour after start)
                    Button(action: { 
                        if canEndParty {
                            showingDeleteConfirmation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: canEndParty ? "stop.circle.fill" : "clock.fill")
                            Text(canEndParty ? "End Party" : "End Available in \(timeUntilEndEnabled)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(canEndParty ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(canEndParty ? .red : .gray)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .disabled(!canEndParty)
                }
            } else {
                // FIXED: Guest action button
                FixedGuestActionButton(afterparty: afterparty)
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingGuestList) {
            FixedGuestListView(partyId: afterparty.id, originalParty: afterparty)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAfterpartyView(afterparty: afterparty)
        }
        .sheet(isPresented: $showingShareSheet) {
            SocialShareSheet(party: afterparty, isPresented: $showingShareSheet)
        }
        .sheet(isPresented: $showingContactHost) {
            RequestToJoinSheet(afterparty: afterparty) {
                // Refresh marketplace data to get updated request status
                refreshAfterpartyData()
            }
        }
        .sheet(isPresented: $showingManagementSheet) {
            PartyManagementSheet(party: afterparty)
        }
        .onAppear {
            // Refresh party data when card appears to ensure UI is up to date
            refreshAfterpartyData()
            
            // Start periodic refresh timer for real-time updates (reduced frequency)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
                refreshAfterpartyData()
            }
            
            // Listen for payment completion notifications
            NotificationCenter.default.addObserver(
                forName: Notification.Name("PaymentCompleted"),
                object: nil,
                queue: .main
            ) { notification in
                print("🔔 PARTY CARD: Received payment completion notification - refreshing")
                // Check if this notification is for our party
                let notificationPartyId = notification.object as? String ?? notification.userInfo?["partyId"] as? String
                if let partyId = notificationPartyId, partyId == afterparty.id {
                    print("🔔 PARTY CARD: Notification is for our party - refreshing data")
                    refreshAfterpartyData()
                } else {
                    print("🔔 PARTY CARD: Notification is for different party or no party ID - refreshing anyway")
                    refreshAfterpartyData()
                }
            }
        }
        .onDisappear {
            // Stop the refresh timer when card disappears
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .refreshable {
            // Add pull-to-refresh functionality
            refreshAfterpartyData()
        }
        .sheet(isPresented: $showingHostInfo) {
            HostProfileSheet(afterparty: afterparty)
        }
        .sheet(isPresented: $showingPaymentSheet) {
            P2PPaymentSheet(afterparty: afterparty) {
                // Refresh party data after payment completion
                refreshAfterpartyData()
            }
        }
        .alert("Stop Invitation?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                Task {
                    do {
                        try await afterpartyManager.deleteAfterparty(afterparty)
                    } catch {
                        
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

// MARK: - Enhanced Guest Row Components

struct PendingRequestRow: View {
    let request: GuestRequest
    let onApprove: () -> Void
    let onDeny: () -> Void
    @State private var showingUserInfo = false
    @State private var showingFullMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info header - CRITICAL FIX: Make tap area more specific
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    // CRITICAL FIX: Use tap gesture instead of Button to avoid conflicts
                    HStack {
                        Text(request.userName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: { 
                            print("🔍 DEBUG: Showing user profile for \(request.userName)")
                            showingUserInfo = true 
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .buttonStyle(PlainButtonStyle()) // Prevent button area expansion
                    }
                    
                    Text("@\(request.userHandle)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formatTimeAgo(request.requestedAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Intro message
            if !request.introMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Button(action: { showingFullMessage = true }) {
                        Text(request.introMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(showingFullMessage ? nil : 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if request.introMessage.count > 100 && !showingFullMessage {
                        Button("Read more...") {
                            showingFullMessage = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            
            // CRITICAL FIX: Add divider and spacing to separate action buttons
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Action buttons with improved spacing and logging
            HStack(spacing: 16) {
                Button(action: {
                    print("✅ DEBUG: APPROVE button tapped for \(request.userHandle)")
                    onApprove()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12) // Increased padding for better touch area
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle()) // Prevent button area expansion
                
                Button(action: {
                    print("❌ DEBUG: DENY button tapped for \(request.userHandle)")
                    onDeny()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Deny")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12) // Increased padding for better touch area
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle()) // Prevent button area expansion
            }
            .padding(.top, 8) // Extra spacing from divider
        }
        .padding(.vertical, 8) // Increased overall padding
        .sheet(isPresented: $showingUserInfo) {
            UserInfoView(userId: request.userId)
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ApprovedGuestSimpleRow: View {
    let request: GuestRequest
    let afterparty: Afterparty
    @State private var showingUserInfo = false
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Button(action: { showingUserInfo = true }) {
                    Text(request.userName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text("@\(request.userHandle)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let approvedAt = request.approvedAt {
                    Text("Approved \(formatTimeAgo(approvedAt))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Payment now handled through Dodo - no Venmo UI needed
            Text("✅ Approved")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
        }
        .sheet(isPresented: $showingUserInfo) {
            UserInfoView(userId: request.userId)
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}



struct SummaryStatsView: View {
    let afterparty: Afterparty
    
    private var pendingCount: Int {
        afterparty.guestRequests.filter { $0.approvalStatus == .pending }.count
    }
    
    private var approvedCount: Int {
        afterparty.guestRequests.filter { $0.approvalStatus == .approved }.count
    }
    
    private var totalRequests: Int {
        afterparty.guestRequests.count
    }
    
    private var estimatedEarnings: Double {
                                Double(approvedCount) * afterparty.ticketPrice * 0.80 // 80% after fees (if all approved guests pay)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Requests")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(totalRequests)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(pendingCount)")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Approved")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(approvedCount)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Party Capacity")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(afterparty.confirmedGuestsCount)/\(afterparty.maxGuestCount)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Potential Earnings")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("$\(Int(estimatedEarnings))")
                        .font(.headline)
                        .foregroundColor(.pink)
                }
            }
            
            Text("💰 Payment verified manually at door")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// Removed obsolete VenmoPaymentInfoSheet - replaced with P2P payment system



struct GuestListView: View {
    @Binding var afterparty: Afterparty  // CRITICAL FIX: Use binding instead of let
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var refreshing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var lastUpdateTime = Date()  // CRITICAL FIX: Track when binding updates
    @State private var forceRefresh = 0  // CRITICAL FIX: Force view refresh
    
    // CRITICAL FIX: Make computed properties more reactive by depending on forceRefresh
    private var pendingRequests: [GuestRequest] {
        let _ = forceRefresh  // Force dependency on refresh trigger
        let pending = afterparty.guestRequests.filter { $0.approvalStatus == .pending }
        print("🔍 UI: pendingRequests computed at \(Date()) - afterparty last updated: \(lastUpdateTime)")
        print("🔍 UI: afterparty.guestRequests count: \(afterparty.guestRequests.count)")
        print("🔍 UI: forceRefresh value: \(forceRefresh)")
        print("🔍 UI: pendingRequests computed - found \(pending.count) pending requests")
        for (index, request) in pending.enumerated() {
            print("🔍 UI: Pending \(index + 1): \(request.userHandle) (status: \(request.approvalStatus))")
        }
        return pending
    }
    
    private var approvedGuests: [GuestRequest] {
        let _ = forceRefresh  // Force dependency on refresh trigger
        let approved = afterparty.guestRequests.filter { $0.approvalStatus == .approved }
        print("🔍 UI: approvedGuests computed - found \(approved.count) approved guests")
        for (index, request) in approved.enumerated() {
            print("🔍 UI: Approved \(index + 1): \(request.userHandle) (status: \(request.approvalStatus), payment: \(request.paymentStatus))")
        }
        return approved
    }
    
    var body: some View {
        NavigationView {
            List {
                // Pending Approval Section
                if !pendingRequests.isEmpty {
                    Section("⏳ Pending Approval (\(pendingRequests.count))") {
                        ForEach(pendingRequests) { request in
                            PendingRequestRow(
                                request: request,
                                onApprove: {
                                    Task {
                                        await approveRequest(request: request)
                                    }
                                },
                                onDeny: {
                                    Task {
                                        await denyRequest(request: request)
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Approved Guests Section
                if !approvedGuests.isEmpty {
                    Section("✅ Approved - Can Attend (\(approvedGuests.count))") {
                        ForEach(approvedGuests) { request in
                            ApprovedGuestSimpleRow(request: request, afterparty: afterparty)
                        }
                    }
                }
                
                // Empty state
                if pendingRequests.isEmpty && approvedGuests.isEmpty {
                    Section("🔍 No Requests Yet") {
                        VStack(spacing: 8) {
                            Text("No one has requested to join yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("Share your party to start receiving requests!")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Summary Section
                Section("📊 Summary") {
                    SummaryStatsView(afterparty: afterparty)
                }
                
                // Debug Section (for testing notifications)
                // Debug section removed - was causing guests to receive host notifications
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Guest Management")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") { 
                    presentationMode.wrappedValue.dismiss() 
                },
                trailing: Button(action: {
                    Task {
                        await refreshData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(refreshing)
            )
        }
        .id(lastUpdateTime)  // CRITICAL FIX: Force view refresh when binding changes
        .onChange(of: afterparty.guestRequests.count) { newCount in
            print("🔄 UI: afterparty.guestRequests.count changed to \(newCount) - updating lastUpdateTime")
            lastUpdateTime = Date()
        }
        .refreshable {
            print("🔄 UI: refreshable action triggered")
            await refreshData()
        }
        .onAppear {
            print("🔄 UI: GuestListView onAppear - loading initial data")
            print("🔄 UI: Initial party state - requests: \(afterparty.guestRequests.count), active users: \(afterparty.activeUsers.count)")
            Task {
                await refreshData()
            }
        }
        .alert("Guest Management", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Actions
    
    private func approveRequest(request: GuestRequest) async {
        print("🟢 DEBUG: approveRequest() called for user \(request.userHandle) with ID \(request.id)")
        
        // CRITICAL FIX: Update UI immediately to prevent multiple taps
        await MainActor.run {
            // Optimistically update the UI by moving request to approved
            var updatedRequests = afterparty.guestRequests
            if let index = updatedRequests.firstIndex(where: { $0.id == request.id }) {
                let originalRequest = updatedRequests[index]
                let updatedRequest = GuestRequest(
                    id: originalRequest.id,
                    userId: originalRequest.userId,
                    userName: originalRequest.userName,
                    userHandle: originalRequest.userHandle,
                    introMessage: originalRequest.introMessage,
                    requestedAt: originalRequest.requestedAt,
                    paymentStatus: originalRequest.paymentStatus,
                    approvalStatus: .approved,
                    paypalOrderId: originalRequest.paypalOrderId,
                    paidAt: originalRequest.paidAt,
                    refundedAt: originalRequest.refundedAt,
                    approvedAt: Date()
                )
                updatedRequests[index] = updatedRequest
                
                // DON'T add to activeUsers yet - wait for payment verification!
                // Users should only be in activeUsers when payment status is .paid
                
                // Update the binding immediately (without activeUsers change)
                afterparty = Afterparty(
                    id: afterparty.id,
                    userId: afterparty.userId,
                    hostHandle: afterparty.hostHandle,
                    coordinate: CLLocationCoordinate2D(latitude: afterparty.coordinate.latitude, longitude: afterparty.coordinate.longitude),
                    radius: afterparty.radius,
                    startTime: afterparty.startTime,
                    endTime: afterparty.endTime,
                    city: afterparty.city,
                    locationName: afterparty.locationName,
                    description: afterparty.description,
                    address: afterparty.address,
                    googleMapsLink: afterparty.googleMapsLink,
                    vibeTag: afterparty.vibeTag,
                    activeUsers: afterparty.activeUsers, // Keep original activeUsers - no premature addition!
                    pendingRequests: afterparty.pendingRequests,
                    createdAt: afterparty.createdAt,
                    title: afterparty.title,
                    ticketPrice: afterparty.ticketPrice,
                    coverPhotoURL: afterparty.coverPhotoURL,
                    maxGuestCount: afterparty.maxGuestCount,
                    visibility: afterparty.visibility,
                    approvalType: afterparty.approvalType,
                    ageRestriction: afterparty.ageRestriction,
                    maxMaleRatio: afterparty.maxMaleRatio,
                    legalDisclaimerAccepted: afterparty.legalDisclaimerAccepted,
                    guestRequests: updatedRequests,
                    earnings: afterparty.earnings,
                    bondfyrFee: afterparty.bondfyrFee,
                    venmoHandle: afterparty.venmoHandle,
                    zelleInfo: afterparty.zelleInfo,
                    cashAppHandle: afterparty.cashAppHandle,
                    acceptsApplePay: afterparty.acceptsApplePay,
                    paymentId: afterparty.paymentId,
                    paymentStatus: afterparty.paymentStatus,
                    listingFeePaid: afterparty.listingFeePaid
                )
                
                print("🟢 DEBUG: UI updated immediately - user moved to approved section")
            }
        }
        
        do {
            print("🟢 DEBUG: Calling afterpartyManager.approveGuestRequest()...")
            try await afterpartyManager.approveGuestRequest(
                afterpartyId: afterparty.id,
                guestRequestId: request.id
            )
            
            print("🟢 DEBUG: approveGuestRequest() succeeded, syncing with Firebase...")
            // Refresh data to ensure consistency with Firebase
            await refreshData()
            
            await MainActor.run {
                let successMessage = "@\(request.userHandle) approved! They now have Venmo info + address."
                print("🟢 DEBUG: Showing SUCCESS alert: \(successMessage)")
                alertMessage = successMessage
                showingAlert = true
            }
        } catch {
            await MainActor.run {
                let errorMessage = "Failed to approve: \(error.localizedDescription)"
                print("🔴 DEBUG: approveRequest() FAILED with error: \(errorMessage)")
                alertMessage = errorMessage
                showingAlert = true
            }
            
            // Rollback optimistic update if backend failed
            await refreshData()
        }
    }
    
    private func denyRequest(request: GuestRequest) async {
        print("🔴 DEBUG: denyRequest() called for user \(request.userHandle) with ID \(request.id)")
        
        // CRITICAL FIX: Update UI immediately to prevent multiple taps
        await MainActor.run {
            // Optimistically remove request from UI
            var updatedRequests = afterparty.guestRequests
            updatedRequests.removeAll { $0.id == request.id }
            
            // Also remove from activeUsers if they were there
            var updatedActiveUsers = afterparty.activeUsers
            updatedActiveUsers.removeAll { $0 == request.userId }
            
            // Update the binding immediately
            afterparty = Afterparty(
                id: afterparty.id,
                userId: afterparty.userId,
                hostHandle: afterparty.hostHandle,
                coordinate: CLLocationCoordinate2D(latitude: afterparty.coordinate.latitude, longitude: afterparty.coordinate.longitude),
                radius: afterparty.radius,
                startTime: afterparty.startTime,
                endTime: afterparty.endTime,
                city: afterparty.city,
                locationName: afterparty.locationName,
                description: afterparty.description,
                address: afterparty.address,
                googleMapsLink: afterparty.googleMapsLink,
                vibeTag: afterparty.vibeTag,
                activeUsers: updatedActiveUsers,
                pendingRequests: afterparty.pendingRequests,
                createdAt: afterparty.createdAt,
                title: afterparty.title,
                ticketPrice: afterparty.ticketPrice,
                coverPhotoURL: afterparty.coverPhotoURL,
                maxGuestCount: afterparty.maxGuestCount,
                visibility: afterparty.visibility,
                approvalType: afterparty.approvalType,
                ageRestriction: afterparty.ageRestriction,
                maxMaleRatio: afterparty.maxMaleRatio,
                legalDisclaimerAccepted: afterparty.legalDisclaimerAccepted,
                guestRequests: updatedRequests,
                earnings: afterparty.earnings,
                bondfyrFee: afterparty.bondfyrFee,

            )
            
            print("🔴 DEBUG: UI updated immediately - request removed")
        }
        
        do {
            print("🔴 DEBUG: Calling afterpartyManager.denyGuestRequest()...")
            try await afterpartyManager.denyGuestRequest(
                afterpartyId: afterparty.id,
                guestRequestId: request.id
            )
            
            print("🔴 DEBUG: denyGuestRequest() succeeded, syncing with Firebase...")
            // Refresh data to ensure consistency with Firebase
            await refreshData()
            
            await MainActor.run {
                let denialMessage = "Request from @\(request.userHandle) was denied"
                print("🔴 DEBUG: Showing DENIAL alert: \(denialMessage)")
                alertMessage = denialMessage
                showingAlert = true
            }
        } catch {
            await MainActor.run {
                let errorMessage = "Failed to deny request: \(error.localizedDescription)"
                print("🔴 DEBUG: denyRequest() FAILED with error: \(errorMessage)")
                alertMessage = errorMessage
                showingAlert = true
            }
            
            // Rollback optimistic update if backend failed
            await refreshData()
        }
    }
    

    
    private func refreshData() async {
        print("🔄 REFRESH: refreshData() called for party \(afterparty.id)")
        refreshing = true
        do {
            print("🔄 REFRESH: Fetching fresh party data from Firebase...")
            // Use the AfterpartyManager method instead of direct Firestore call
            let updatedParty = try await afterpartyManager.getAfterpartyById(afterparty.id)
            
            await MainActor.run {
                print("🟢 REFRESH: Successfully loaded party data")
                print("🟢 REFRESH: Title: \(updatedParty.title)")
                print("🟢 REFRESH: Guest requests count: \(updatedParty.guestRequests.count)")
                print("🟢 REFRESH: Active users count: \(updatedParty.activeUsers.count)")
                
                if !updatedParty.guestRequests.isEmpty {
                    for (index, request) in updatedParty.guestRequests.enumerated() {
                        print("🟢 REFRESH: Request \(index + 1): \(request.userHandle) (\(request.approvalStatus))")
                    }
                } else {
                    print("🟢 REFRESH: No guest requests found")
                }
                
                // CRITICAL FIX: Update the binding, which will also update the parent AfterpartyCard
                print("🔄 REFRESH: About to update binding - current requests: \(afterparty.guestRequests.count), new requests: \(updatedParty.guestRequests.count)")
                afterparty = updatedParty
                lastUpdateTime = Date()  // Force view refresh
                forceRefresh += 1  // CRITICAL FIX: Trigger computed property refresh
                print("🟢 REFRESH: Binding updated - both GuestListView and AfterpartyCard now have fresh data")
                print("🟢 REFRESH: forceRefresh incremented to \(forceRefresh)")
                print("🟢 REFRESH: UI should now show \(updatedParty.guestRequests.filter { $0.approvalStatus == .pending }.count) pending requests")
            }
        } catch {
            print("🔴 REFRESH: Failed to refresh data: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = "Failed to refresh data: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        refreshing = false
        print("🔄 REFRESH: refreshData() completed")
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
                    TextField("Paste (Apple/Google) Maps Link", text: $googleMapsLink)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .textFieldStyle(PlainTextFieldStyle())
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
    @State private var maxGuestCount = 25
    @State private var selectedVibeTag = "BYOB"
    @State private var coverPhotoImage: UIImage?
    @State private var coverPhotoURL = ""
    @State private var visibility: PartyVisibility = .publicFeed
    @State private var approvalType: ApprovalType = .manual
    @State private var ageRestriction: Int? = nil
    @State private var maxMaleRatio: Double = 1.0
    @State private var legalDisclaimerAccepted = false
    @State private var paypalSetupCompleted = false
    @State private var showImagePicker = false
    @State private var isUploadingImage = false
    
    // MARK: - Enhanced Date/Time Selection
    @State private var selectedDate = Date()
    @State private var customStartTime = Date().addingTimeInterval(3600)
    @State private var customEndTime = Date().addingTimeInterval(3600 * 5)
    
    // MARK: - NEW: Host Profile Requirements
    @State private var phoneNumber = ""
    @State private var instagramHandle = ""
    @State private var snapchatHandle = ""
    @State private var idVerificationImage: UIImage?
    @State private var showingIdPicker = false
    
    // MARK: - NEW: Payment Method Requirements (Critical for P2P)
    @State private var venmoHandle = ""
    @State private var zelleInfo = ""
    @State private var cashAppHandle = ""
    @State private var acceptsApplePay = false
    
    // MARK: - NEW: Listing Fee Payment Flow
    @State private var showingListingFeePayment = false
    @State private var listingFeePaid = false
    @State private var listingFeeAmount: Double = 0.0
    @State private var pendingPartyData: [String: Any]?
    @State private var isProcessingPayment = false
    @State private var paymentSuccess = false
    
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
        let hasPaymentMethod = !venmoHandle.isEmpty || !zelleInfo.isEmpty || !cashAppHandle.isEmpty || acceptsApplePay
        
        return !title.isEmpty &&
               !selectedVibes.isEmpty &&
               !address.isEmpty &&
               !phoneNumber.isEmpty && // NEW: Phone required
               hasPaymentMethod && // NEW: At least one payment method required
               idVerificationImage != nil && // NEW: ID verification required
               ticketPrice >= 5.0 && // Minimum $5
               maxGuestCount >= 5 && // Minimum 5 guests
               legalDisclaimerAccepted // Must accept legal responsibility
    }
    
    // MARK: - NEW: Calculate Listing Fee
    private var calculatedListingFee: Double {
        let halfCapacity = Double(maxGuestCount) / 2.0
        return halfCapacity * ticketPrice * 0.20 // 20% of (half capacity * price)
    }
    
    // MARK: - Computed Properties
    private var createButtonBackground: AnyView {
        if isFormValid {
            return AnyView(Color.pink)
        } else {
            return AnyView(Color.gray)
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
                    
                    // MARK: - Cover Photo
                    CoverPhotoSectionWithBinding(
                        coverPhotoURL: $coverPhotoURL,
                        showImagePicker: $showImagePicker,
                        coverPhotoImage: $coverPhotoImage,
                        isUploading: isUploadingImage
                    )
                    
                    // Vibe Tags
                    VibeTagsSection(
                        selectedVibes: $selectedVibes
                    )
                    
                    // Enhanced Date & Time Selection
                    EnhancedDateTimeSection(
                        selectedDate: $selectedDate,
                        customStartTime: $customStartTime,
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
                        
                        // MARK: - NEW: Host Profile Section (Required)
                        HostProfileSection(
                            phoneNumber: $phoneNumber,
                            instagramHandle: $instagramHandle,
                            snapchatHandle: $snapchatHandle,
                            venmoHandle: $venmoHandle,
                            zelleInfo: $zelleInfo,
                            cashAppHandle: $cashAppHandle,
                            acceptsApplePay: $acceptsApplePay,
                            idVerificationImage: $idVerificationImage,
                            showingIdPicker: $showingIdPicker
                        )
                        
                        // MARK: - Legal Disclaimer
                        LegalDisclaimerSection(legalDisclaimerAccepted: $legalDisclaimerAccepted)
                        
                    // Create Button (NEW: Shows listing fee)
                    Button(action: initiateListingFeePayment) {
                        CreateButtonContentNew(
                            listingFee: calculatedListingFee,
                            isCreating: isCreating,
                            isUploadingImage: isUploadingImage,
                            isProcessingPayment: isProcessingPayment,
                            paymentSuccess: paymentSuccess
                        )
                        }
                                .frame(maxWidth: .infinity)
                                .padding()
                    .background(createButtonBackground)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                    .disabled(isCreating || isUploadingImage || isProcessingPayment || !isFormValid)
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
                ImagePicker(source: .photoLibrary) { image in
                    coverPhotoImage = image
                }
                    .onDisappear {
                        if let image = coverPhotoImage {
                            // Upload the actual image to Firebase Storage
                            uploadCoverPhoto(image)
                        }
                    }
            }
            .sheet(isPresented: $showingIdPicker) {
                ImagePicker(source: .photoLibrary) { image in
                    idVerificationImage = image
                }
            }
                    .sheet(isPresented: $showingListingFeePayment) {
            DodoPaymentSheet(
                afterparty: createMockAfterpartyForListingFee(),
                onCompletion: {
                    listingFeePaid = true
                    showingListingFeePayment = false
                    // Now create the party after payment
                    createAfterpartyAfterPayment()
                }
            )
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PaymentCompleted"))) { notification in
                // Payment completed - reset form and show success
                print("🎉 CREATE VIEW: Payment completed! Resetting form...")
                isProcessingPayment = false
                paymentSuccess = true
                listingFeePaid = true
                showingListingFeePayment = false
                
                // Show success message
                errorMessage = "🎉 Party created successfully! Your listing is now live."
                showingError = true
                
                // Reset form after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    resetForm()
                    presentationMode.wrappedValue.dismiss()
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
    
    private func uploadCoverPhoto(_ image: UIImage) {
        isUploadingImage = true
        
        Task {
            do {
                // Compress image
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    await MainActor.run {
                        errorMessage = "Could not process image"
                        showingError = true
                        isUploadingImage = false
                    }
                    return
                }
                
                // Create storage reference
                let fileName = "\(UUID().uuidString).jpg"
                let storageRef = Storage.storage().reference().child("afterparty_covers/\(fileName)")
                
                // Create metadata
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                // Upload the image
                _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                
                // Get download URL
                let downloadURL = try await storageRef.downloadURL()
                
                // Update coverPhotoURL on main thread
                await MainActor.run {
                    coverPhotoURL = downloadURL.absoluteString
                    isUploadingImage = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    showingError = true
                    isUploadingImage = false
                }
            }
        }
    }
    
    private func createAfterparty() {
        guard let location = currentLocation else { return }
        
        isCreating = true
        Task {
            do {
                // Combine selected date with start time
                let finalStartTime = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: customStartTime),
                    minute: Calendar.current.component(.minute, from: customStartTime),
                    second: 0,
                    of: selectedDate
                ) ?? customStartTime
                
                // Parties run indefinitely until host ends them manually
                // Set end time far in the future (1 year) - will be ended by host's "End Party" button
                let distantFuture = Calendar.current.date(byAdding: .year, value: 1, to: finalStartTime) ?? finalStartTime
                
                try await afterpartyManager.createAfterparty(
                    hostHandle: authViewModel.currentUser?.name ?? "",
                    coordinate: location,
                    radius: 5000, // 5km radius
                    startTime: finalStartTime,
                    endTime: distantFuture,  // Open-ended - host controls when it ends
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
    
    // MARK: - NEW: Listing Fee Payment Flow
    
    private func initiateListingFeePayment() {
        guard let location = currentLocation else { return }
        
        // Set processing state
        isProcessingPayment = true
        paymentSuccess = false
        
        // Calculate listing fee
        listingFeeAmount = calculatedListingFee
        
        // Store party data for after payment
        storePendingPartyData(location: location)
        
        // Show listing fee payment sheet
        showingListingFeePayment = true
    }
    
    private func createMockAfterpartyForListingFee() -> Afterparty {
        // Use the stored party ID from pending data to ensure webhook can find the data
        let partyId = pendingPartyData?["partyId"] as? String ?? UUID().uuidString
        
        // Create a mock afterparty for Dodo payment processing (listing fee)
        return Afterparty(
            id: partyId, // Pass the party ID during initialization
            userId: authViewModel.currentUser?.uid ?? "",
            hostHandle: authViewModel.currentUser?.name ?? "Host",
            coordinate: currentLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            radius: 1000,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            city: currentCity,
            locationName: "Listing Fee Payment",
            description: "Listing fee for \(title)",
            address: "Platform Fee",
            googleMapsLink: "",
            vibeTag: "Platform",
            title: "Listing Fee - \(title)",
            ticketPrice: ticketPrice,  // Use actual ticket price, not listing fee!
            maxGuestCount: maxGuestCount,  // Use actual guest count!
            phoneNumber: phoneNumber,
            instagramHandle: instagramHandle,
            snapchatHandle: snapchatHandle,
            venmoHandle: venmoHandle,
            zelleInfo: zelleInfo,
            cashAppHandle: cashAppHandle,
            acceptsApplePay: acceptsApplePay
        )
    }
    
    private func resetForm() {
        title = ""
        description = ""
        address = ""
        googleMapsLink = ""
        selectedVibes.removeAll()
        ticketPrice = 10.0
        maxGuestCount = 25
        phoneNumber = ""
        instagramHandle = ""
        snapchatHandle = ""
        venmoHandle = ""
        zelleInfo = ""
        cashAppHandle = ""
        acceptsApplePay = false
        idVerificationImage = nil
        legalDisclaimerAccepted = false
        pendingPartyData = nil
        listingFeePaid = false
        isProcessingPayment = false
        paymentSuccess = false
    }
    
    private func storePendingPartyData(location: CLLocationCoordinate2D) {
        let finalStartTime = Calendar.current.date(
            bySettingHour: Calendar.current.component(.hour, from: customStartTime),
            minute: Calendar.current.component(.minute, from: customStartTime),
            second: 0,
            of: selectedDate
        ) ?? customStartTime
        
        let distantFuture = Calendar.current.date(byAdding: .year, value: 1, to: finalStartTime) ?? finalStartTime
        
        let partyId = UUID().uuidString
        
        pendingPartyData = [
            "hostHandle": authViewModel.currentUser?.name ?? "",
            "coordinate": location,
            "radius": 5000,
            "startTime": finalStartTime,
            "endTime": distantFuture,
            "city": currentCity,
            "locationName": address,
            "description": description,
            "address": address,
            "googleMapsLink": googleMapsLink,
            "vibeTag": Array(selectedVibes).joined(separator: ", "),
            "title": title,
            "ticketPrice": ticketPrice,
            "coverPhotoURL": coverPhotoURL.isEmpty ? nil : coverPhotoURL,
            "maxGuestCount": maxGuestCount,
            "visibility": visibility.rawValue,
            "approvalType": approvalType.rawValue,
            "ageRestriction": ageRestriction,
            "maxMaleRatio": maxMaleRatio,
            "legalDisclaimerAccepted": legalDisclaimerAccepted,
            "phoneNumber": phoneNumber,
            "instagramHandle": instagramHandle,
            "snapchatHandle": snapchatHandle,
            "venmoHandle": venmoHandle,
            "zelleInfo": zelleInfo,
            "cashAppHandle": cashAppHandle,
            "acceptsApplePay": acceptsApplePay,
            "partyId": partyId
        ]
        
        // Store in Firebase for webhook access
        Task {
            await storePendingPartyInFirebase(partyId: partyId, partyData: pendingPartyData!)
        }
    }
    
    private func storePendingPartyInFirebase(partyId: String, partyData: [String: Any]) async {
        do {
            print("💾 Storing pending party data in Firebase for webhook access")
            
            // Convert coordinate to a format Firebase can store
            var firebaseData = partyData
            if let coordinate = partyData["coordinate"] as? CLLocationCoordinate2D {
                firebaseData["coordinate"] = [
                    "latitude": coordinate.latitude,
                    "longitude": coordinate.longitude
                ]
            }
            
            // Add additional metadata for webhook
            firebaseData["userId"] = authViewModel.currentUser?.uid
            firebaseData["hostId"] = authViewModel.currentUser?.uid
            firebaseData["createdAt"] = Date()
            
            // Store in pendingParties collection
            try await Firestore.firestore()
                .collection("pendingParties")
                .document(partyId)
                .setData(firebaseData)
            
            print("✅ Pending party data stored successfully: \(partyId)")
            
        } catch {
            print("❌ Error storing pending party data: \(error)")
        }
    }
    
    private func createAfterpartyAfterPayment() {
        guard let partyData = pendingPartyData,
              let coordinate = partyData["coordinate"] as? CLLocationCoordinate2D else {
            return
        }
        
        isCreating = true
        Task {
            do {
                try await afterpartyManager.createAfterparty(
                    hostHandle: partyData["hostHandle"] as? String ?? "",
                    coordinate: coordinate,
                    radius: partyData["radius"] as? Double ?? 5000,
                    startTime: partyData["startTime"] as? Date ?? Date(),
                    endTime: partyData["endTime"] as? Date ?? Date(),
                    city: partyData["city"] as? String ?? "",
                    locationName: partyData["locationName"] as? String ?? "",
                    description: partyData["description"] as? String ?? "",
                    address: partyData["address"] as? String ?? "",
                    googleMapsLink: partyData["googleMapsLink"] as? String ?? "",
                    vibeTag: partyData["vibeTag"] as? String ?? "",
                    title: partyData["title"] as? String ?? "",
                    ticketPrice: partyData["ticketPrice"] as? Double ?? 0.0,
                    coverPhotoURL: partyData["coverPhotoURL"] as? String,
                    maxGuestCount: partyData["maxGuestCount"] as? Int ?? 25,
                    visibility: PartyVisibility(rawValue: partyData["visibility"] as? String ?? "public") ?? .publicFeed,
                    approvalType: ApprovalType(rawValue: partyData["approvalType"] as? String ?? "manual") ?? .manual,
                    ageRestriction: partyData["ageRestriction"] as? Int,
                    maxMaleRatio: partyData["maxMaleRatio"] as? Double ?? 1.0,
                    legalDisclaimerAccepted: partyData["legalDisclaimerAccepted"] as? Bool ?? false,
                    phoneNumber: partyData["phoneNumber"] as? String,
                    instagramHandle: partyData["instagramHandle"] as? String,
                    snapchatHandle: partyData["snapchatHandle"] as? String,
                    venmoHandle: partyData["venmoHandle"] as? String,
                    zelleInfo: partyData["zelleInfo"] as? String,
                    cashAppHandle: partyData["cashAppHandle"] as? String,
                    acceptsApplePay: partyData["acceptsApplePay"] as? Bool
                )
                
                await MainActor.run {
                    // Clear state and dismiss
                    isCreating = false
                    resetForm()
                    presentationMode.wrappedValue.dismiss()
                    
                    // TODO: Navigate to created party or show success message
                    print("🎉 PARTY CREATED: Party created successfully!")
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
            } else if afterparty.guestRequests.contains(where: { $0.userId == currentUserId && $0.approvalStatus == .pending }) {
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
                        Text("\(afterparty.pendingApprovalCount)")
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
                        .background(Color.pink)
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

// SocialShareSheet has been moved to Views/Shared/SocialShareSheet.swift

// MARK: - Demo Banner Component
struct DemoPartiesBanner: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🧪 TestFlight Demo Parties")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Tap to learn more")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These sample parties show how Bondfyr works:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("✅ Different price points ($8 - $85)")
                        Text("✅ Various party types & vibes")
                        Text("✅ Payment flow simulation")
                        Text("✅ Host/guest interactions")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    Text("Real parties from actual hosts will appear here!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

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
                        Text("You keep $\(String(format: "%.2f", ticketPrice)) per ticket (100% during TestFlight!)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    } else {
                        Text("⚠️ Minimum $5 required to create party")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Text("Full version: 20% service fee, you keep 80%")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
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
                        if maxGuestCount < 500 {
                            maxGuestCount += 5
                        }
                    }
                    .padding()
                    .background(maxGuestCount >= 500 ? Color(.systemGray4) : Color(.systemGray6))
                    .cornerRadius(8)
                    .foregroundColor(maxGuestCount >= 500 ? .gray : .white)
                    .disabled(maxGuestCount >= 500)
                }
            }
        }
    }
}

struct CoverPhotoSectionWithBinding: View {
    @Binding var coverPhotoURL: String
    @Binding var showImagePicker: Bool
    @Binding var coverPhotoImage: UIImage?
    let isUploading: Bool
    
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
            
            Button(action: { 
                if !isUploading {
                    showImagePicker = true 
                }
            }) {
                ZStack {
                    if let image = coverPhotoImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(4/3, contentMode: .fill) // 4:3 landscape ratio
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .cornerRadius(12)
                    } else if !coverPhotoURL.isEmpty {
                        AsyncImage(url: URL(string: coverPhotoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(4/3, contentMode: .fill) // 4:3 landscape ratio
                        } placeholder: {
                            Color(.systemGray6)
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .aspectRatio(4/3, contentMode: .fit) // 4:3 landscape ratio
                            .frame(maxWidth: .infinity)
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
                    
                    // Upload overlay
                    if isUploading {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .aspectRatio(4/3, contentMode: .fit) // 4:3 landscape ratio
                            .frame(maxWidth: .infinity)
                            .overlay(
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Uploading...")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            )
                    }
                }
            }
            .disabled(isUploading)
        }
        .onChange(of: showImagePicker) {
            // This will be handled by the parent view's ImagePicker
        }
    }
}

struct VibeTagsSection: View {
    @Binding var selectedVibes: Set<String>
    @State private var customTag = ""
    @State private var showingCustomTagField = false
    
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
                // Default vibe options
                ForEach(Afterparty.vibeOptions, id: \.self) { vibe in
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
                
                // Custom tags that were added
                ForEach(Array(selectedVibes.filter { !Afterparty.vibeOptions.contains($0) }), id: \.self) { customVibe in
                    Button(action: {
                        selectedVibes.remove(customVibe)
                    }) {
                        HStack {
                            Text(customVibe)
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                // Custom Tag Button
                Button(action: {
                    showingCustomTagField = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Custom Tag")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.pink.opacity(0.3))
                    .foregroundColor(.pink)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.pink, lineWidth: 2)
                    )
                }
            }
            
            // Custom tag input field
            if showingCustomTagField {
                VStack(spacing: 8) {
                    HStack {
                        TextField("Enter custom tag", text: $customTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .background(Color.white)
                            .cornerRadius(8)
                        
                        Button("Add") {
                            if !customTag.isEmpty && !selectedVibes.contains(customTag) {
                                selectedVibes.insert(customTag)
                                customTag = ""
                                showingCustomTagField = false
                            }
                        }
                        .disabled(customTag.isEmpty)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(customTag.isEmpty ? Color.gray : Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        Button("Cancel") {
                            customTag = ""
                            showingCustomTagField = false
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

struct CreateButtonContent: View {
    let ticketPrice: Double
    let isCreating: Bool
    let isUploadingImage: Bool
    
    var body: some View {
        HStack {
            if isUploadingImage {
                Text("Uploading Image...")
                    .fontWeight(.semibold)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else if isCreating {
                Text("Creating Party...")
                    .fontWeight(.semibold)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else {
                Text("Create Paid Party • $\(Int(ticketPrice))")
                    .fontWeight(.semibold)
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
            
            // Guest Approval
            ApprovalSection(approvalType: $approvalType, maxMaleRatio: $maxMaleRatio)
            
            // Age Restriction
            AgeRestrictionSection(ageRestriction: $ageRestriction)
        }
    }
}



struct ApprovalSection: View {
    @Binding var approvalType: ApprovalType
    @Binding var maxMaleRatio: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            // Gender Ratio Control (only shows for auto-approve)
            if approvalType == .automatic {
                // PRIVATE PARTY NOTICE
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.pink)
                        Text("Your party will be private and unlisted. It will only be discoverable through the share link.")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.pink.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Male Ratio: \(Int(maxMaleRatio * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Slider(value: $maxMaleRatio, in: 0.3...1.0, step: 0.1)
                        .accentColor(.pink)
                    
                    Text("Controls gender balance for auto-approval")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
            
            // Explanation text
            VStack(alignment: .leading, spacing: 4) {
                if approvalType == .manual {
                    Text("• You manually approve each guest request")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("• Full control over who attends your party")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("• First-come, first-serve with gender ratio limits")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("• Guests auto-approved until capacity/ratio reached")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 4)
        }
    }
}

struct AgeRestrictionSection: View {
    @Binding var ageRestriction: Int?
    @State private var sliderValue: Double = 0 // 0 = None, 1-12 = ages 18-30
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Age Restriction")
                .font(.body)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Minimum Age: \(displayAge)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Slider(value: $sliderValue, in: 0...13, step: 1) { _ in
                    updateAgeRestriction()
                }
                .accentColor(.pink)
                
                HStack {
                    Text("None")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("30+")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            // Initialize slider based on current age restriction
            if let age = ageRestriction {
                sliderValue = Double(max(0, min(13, age - 17)))
            } else {
                sliderValue = 0
            }
        }
    }
    
    private var displayAge: String {
        if sliderValue == 0 {
            return "None"
        } else if sliderValue >= 13 {
            return "30+"
        } else {
            return "\(Int(sliderValue + 17))+"
        }
    }
    
    private func updateAgeRestriction() {
        if sliderValue == 0 {
            ageRestriction = nil
        } else if sliderValue >= 13 {
            ageRestriction = 30
        } else {
            ageRestriction = Int(sliderValue + 17)
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
                
                Text("Paste (Apple/Google) Maps Link")
                    .font(.body)
                    .foregroundColor(.white)
                
                TextEditor(text: $googleMapsLink)
                    .frame(height: 50)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .multilineTextAlignment(.leading)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.body)
                    .foregroundColor(.white)
                
                Text("💡 Tip: If you want guests to show ID for approval, mention it here!")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.bottom, 4)
                
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
                
                DatePicker("", selection: $customStartTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .accentColor(.pink)
                    .colorScheme(.dark)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .labelsHidden()
            }
            
            // Party info note
            HStack {
                Text("Parties run until you end them - no time limits!")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
    }
}

// MARK: - PayPal Setup Section
struct PayPalSetupSection: View {
    @Binding var paypalSetupCompleted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💰 Get Paid")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            PayPalSetupCard(isCompleted: $paypalSetupCompleted)
            
            if !paypalSetupCompleted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("PayPal setup required to receive earnings from your party")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
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
            
            // Payment now handled through Dodo - no Venmo UI needed
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
                    .background(Color.pink)
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
                Text("Payment via Dodo confirmed - you're in!")
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
        // CRITICAL FIX: Only use activeUsers array for determining confirmed status
        // This ensures consistency with all other permission checks in the app
        if afterparty.activeUsers.contains(currentUserId) {
            userRequestStatus = .confirmed
        } else if let request = userRequest {
            // Check approval status, not payment status
            if request.approvalStatus == .approved {
                userRequestStatus = .approved // Approved but not yet in activeUsers
            } else {
                userRequestStatus = .pending // Still waiting for host approval
            }
        } else {
            userRequestStatus = .notRequested
        }
    }
    
    private func sendJoinRequest() {
        isJoining = true
        Task {
            do {
                guard let currentUser = authViewModel.currentUser else {
                    print("🔴 REQUEST: No current user")
                    throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
                
                print("🟡 REQUEST: Sending join request for party \(afterparty.id)")
                print("🟡 REQUEST: User: \(currentUser.name) (\(currentUser.uid))")
                
                // CRITICAL FIX: Use proper submitGuestRequest flow that triggers notifications
                let guestRequest = GuestRequest(
                    userId: currentUser.uid,
                    userName: currentUser.name,
                    userHandle: currentUser.username ?? currentUser.name,
                    introMessage: "Excited to join this party!", // Default intro message
                    paymentStatus: .pending // Will be handled after approval
                )
                
                print("🟡 REQUEST: Created GuestRequest - calling submitGuestRequest()...")
                
                // Use the PROPER method that handles transactions and notifications
                try await afterpartyManager.submitGuestRequest(
                    afterpartyId: afterparty.id,
                    guestRequest: guestRequest
                )
                
                print("🟢 REQUEST: submitGuestRequest() SUCCESS - request submitted and host notified")
                
                await MainActor.run {
                    userRequestStatus = .pending // Proper pending state (not auto-approved)
                    showingSuccess = true
                }
            } catch {
                print("🔴 REQUEST: submitGuestRequest() FAILED: \(error.localizedDescription)")
                await MainActor.run {
                    // Handle error properly
                }
            }
            isJoining = false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - NEW: Host Profile Section
struct HostProfileSection: View {
    @Binding var phoneNumber: String
    @Binding var instagramHandle: String
    @Binding var snapchatHandle: String
    @Binding var venmoHandle: String
    @Binding var zelleInfo: String
    @Binding var cashAppHandle: String
    @Binding var acceptsApplePay: Bool
    @Binding var idVerificationImage: UIImage?
    @Binding var showingIdPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Host Profile (Required)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Your contact info helps guests verify you're legit")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Phone Number (Required)
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number*")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("(555) 123-4567", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Social Media (Optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Social Media (Optional)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("@instagram", text: $instagramHandle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(12)
                
                TextField("@snapchat", text: $snapchatHandle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Payment Methods (Required for P2P)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Payment Methods")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("*")
                        .foregroundColor(.red)
                        .font(.headline)
                }
                
                Text("Guests need to know where to send P2P payments")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextField("@venmo-handle", text: $venmoHandle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        HStack {
                            Spacer()
                            Text("Venmo")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    )
                
                TextField("Phone or email for Zelle", text: $zelleInfo)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        HStack {
                            Spacer()
                            Text("Zelle")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    )
                
                TextField("$cash-app-handle", text: $cashAppHandle)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        HStack {
                            Spacer()
                            Text("Cash App")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    )
                
                Toggle(isOn: $acceptsApplePay) {
                    Text("Accept Apple Pay (via phone)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                
                Text("⚠️ At least one payment method is required")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
            
            // ID Verification (Required)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ID Verification")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("*")
                        .foregroundColor(.red)
                        .font(.headline)
                }
                
                Text("Upload student ID or driver's license to verify you're a real host")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: { showingIdPicker = true }) {
                    HStack {
                        Image(systemName: idVerificationImage != nil ? "checkmark.circle.fill" : "camera")
                        Text(idVerificationImage != nil ? "ID Uploaded" : "Upload ID")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(idVerificationImage != nil ? Color.green.opacity(0.3) : Color(.systemGray6).opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - NEW: Create Button Content (Shows Listing Fee)
struct CreateButtonContentNew: View {
    let listingFee: Double
    let isCreating: Bool
    let isUploadingImage: Bool
    let isProcessingPayment: Bool
    let paymentSuccess: Bool
    
    var body: some View {
        HStack {
            if isUploadingImage {
                Text("Uploading Image...")
                    .fontWeight(.semibold)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else if isProcessingPayment {
                Text("Processing Payment...")
                    .fontWeight(.semibold)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else if isCreating {
                Text("Creating Party...")
                    .fontWeight(.semibold)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else if paymentSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Party Created!")
                    .fontWeight(.semibold)
            } else {
                Text("Pay Listing Fee • $\(String(format: "%.2f", listingFee))")
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Listing Fee Payment - Now uses real DodoPaymentSheet
 