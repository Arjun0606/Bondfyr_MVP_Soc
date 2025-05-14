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
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // City Header
                CityPickerView(
                    currentCity: locationManager.currentCity,
                    authorizationStatus: locationManager.authorizationStatus,
                    onLocationDenied: { showLocationDeniedAlert = true }
                )
                .padding(.horizontal)
                
                SearchBarView(searchText: $searchText)
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
                
                if afterpartyManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if filteredAfterparties.isEmpty {
                    VStack {
                        Image(systemName: "party.popper.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No afterparties yet in \(locationManager.currentCity ?? "your area").")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
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
    @State private var isJoining = false
    
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
            // Header with location and vibe tag
                HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(afterparty.locationName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(afterparty.address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Vibe tags
                Text(afterparty.vibeTag)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.3))
                    .foregroundColor(.purple)
                .cornerRadius(12)
            }
            
            // Description if available
            if !afterparty.description.isEmpty {
                Text(afterparty.description)
                        .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            // Time and host info
                    HStack {
                Label(formatTime(afterparty.startTime), systemImage: "clock.fill")
                    .foregroundColor(.pink)
                
                Text("•")
                    .foregroundColor(.gray)
                
                Text(timeRemaining)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Label(afterparty.hostHandle, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Guest count and Google Maps
            HStack {
                Label("\(afterparty.activeUsers.count) accepted", systemImage: "person.2.fill")
                    .font(.caption)
                                    .foregroundColor(.gray)
                
                Text("•")
                                    .foregroundColor(.gray)
                
                Label("\(afterparty.pendingRequests.count) pending", systemImage: "person.2.badge.gearshape")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !afterparty.googleMapsLink.isEmpty {
                    Link(destination: URL(string: afterparty.googleMapsLink)!) {
                        Image(systemName: "map.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if isHost {
                    // Host controls
                    Menu {
                        Button(action: { showingGuestList = true }) {
                            Label("Manage Guest List", systemImage: "person.2.fill")
                        }
                        
                        Button(action: { showingEditSheet = true }) {
                            Label("Edit Afterparty", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                            Label("Stop Invitation", systemImage: "xmark.circle")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Label("Manage", systemImage: "ellipsis.circle.fill")
                            .foregroundColor(.white)
                    }
                } else {
                    // Guest actions
                    Button(action: {
                        Task {
                            isJoining = true
                            if afterparty.activeUsers.contains(authViewModel.currentUser?.uid ?? "") {
                                try? await afterpartyManager.leaveAfterparty(afterparty)
                            } else {
                                try? await afterpartyManager.joinAfterparty(afterparty)
                            }
                            isJoining = false
                        }
                    }) {
                        if isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(afterparty.activeUsers.contains(authViewModel.currentUser?.uid ?? "") ? "Leave" : "Join")
                        }
                    }
                    .disabled(isJoining)
                    .buttonStyle(.borderedProminent)
                }
                
                // Share button
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                }
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
        "Chill",
        "Sesh 🍃",
        "BYOB",
        "House",
        "Rooftop",
        "Pool Party",
        "💊",
        "Video Games"
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
    
    var body: some View {
        NavigationView {
                ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Vibe Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Vibes (Choose Multiple)")
                            .font(.title2)
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
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start Time")
                            .font(.title2)
                                .foregroundColor(.white)
                        
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
                                    .background(!todaySlots.isEmpty && selectedDay == "today" ? Color.pink : Color(.systemGray6))
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
                                    .background(!tomorrowSlots.isEmpty && selectedDay == "tomorrow" ? Color.pink : Color(.systemGray6))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(tomorrowSlots.isEmpty)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                let availableSlots = selectedDay == "today" ? todaySlots : tomorrowSlots
                                ForEach(availableSlots, id: \.self) { time in
                                    Button(action: { startTime = time }) {
                                        Text(formatHourOnly(time))
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Calendar.current.isDate(time, equalTo: startTime, toGranularity: .hour) ? Color.pink : Color(.systemGray6))
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        
                        Text("Ends at \(formatTime(endTime))")
                            .foregroundColor(.gray)
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 16) {
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
                        }
                        
                        // Description
                    VStack(alignment: .leading, spacing: 12) {
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
                        
                    // Create Button
                    Button(action: createAfterparty) {
                        HStack {
                            Text("Create Afterparty")
                                .fontWeight(.semibold)
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                                .frame(maxWidth: .infinity)
                                .padding()
                        .background(
                            selectedVibes.isEmpty || address.isEmpty ? Color.gray : Color.pink
                        )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    .disabled(isCreating || selectedVibes.isEmpty || address.isEmpty)
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
                try await afterpartyManager.createAfterparty(
                    hostHandle: authViewModel.currentUser?.name ?? "",
                    coordinate: location,
                    radius: 5000, // 5km radius
                    startTime: startTime,
                    endTime: endTime,
                    city: currentCity,
                    locationName: address,
                description: description,
                address: address,
                googleMapsLink: googleMapsLink,
                    vibeTag: Array(selectedVibes).joined(separator: ", ")
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
