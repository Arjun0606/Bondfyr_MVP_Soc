import SwiftUI
import CoreLocation
import Bondfyr // For AfterpartyModel, if needed
import FirebaseFirestore
import CoreLocationUI
import Bondfyr // Ensure Afterparty model is imported
import Foundation

class AfterpartyLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AfterpartyLocationManager()
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}

struct CreateAfterpartyFlow: View {
    @Environment(\.dismiss) var dismiss
    @Binding var vibeTag: String
    @Binding var isCreating: Bool
    @State private var address = ""
    @State private var description = ""
    @State private var googleMapsLink = ""
    @State private var selectedVibeTags: Set<String> = []
    @State private var startTime = Date()
    @State private var isTomorrow = false
    @State private var showError: String? = nil
    let onCreate: (String, String, String, String, Date) -> Void
    
    // Helper to get available hours (7 PM to 4 AM)
    private var availableHours: [Date] {
        let calendar = Calendar.current
        var hours: [Date] = []
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let baseDate = isTomorrow ? calendar.date(byAdding: .day, value: 1, to: now)! : now
        
        if !isTomorrow {
            // For today, show remaining hours until 11 PM
            let startHour = currentHour + 1
            let endHour = 23 // 11 PM
            
            for hour in startHour...endHour {
                if let date = calendar.date(
                    bySettingHour: hour,
                    minute: 0,
                    second: 0,
                    of: baseDate
                ), date > now {
                    hours.append(date)
                }
            }
        } else {
            // For tomorrow, only show 12 AM to 4 AM
            for hour in 0...4 {
                if let date = calendar.date(
                    bySettingHour: hour,
                    minute: 0,
                    second: 0,
                    of: baseDate
                ) {
                    hours.append(date)
                }
            }
        }
        
        return hours
    }
    
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private var isValidStartTime: Bool {
        // Check if selected time is in the future
        guard startTime > Date() else { return false }
        
        // Check if the afterparty would end within the allowed window
        let endTime = startTime.addingTimeInterval(9 * 3600)
        let calendar = Calendar.current
        let endComponents = calendar.dateComponents([.hour], from: endTime)
        
        // Afterparty should end by 1 PM the next day (for 4 AM start + 9 hours)
        return endComponents.hour! <= 13
    }
    
