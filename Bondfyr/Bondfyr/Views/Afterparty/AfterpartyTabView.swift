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
    let onCreate: (String, String, String, String, Date) -> Void
    
    // Helper to get available hours (7 PM to 4 AM)
    private var availableHours: [Date] {
        let calendar = Calendar.current
        var hours: [Date] = []
        let baseDate = isTomorrow ? calendar.date(byAdding: .day, value: 1, to: Date())! : Date()
        
        // Start from 7 PM today or tomorrow
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = 19 // 7 PM
        components.minute = 0
        var date = calendar.date(from: components)!
        
        // Add hours until 11 PM
        while components.hour! <= 23 {
            // Only add future times
            if date > Date() {
                hours.append(date)
            }
            date = calendar.date(byAdding: .hour, value: 1, to: date)!
            components.hour! += 1
        }
        
        // Add hours from 12 AM to 4 AM
        components.hour = 0
        components.day! += 1
        date = calendar.date(from: components)!
        
        for hour in 0...4 {
            components.hour = hour
            date = calendar.date(from: components)!
            hours.append(date)
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
                                        vibeTag = selectedVibeTags.joined(separator: ", ")
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
                            onCreate(vibeTag, address, description, googleMapsLink, startTime)
                            dismiss()
                        }) {
                            Text(isCreating ? "Creating..." : "Create Afterparty")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(isCreating ? Color.gray : Color.pink)
                                .cornerRadius(28)
                        }
                        .disabled(isCreating || address.isEmpty || googleMapsLink.isEmpty || selectedVibeTags.isEmpty || !isValidStartTime)
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
    @State private var radius: Double = 100.0
    @State private var isCreating: Bool = false
    @State private var createError: String? = nil
    @State private var afterparties: [Afterparty] = []
    @State private var isLoading: Bool = false
    @State private var showCityPicker = false
    @State private var selectedVibeTag = "Chill"
    @State private var showVibeSelection = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                CityHeader(cityName: cityManager.selectedCity, onTap: { showCityPicker = true })
                RadiusSlider(radius: $radius)
                CreateAfterpartyButton(locationManager: locationManager, showVibeSelection: $showVibeSelection)
                ActiveAfterpartiesSection(afterparties: afterparties, cityName: cityManager.selectedCity)
                Spacer()
            }
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
                                let afterparty = try await AfterpartyService().createAfterparty(
                                    hostHandle: userHandle,
                                    startTime: startTime,
                                    vibeTag: vibe,
                                    address: address,
                                    description: description,
                                    googleMapsLink: googleMapsLink,
                                    locationName: city
                                )
                                fetchAfterparties()
                                showVibeSelection = false
                            } catch {
                                createError = "Failed to create afterparty: \(error.localizedDescription)"
                            }
                            isCreating = false
                        }
                    }
                )
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .alert(item: Binding(
                get: { createError.map { ErrorAlert(message: $0) } },
                set: { _ in createError = nil }
            )) { error in
                Alert(title: Text("Error"), message: Text(error.message))
            }
        }
        .onAppear {
            locationManager.requestLocation()
            fetchAfterparties()
        }
    }
    
    // MARK: - Fetch
    func fetchAfterparties() {
        guard let city = cityManager.selectedCity else { return }
        isLoading = true
        AfterpartyService().fetchActiveAfterparties(for: city)
        // You may want to update afterparties array here if using a callback
        isLoading = false
    }
}

struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct AfterpartyCard: View {
    let afterparty: Afterparty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("@\(afterparty.hostHandle)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(afterparty.locationRadius))m")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Text(afterparty.locationName)
                .font(.subheadline)
                .foregroundColor(.gray)
            HStack {
                Image(systemName: "person.2.fill")
                Text("\(afterparty.guestCount) going")
                Spacer()
                Text(afterparty.startTime.formatted(date: .omitted, time: .shortened))
            }
            .font(.caption)
            .foregroundColor(.gray)
            if !afterparty.description.isEmpty {
                Text(afterparty.description)
                    .font(.body)
                    .foregroundColor(.white)
            }
            if !afterparty.address.isEmpty {
                Text("Address: \(afterparty.address)")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            if !afterparty.googleMapsLink.isEmpty {
                Link("Google Maps", destination: URL(string: afterparty.googleMapsLink)!)
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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
        try await ref.updateData(["isActive": false])
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
    var body: some View {
        VStack(alignment: .leading) {
            Text("Radius: \(Int(radius))m")
                .foregroundColor(.white)
            Slider(value: $radius, in: 50...500, step: 50)
                .accentColor(.pink)
        }
        .padding(.horizontal)
    }
}

private struct CreateAfterpartyButton: View {
    @ObservedObject var locationManager: AfterpartyLocationManager
    @Binding var showVibeSelection: Bool
    var body: some View {
        Button(action: {
            if locationManager.currentLocation == nil {
                locationManager.requestLocation()
            }
            showVibeSelection = true
        }) {
            Text("Create Afterparty")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink)
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// If Afterparty is not found, add a typealias to ensure the correct model is used
// typealias Afterparty = <full path to model>.Afterparty

// If Afterparty is not found, add a typealias to ensure the correct model is used
// typealias Afterparty = <full path to model>.Afterparty 
