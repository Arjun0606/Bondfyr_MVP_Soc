import SwiftUI
import CoreLocation

struct AfterpartyTabView: View {
    @ObservedObject var cityManager = CityManager.shared
    @State private var location: CLLocationCoordinate2D? = nil
    @State private var radius: Double = 100.0
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(2 * 3600)
    @State private var isCreating: Bool = false
    @State private var createError: String? = nil
    @State private var afterparties: [Afterparty] = []
    @State private var isLoading: Bool = false
    @State private var joinMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // City picker
                if cityManager.isLoading {
                    ProgressView().padding()
                } else {
                    Picker("City", selection: $cityManager.selectedCity) {
                        ForEach(cityManager.cities, id: \ .self) { city in
                            Text(city).tag(Optional(city))
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                }
                // Afterparty creation form
                GroupBox(label: Text("Drop Afterparty Pin").bold().foregroundColor(.white)) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Location (use current location for MVP)
                        Button(action: getCurrentLocation) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(location == nil ? "Use My Location" : "Location Set")
                            }
                            .foregroundColor(.white)
                        }
                        // Time window
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        // Radius
                        HStack {
                            Text("Radius: \(Int(radius))m")
                                .foregroundColor(.white)
                            Slider(value: $radius, in: 50...500, step: 10)
                        }
                        // Create button
                        Button(action: createAfterparty) {
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Create Afterparty")
                                    .bold()
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.pink)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .disabled(location == nil || isCreating)
                        if let error = createError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                // Active afterparties list
                Text("Active Afterparties")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top)
                if isLoading {
                    ProgressView().padding()
                } else if afterparties.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "party.popper")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                        Text("No afterparties yet in \(cityManager.selectedCity ?? "your city").")
                            .foregroundColor(.gray)
                            .font(.headline)
                    }
                    Spacer()
                } else {
                    List(afterparties) { party in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Host: \(party.userId.prefix(8))...")
                                .font(.subheadline)
                                .foregroundColor(.pink)
                            Text("\(party.startTime, style: .time) - \(party.endTime, style: .time)")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("Radius: \(Int(party.radius))m")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Button(action: { joinAfterparty(party) }) {
                                Text("Join Afterparty")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
                if let joinMessage = joinMessage {
                    Text(joinMessage)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
                Spacer()
            }
            .background(BackgroundGradientView())
            .navigationTitle("Afterparty")
            .onAppear {
                fetchAfterparties()
                if cityManager.selectedCity == nil, let first = cityManager.cities.first {
                    cityManager.selectedCity = first
                }
            }
        }
    }
    // MARK: - Location
    func getCurrentLocation() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            manager.requestLocation()
            manager.delegate = LocationDelegate { loc in
                if let loc = loc {
                    location = loc.coordinate
                }
            }
        }
    }
    // MARK: - Create
    func createAfterparty() {
        guard let loc = location, let city = cityManager.selectedCity else {
            createError = "Please set your location and city before creating an afterparty."
            return
        }
        isCreating = true
        createError = nil
        AfterpartyManager.shared.createAfterparty(city: city, location: loc, radius: radius, startTime: startTime, endTime: endTime) { result in
            isCreating = false
            switch result {
            case .success:
                fetchAfterparties()
            case .failure(let error):
                createError = error.localizedDescription
            }
        }
    }
    // MARK: - Fetch
    func fetchAfterparties() {
        guard let city = cityManager.selectedCity else { return }
        isLoading = true
        AfterpartyManager.shared.fetchActiveAfterparties(city: city) { parties in
            afterparties = parties
            isLoading = false
        }
    }
    // MARK: - Join
    func joinAfterparty(_ party: Afterparty) {
        joinMessage = "Joined afterparty! (Chat coming soon)"
    }
}

// Reuse LocationDelegate from previous code 