    private var isValidForm: Bool {
        !address.isEmpty && 
        !googleMapsLink.isEmpty && 
        !selectedVibeTags.isEmpty && 
        isValidStartTime
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Create Afterparty")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.top, 12)
                        
                        // Vibe Selection
                        VStack(alignment: .leading) {
                            Text("Select Vibes (Choose Multiple)")
                                .font(.headline)
                                .foregroundColor(.white)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(Afterparty.vibeOptions, id: \.self) { vibe in
                                    Button(action: {
                                        if selectedVibeTags.contains(vibe) {
                                            selectedVibeTags.remove(vibe)
                                        } else {
                                            selectedVibeTags.insert(vibe)
                                        }
                                        vibeTag = Array(selectedVibeTags).joined(separator: ", ")
                                    }) {
                                        Text(vibe)
                                            .font(.system(size: 18))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .background(selectedVibeTags.contains(vibe) ? Color.pink : Color(white: 0.15))
                                            .foregroundColor(.white)
                                            .cornerRadius(24)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                        
                        // Start Time Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start Time")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Today/Tomorrow Toggle
                            HStack(spacing: 16) {
                                Button(action: { isTomorrow = false }) {
                                    Text("Today")
                                        .font(.system(size: 18))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(!isTomorrow ? Color.pink : Color(white: 0.15))
                                        .foregroundColor(.white)
                                        .cornerRadius(20)
                                }
                                
                                Button(action: { isTomorrow = true }) {
                                    Text("Tomorrow")
                                        .font(.system(size: 18))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(isTomorrow ? Color.pink : Color(white: 0.15))
                                        .foregroundColor(.white)
                                        .cornerRadius(20)
                                }
                            }
                            
                            if availableHours.isEmpty {
                                Text("No available start times for today")
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 8)
                            } else {
                                // Hour Selection
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(availableHours, id: \.self) { hour in
                                            Button(action: { startTime = hour }) {
                                                Text(formatHour(hour))
                                                    .font(.system(size: 16))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        Calendar.current.compare(hour, to: startTime, toGranularity: .hour) == .orderedSame 
                                                        ? Color.pink : Color(white: 0.15)
                                                    )
                                                    .foregroundColor(.white)
                                                    .cornerRadius(16)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            
                            // Show end time
                            Text("Ends at \(formatHour(startTime.addingTimeInterval(9 * 3600)))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Address Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address (flat/house number, street, etc.)")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("Enter address", text: $address)
                                .textFieldStyle(DefaultTextFieldStyle())
                                .padding()
                                .background(Color(white: 0.15))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                        }
                        
                        // Google Maps Link
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Google Maps Link")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("Paste Google Maps link", text: $googleMapsLink)
                                .textFieldStyle(DefaultTextFieldStyle())
                                .padding()
                                .background(Color(white: 0.15))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                        }
                        
                        // Description Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextEditor(text: $description)
                                .frame(height: 80)
                                .padding(4)
                                .background(Color(white: 0.15))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Create Button
                        Button(action: {
                            Task {
                                do {
                                    onCreate(vibeTag, address, description, googleMapsLink, startTime)
                                    await MainActor.run {
                                        dismiss()
                                    }
                                } catch {
                                    showError = error.localizedDescription
                                }
                            }
                        }) {
                            Text(isCreating ? "Creating..." : "Create Afterparty")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background((!isValidForm || isCreating) ? Color.gray : Color.pink)
                                .cornerRadius(28)
                        }
                        .disabled(!isValidForm || isCreating)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: .init(
                get: { showError != nil },
                set: { if !$0 { showError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(showError ?? "")
            }
        }
    }
}

// Helper subview for CityHeader
private struct CityHeader: View {
    let cityName: String?
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.pink)
                    .shadow(color: .pink.opacity(0.7), radius: 6, x: 0, y: 0)
                Text(cityName?.components(separatedBy: ",").first ?? "Select City")
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
        .padding(.horizontal)
    }
}

// Helper subview for ActiveAfterpartiesSection
private struct ActiveAfterpartiesSection: View {
    let afterparties: [Afterparty]
    let cityName: String?
    @EnvironmentObject var afterpartyService: AfterpartyService
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Active Afterparties")
                .font(.headline)
                .foregroundColor(.white)
            if afterparties.isEmpty {
                VStack {
                    Image(systemName: "party.popper")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No afterparties yet in \(cityName?.components(separatedBy: ",").first ?? "your city").")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(afterparties) { party in
                            AfterpartyCard(afterparty: party)
                                .environmentObject(afterpartyService)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct AfterpartyTabView: View {
    @ObservedObject var cityManager = CityManager.shared
    @StateObject private var locationManager = AfterpartyLocationManager.shared
    @StateObject private var afterpartyService = AfterpartyService()
    @State private var radius: Double = 0.5 // Starting with 0.5 miles
    @State private var isCreating: Bool = false
    @State private var createError: String? = nil
    @State private var isLoading: Bool = false
    @State private var showCityPicker = false
    @State private var selectedVibeTag = "Chill"
    @State private var showVibeSelection = false
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // City header
                CityHeader(cityName: cityManager.selectedCity, onTap: { showCityPicker = true })
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.pink)
                    TextField("Search afterparties...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .autocapitalization(.none)
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
                
                // Radius slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Distance: \(String(format: "%.1f", radius)) miles")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Slider(value: $radius, in: 0.5...15.0)
                        .accentColor(.pink)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Create afterparty button
                Button(action: { showVibeSelection = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Create Afterparty")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.pink, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 0)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Active afterparties
                ScrollView {
                    LazyVStack(spacing: 16) {
                        let filteredAfterparties = afterpartyService.activeAfterparties.filter {
                            searchText.isEmpty || 
                            $0.hostHandle.localizedCaseInsensitiveContains(searchText) ||
                            $0.vibeTag.localizedCaseInsensitiveContains(searchText)
                        }
                        
                        if filteredAfterparties.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "party.popper.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No afterparties yet in \(cityManager.selectedCity?.components(separatedBy: ",").first ?? "your city").")
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(filteredAfterparties) { party in
                                AfterpartyCard(afterparty: party)
                                    .environmentObject(afterpartyService)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCityPicker) {
            CitySelectionView { selectedCity in
                cityManager.selectedCity = selectedCity
                showCityPicker = false
                fetchAfterparties()
            }
        }
        .sheet(isPresented: $showVibeSelection) {
            CreateAfterpartyFlow(
                vibeTag: $selectedVibeTag,
                isCreating: $isCreating,
                onCreate: { vibe, address, description, googleMapsLink, startTime in
                    guard let city = cityManager.selectedCity else {
                        createError = "Please select a city."
                        return
                    }
                    guard let userHandle = UserDefaults.standard.string(forKey: "userHandle") else {
                        createError = "Please set up your profile first."
                        return
                    }
                    isCreating = true
                    Task {
                        do {
                            let afterparty = try await afterpartyService.createAfterparty(
                                hostHandle: userHandle,
                                startTime: startTime,
                                vibeTag: vibe,
                                address: address,
                                description: description,
                                googleMapsLink: googleMapsLink,
                                locationName: city
                            )
                            await MainActor.run {
                                showVibeSelection = false
                                isCreating = false
                            }
                        } catch {
                            createError = "Failed to create afterparty: \(error.localizedDescription)"
                            isCreating = false
                        }
                    }
                }
            )
        }
        .alert(item: Binding(
            get: { createError.map { ErrorAlert(message: $0) } },
            set: { _ in createError = nil }
        )) { error in
            Alert(title: Text("Error"), message: Text(error.message))
        }
        .onAppear {
            locationManager.requestLocation()
            fetchAfterparties()
        }
    }
    
    private func fetchAfterparties() {
        guard let city = cityManager.selectedCity else { return }
        isLoading = true
        afterpartyService.fetchActiveAfterparties(for: city)
        isLoading = false
    }
}

struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct AfterpartyCard: View {
    let afterparty: Afterparty
    @State private var showGuestList = false
    @State private var showShareSheet = false
    @State private var isRequestingToJoin = false
    @State private var showConfirmClose = false
    @State private var showEditSheet = false
    @State private var timeLeft: String = ""
    @State private var timer: Timer? = nil
    @EnvironmentObject var afterpartyService: AfterpartyService
    
    private var isHost: Bool {
        UserDefaults.standard.string(forKey: "userHandle") == afterparty.hostHandle
    }
    
    private var isGuest: Bool {
        guard let userHandle = UserDefaults.standard.string(forKey: "userHandle") else { return false }
        return afterparty.activeUsers.contains(userHandle)
    }
    
    private var hasPendingRequest: Bool {
        guard let userHandle = UserDefaults.standard.string(forKey: "userHandle") else { return false }
        return afterparty.pendingRequests.contains(userHandle)
    }
    
    private func updateTimeLeft() {
        let now = Date()
        let endTime = afterparty.createdAt.addingTimeInterval(9 * 3600) // 9 hours from creation time
        let diff = endTime.timeIntervalSince(now)
        
        if diff <= 0 {
            timeLeft = "Expired"
            timer?.invalidate()
        } else {
            let hours = Int(diff) / 3600
            let minutes = (Int(diff) % 3600) / 60
            timeLeft = "Closes in \(hours)h \(minutes)m"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with host info and buttons
            HStack {
                Text("@\(afterparty.hostHandle)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if isHost {
                    Button(action: { showEditSheet = true }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.pink)
                    }
                    .padding(.trailing, 8)
                }
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.pink)
                }
            }
            
            // Vibe tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(afterparty.vibeTag.components(separatedBy: ", "), id: \.self) { vibe in
                        Text(vibe)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.pink.opacity(0.2))
                            .foregroundColor(.pink)
                            .cornerRadius(12)
                    }
                }
            }
            
