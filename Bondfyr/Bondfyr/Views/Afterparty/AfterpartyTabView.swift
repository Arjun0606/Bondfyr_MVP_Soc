import SwiftUI
import CoreLocation
import FirebaseFirestore
import CoreLocationUI

struct AfterpartyTabView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingCreateSheet = false
    @State private var searchText = ""
    @State private var selectedRadius: Double = 5.0 // 5 miles default
    @State private var showLocationDeniedAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // City Picker
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.pink)
                    if locationManager.authorizationStatus == .denied {
                        Text("Location Access Required")
                            .foregroundColor(.red)
                    } else {
                        Text(locationManager.currentCity ?? "Loading...")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .onTapGesture {
                    if locationManager.authorizationStatus == .denied {
                        showLocationDeniedAlert = true
                    }
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search afterparties...", text: $searchText)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Distance Slider
                VStack(alignment: .leading) {
                    Text("Distance: \(Int(selectedRadius)) miles")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Slider(value: $selectedRadius, in: 1...20) { _ in
                        if let location = locationManager.location?.coordinate {
                            afterpartyManager.updateLocation(location)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Create Afterparty Button
                Button(action: { 
                    if locationManager.authorizationStatus == .denied {
                        showLocationDeniedAlert = true
                    } else {
                        showingCreateSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Afterparty")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                
                if afterpartyManager.isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Finding nearby afterparties...")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding()
                } else if locationManager.authorizationStatus == .denied {
                    VStack {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Location Access Required")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("Please enable location services in Settings to find nearby afterparties.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if afterpartyManager.nearbyAfterparties.isEmpty {
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
                    // Afterparty List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(afterpartyManager.nearbyAfterparties) { afterparty in
                                AfterpartyCard(afterparty: afterparty)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAfterpartyView(
                currentLocation: locationManager.location?.coordinate,
                currentCity: locationManager.currentCity ?? ""
            )
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation?.coordinate {
                afterpartyManager.updateLocation(location)
            }
        }
        .alert("Location Access Required", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable location services in Settings to use this feature.")
        }
    }
}

struct AfterpartyCard: View {
    let afterparty: Afterparty
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
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
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text(afterparty.vibeTag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.3))
                        .foregroundColor(.purple)
                        .cornerRadius(12)
                }
                
                // Description
                if !afterparty.description.isEmpty {
                    Text(afterparty.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                // Footer with time and host info
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.pink)
                        Text(formatTime(afterparty.startTime))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                        Text(afterparty.hostHandle)
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                }
            }
            .padding(16)
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            AfterpartyDetailView(afterparty: afterparty)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CreateAfterpartyView: View {
    let currentLocation: CLLocationCoordinate2D?
    let currentCity: String
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var selectedVibes: Set<String> = []
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
    @State private var address = ""
    @State private var locationName = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var error: Error?
    
    let vibeOptions = ["Chill", "Lit", "Exclusive", "Everyone Welcome", "BYOB", "House", "Rooftop", "Pool Party"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Vibe Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Vibes (Choose Multiple)")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(vibeOptions, id: \.self) { vibe in
                                Button(action: {
                                    if selectedVibes.contains(vibe) {
                                        selectedVibes.remove(vibe)
                                    } else {
                                        selectedVibes.insert(vibe)
                                    }
                                }) {
                                    Text(vibe)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedVibes.contains(vibe) ? Color.purple : Color(.systemGray5))
                                        .foregroundColor(selectedVibes.contains(vibe) ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start Time")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            Button(action: { startTime = Date() }) {
                                Text("Today")
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                    .background(Color.pink)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                            }
                            
                            Button(action: {
                                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                                    startTime = tomorrow
                                }
                            }) {
                                Text("Tomorrow")
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(20)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([4,5,6,7], id: \.self) { hour in
                                    let time = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: startTime) ?? startTime
                                    Button(action: { startTime = time }) {
                                        Text("\(hour):00 am")
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        
                        Text("Ends at \(formatTime(endTime))")
                            .foregroundColor(.gray)
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        TextField("Location Name", text: $locationName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Address (flat/house number, street, etc.)", text: $address)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Create Afterparty")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Create") {
                    createAfterparty()
                }
                .disabled(isCreating || selectedVibes.isEmpty || locationName.isEmpty || address.isEmpty)
            )
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
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
                    locationName: locationName,
                    description: description,
                    address: address,
                    googleMapsLink: "",
                    vibeTag: Array(selectedVibes).joined(separator: ", ")
                )
                await MainActor.run {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                self.error = error
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