            // Time, guest count, and closes in
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "clock")
                    Text(afterparty.startTime.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Image(systemName: "person.2.fill")
                    Text("\(afterparty.activeUsers.count) going")
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                HStack {
                    Spacer()
                    Text(timeLeft)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if !afterparty.description.isEmpty {
                Text(afterparty.description)
                    .font(.body)
                    .foregroundColor(.white)
            }
            
            // Location info
            if !afterparty.address.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.gray)
                    Text(afterparty.address)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            
            if !afterparty.googleMapsLink.isEmpty {
                Link(destination: URL(string: afterparty.googleMapsLink)!) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Open in Maps")
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Host Controls
            if isHost {
                HStack(spacing: 16) {
                    Button(action: { showGuestList = true }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                            Text("Manage Guest List")
                        }
                        .foregroundColor(.pink)
                    }
                    
                    Button(action: { showConfirmClose = true }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Close Early")
                        }
                        .foregroundColor(.red)
                    }
                }
                .font(.subheadline)
            }
            // Guest Controls
            else if !isGuest && !hasPendingRequest {
                Button(action: {
                    isRequestingToJoin = true
                    Task {
                        guard let userHandle = UserDefaults.standard.string(forKey: "userHandle") else { return }
                        do {
                            try await afterpartyService.requestToJoin(afterpartyId: afterparty.id, userHandle: userHandle)
                        } catch {
                            print("Failed to request join: \(error)")
                        }
                        isRequestingToJoin = false
                    }
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join Waitlist")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isRequestingToJoin)
            }
            else if hasPendingRequest {
                HStack {
                    Image(systemName: "clock.fill")
                    Text("Request Pending")
                }
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            else if isGuest {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("You're on the list!")
                }
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showGuestList) {
            GuestListView(afterparty: afterparty)
                .environmentObject(afterpartyService)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                items: [
                    afterparty.shareText,
                    afterparty.deepLinkURL
                ]
            )
        }
        .sheet(isPresented: $showEditSheet) {
            EditAfterpartyView(afterparty: afterparty)
                .environmentObject(afterpartyService)
        }
        .alert("Close Afterparty", isPresented: $showConfirmClose) {
            Button("Cancel", role: .cancel) { }
            Button("Close", role: .destructive) {
                Task {
                    do {
                        try await afterpartyService.closeAfterparty(afterpartyId: afterparty.id)
                        // The UI will automatically update through the Firestore listener
                    } catch {
                        print("Failed to close afterparty: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to close this afterparty? This cannot be undone.")
        }
        .onAppear {
            updateTimeLeft()
            // Start timer to update countdown
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                updateTimeLeft()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct EditAfterpartyView: View {
    let afterparty: Afterparty
    @Environment(\.dismiss) var dismiss
    @State private var description: String
    @State private var address: String
    @State private var googleMapsLink: String
    @State private var selectedVibeTags: Set<String>
    @State private var isUpdating = false
    @State private var showError: String? = nil
    @EnvironmentObject var afterpartyService: AfterpartyService
    
    init(afterparty: Afterparty) {
        self.afterparty = afterparty
        _description = State(initialValue: afterparty.description)
        _address = State(initialValue: afterparty.address)
        _googleMapsLink = State(initialValue: afterparty.googleMapsLink)
        _selectedVibeTags = State(initialValue: Set(afterparty.vibeTag.components(separatedBy: ", ")))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Vibe Selection
                        VStack(alignment: .leading) {
                            Text("Update Vibes")
                                .font(.headline)
                                .foregroundColor(.white)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(Afterparty.vibeOptions, id: \.self) { vibe in
                                    Button(action: {
                                        if selectedVibeTags.contains(vibe) {
                                            selectedVibeTags.remove(vibe)
                                        } else {
                                            selectedVibeTags.insert(vibe)
                                        }
                                    }) {
                                        Text(vibe)
                                            .font(.system(size: 18))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .background(selectedVibeTags.contains(vibe) ? Color.pink : Color(white: 0.15))
                                            .foregroundColor(.white)
                                            .cornerRadius(24)
                                    }
                                }
                            }
                        }
                        
                        // Address
                        VStack(alignment: .leading) {
                            Text("Address")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("", text: $address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(.white)
                        }
                        
                        // Google Maps Link
                        VStack(alignment: .leading) {
                            Text("Google Maps Link")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextField("", text: $googleMapsLink)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(.white)
                        }
                        
                        // Description
                        VStack(alignment: .leading) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.white)
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            Task {
                                await updateAfterparty()
                            }
                        }) {
                            Text(isUpdating ? "Updating..." : "Update Afterparty")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isUpdating ? Color.gray : Color.pink)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(isUpdating)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Afterparty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: .init(
                get: { showError != nil },
                set: { if !$0 { showError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(showError ?? "")
            }
        }
    }
    
    private func updateAfterparty() async {
        isUpdating = true
        do {
            try await afterpartyService.updateAfterparty(
                id: afterparty.id,
                description: description,
                address: address,
                googleMapsLink: googleMapsLink,
                vibeTag: Array(selectedVibeTags).joined(separator: ", ")
            )
            await MainActor.run {
                dismiss()
            }
        } catch {
            showError = error.localizedDescription
        }
        isUpdating = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct GuestListView: View {
    let afterparty: Afterparty
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @EnvironmentObject var afterpartyService: AfterpartyService
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("", selection: $selectedTab) {
                    Text("Going (\(afterparty.activeUsers.count))").tag(0)
                    Text("Requests (\(afterparty.pendingRequests.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    // Active Users List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(afterparty.activeUsers, id: \.self) { userHandle in
                                HStack {
                                    Text("@\(userHandle)")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                } else {
                    // Pending Requests List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(afterparty.pendingRequests, id: \.self) { userHandle in
                                HStack {
                                    Text("@\(userHandle)")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button(action: {
                                        Task {
                                            try? await afterpartyService.acceptRequest(afterpartyId: afterparty.id, userHandle: userHandle)
                                        }
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    Button(action: {
                                        Task {
                                            try? await afterpartyService.rejectRequest(afterpartyId: afterparty.id, userHandle: userHandle)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Guest List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

// --- AfterpartyService and AfterpartyError copied here for local scope ---

class AfterpartyService: ObservableObject {
    private let db = Firestore.firestore()
    @Published var activeAfterparties: [Afterparty] = []
    @Published var joinedAfterparties: Set<String> = []
    @Published var pendingRequests: Set<String> = []
    
    init() {
        if let joined = UserDefaults.standard.array(forKey: "joinedAfterparties") as? [String] {
            joinedAfterparties = Set(joined)
        }
        if let pending = UserDefaults.standard.array(forKey: "pendingRequests") as? [String] {
            pendingRequests = Set(pending)
        }
    }
    
    func createAfterparty(hostHandle: String, startTime: Date, vibeTag: String, address: String, description: String, googleMapsLink: String, locationName: String) async throws -> Afterparty {
        print("📝 Starting afterparty creation process...")
        guard !hostHandle.isEmpty else { throw AfterpartyError.invalidInput("Host handle cannot be empty") }
        guard !locationName.isEmpty else { throw AfterpartyError.invalidInput("Location name cannot be empty") }
        guard !address.isEmpty else { throw AfterpartyError.invalidInput("Address cannot be empty") }
        guard !googleMapsLink.isEmpty else { throw AfterpartyError.invalidInput("Google Maps link cannot be empty") }
        let endTime = startTime.addingTimeInterval(6 * 3600)
        let shareSlug = generateUniqueSlug()
        let afterparty = Afterparty(
            id: UUID().uuidString,
            hostHandle: hostHandle,
            startTime: startTime,
            endTime: endTime,
            vibeTag: vibeTag,
            locationRadius: 0,
            location: GeoPoint(latitude: 0, longitude: 0),
            locationName: locationName,
            address: address,
            description: description,
            googleMapsLink: googleMapsLink,
            createdAt: Date(),
            activeUsers: [hostHandle],
            pendingRequests: [],
            isActive: true,
            isAcceptingRequests: true,
            shareSlug: shareSlug
        )
        do {
            try await db.collection("afterparties").document(afterparty.id).setData(from: afterparty)
            NotificationManager.shared.scheduleAfterpartyReminder(afterparty: afterparty)
            await MainActor.run {
                activeAfterparties.insert(afterparty, at: 0)
                joinedAfterparties.insert(afterparty.id)
                UserDefaults.standard.set(Array(joinedAfterparties), forKey: "joinedAfterparties")
            }
            return afterparty
        } catch {
            throw AfterpartyError.creationFailed(error.localizedDescription)
        }
    }
    func requestToJoin(afterpartyId: String, userHandle: String) async throws {
        let ref = db.collection("afterparties").document(afterpartyId)
        let afterparty = try await ref.getDocument(as: Afterparty.self)
        guard afterparty.isAcceptingRequests else { throw AfterpartyError.joinFailed("This afterparty is not accepting new requests") }
        try await ref.updateData(["pendingRequests": FieldValue.arrayUnion([userHandle])])
        await MainActor.run {
            pendingRequests.insert(afterpartyId)
            UserDefaults.standard.set(Array(pendingRequests), forKey: "pendingRequests")
        }
        NotificationManager.shared.sendJoinRequestNotification(
            to: afterparty.hostHandle,
            requesterHandle: userHandle,
            afterpartyName: afterparty.locationName
        )
    }
    func acceptRequest(afterpartyId: String, userHandle: String) async throws {
        let ref = db.collection("afterparties").document(afterpartyId)
        try await ref.updateData([
            "activeUsers": FieldValue.arrayUnion([userHandle]),
            "pendingRequests": FieldValue.arrayRemove([userHandle])
        ])
        let afterparty = try await ref.getDocument(as: Afterparty.self)
        NotificationManager.shared.sendRequestAcceptedNotification(
            to: userHandle,
            hostHandle: afterparty.hostHandle,
            afterpartyName: afterparty.locationName
        )
    }
    func rejectRequest(afterpartyId: String, userHandle: String) async throws {
        let ref = db.collection("afterparties").document(afterpartyId)
        try await ref.updateData(["pendingRequests": FieldValue.arrayRemove([userHandle])])
    }
    func toggleAcceptingRequests(afterpartyId: String, isAccepting: Bool) async throws {
        let ref = db.collection("afterparties").document(afterpartyId)
        try await ref.updateData(["isAcceptingRequests": isAccepting])
    }
    func joinAfterparty(afterpartyId: String, userHandle: String) async throws {
        let ref = db.collection("afterparties").document(afterpartyId)
        try await ref.updateData(["activeUsers": FieldValue.arrayUnion([userHandle])])
        await MainActor.run {
            joinedAfterparties.insert(afterpartyId)
            UserDefaults.standard.set(Array(joinedAfterparties), forKey: "joinedAfterparties")
        }
        let afterparty = try await ref.getDocument(as: Afterparty.self)
        NotificationManager.shared.sendAfterpartyJoinNotification(
            to: afterparty.hostHandle,
            joinerHandle: userHandle,
            afterpartyName: afterparty.locationName
        )
    }
    func leaveAfterparty(afterpartyId: String, userHandle: String) async throws {
        let ref = db.collection("afterparties").document(afterpartyId)
        try await ref.updateData(["activeUsers": FieldValue.arrayRemove([userHandle])])
        await MainActor.run {
            joinedAfterparties.remove(afterpartyId)
            UserDefaults.standard.set(Array(joinedAfterparties), forKey: "joinedAfterparties")
        }
    }
    func closeAfterparty(afterpartyId: String) async throws {
        let ref = db.collection("afterparties").document(afterpartyId)
        try await ref.updateData([
            "isActive": false,
            "isAcceptingRequests": false
        ])
        
        // Update local state
        await MainActor.run {
            activeAfterparties.removeAll { $0.id == afterpartyId }
            joinedAfterparties.remove(afterpartyId)
            UserDefaults.standard.set(Array(joinedAfterparties), forKey: "joinedAfterparties")
        }
    }
    func fetchActiveAfterparties(for city: String) {
        db.collection("afterparties")
            .whereField("isActive", isEqualTo: true)
            .whereField("locationName", isGreaterThanOrEqualTo: city)
            .whereField("locationName", isLessThan: city + "~")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.activeAfterparties = documents.compactMap { document in
                    try? document.data(as: Afterparty.self)
                }.filter { !$0.isExpired }
            }
    }
    func listenToAfterpartyUpdates(afterpartyId: String, completion: @escaping (Afterparty?) -> Void) -> ListenerRegistration {
        return db.collection("afterparties").document(afterpartyId)
            .addSnapshotListener { snapshot, error in
                guard let document = snapshot else {
                    completion(nil)
                    return
                }
                let afterparty = try? document.data(as: Afterparty.self)
                completion(afterparty)
            }
    }
    private func generateUniqueSlug() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    func getAfterpartyBySlug(_ slug: String) async throws -> Afterparty? {
        let snapshot = try await db.collection("afterparties")
            .whereField("shareSlug", isEqualTo: slug)
            .getDocuments()
        return try snapshot.documents.first?.data(as: Afterparty.self)
    }
    func updateAfterparty(id: String, description: String, address: String, googleMapsLink: String, vibeTag: String) async throws {
        let ref = db.collection("afterparties").document(id)
        try await ref.updateData([
            "description": description,
            "address": address,
            "googleMapsLink": googleMapsLink,
            "vibeTag": vibeTag
        ])
    }
}

enum AfterpartyError: LocalizedError {
    case invalidInput(String)
    case creationFailed(String)
    case joinFailed(String)
    case leaveFailed(String)
    case requestFailed(String)
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message): return message
        case .creationFailed(let message): return "Failed to create afterparty: \(message)"
        case .joinFailed(let message): return "Failed to join afterparty: \(message)"
        case .leaveFailed(let message): return "Failed to leave afterparty: \(message)"
        case .requestFailed(let message): return "Request failed: \(message)"
        }
    }
}

// Add missing subviews for RadiusSlider and CreateAfterpartyButton
private struct RadiusSlider: View {
    @Binding var radius: Double
    
    // Available radius values in 0.5 mile increments
    private let radiusValues: [Double] = Array(stride(from: 0.5, through: 15.0, by: 0.5))
    
    // Convert miles to display format
    private func formatRadius(_ miles: Double) -> String {
        let validMiles = radiusValues.contains(miles) ? miles : radiusValues[0]
        if validMiles == 0.5 {
            return "0.5 mile"
        }
        if validMiles == 1.0 {
            return "1.0 mile"
        }
        return String(format: "%.1f miles", validMiles)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Radius: \(formatRadius(radius))")
                .foregroundColor(.white)
            Slider(value: Binding(
                get: { 
                    // Find closest valid value
                    let index = radiusValues.firstIndex { $0 >= radius } ?? 0
                    return radiusValues[index]
                },
                set: { newValue in
                    // Ensure value is exactly on 0.5 increment
                    let index = radiusValues.firstIndex { $0 >= newValue } ?? 0
                    radius = radiusValues[index]
                }
            ), in: 0.5...15.0, step: 0.5)
                .accentColor(.pink)
        }
        .padding(.horizontal)
    }
}

private struct CreateAfterpartyButton: View {
    @ObservedObject var locationManager: AfterpartyLocationManager
    @ObservedObject var afterpartyService: AfterpartyService
    @Binding var showVibeSelection: Bool
    
    private var hasActiveAfterparty: Bool {
        guard let userHandle = UserDefaults.standard.string(forKey: "userHandle") else { return false }
        return afterpartyService.activeAfterparties.contains { $0.hostHandle == userHandle }
    }
    
    var body: some View {
        Button(action: {
            if locationManager.currentLocation == nil {
                locationManager.requestLocation()
            }
            showVibeSelection = true
        }) {
            Text(hasActiveAfterparty ? "You already have an active afterparty" : "Create Afterparty")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(hasActiveAfterparty ? Color.gray : Color.pink)
                .cornerRadius(12)
        }
        .disabled(hasActiveAfterparty)
        .padding(.horizontal)
    }
}

// If Afterparty is not found, add a typealias to ensure the correct model is used
// typealias Afterparty = <full path to model>.Afterparty

// If Afterparty is not found, add a typealias to ensure the correct model is used
// typealias Afterparty = <full path to model>.Afterparty 
 