import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct EventCheckInView: View {
    let event: Event
    
    @StateObject private var checkInManager = CheckInManager.shared
    @State private var attendees: [AppUser] = []
    @State private var showCheckInAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isSuccess = false
    @State private var isLoading = false
    @State private var userTickets: [TicketModel] = []
    @State private var selectedTicket: TicketModel?

    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea(.container, edges: .bottom)
            
            VStack(spacing: 20) {
                headerView
                eventInfoView
                checkInStatusView
                attendeesListView
            }
        }
        .onAppear {
            fetchAttendees()
            fetchUserTickets()
            checkInManager.fetchActiveCheckIn()
        }
        .alert(isPresented: $showCheckInAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private var headerView: some View {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Check In")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
    }
                
    private var eventInfoView: some View {
                HStack(spacing: 15) {
                    Image(event.venueLogoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("\(event.date) • \(event.time)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
    }
                
    private var checkInStatusView: some View {
        Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if checkInManager.activeCheckIn != nil {
                checkedInView
            } else if userTickets.isEmpty {
                noTicketsView
            } else {
                readyToCheckInView
            }
        }
    }
    
    private var checkedInView: some View {
        Group {
                    if let checkIn = checkInManager.activeCheckIn, checkIn.eventId == event.id.uuidString {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("You're checked in!")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Check-in time: \(formatDate(checkIn.timestamp))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                                Button(action: {
                                    checkOut()
                                }) {
                                    Text("Check Out")
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                        .background(Color.red.opacity(0.7))
                                        .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
        }
    }
    
    private var noTicketsView: some View {
                    VStack(spacing: 12) {
                        Text("You don't have tickets for this event")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Purchase Tickets")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.pink)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
    }
    
    private var readyToCheckInView: some View {
                    VStack(spacing: 12) {
                        Text("Ready to check in?")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if userTickets.count > 1 {
                ticketSelectionMenu
                        } else if let ticket = userTickets.first {
                            Text("\(ticket.tier) - \(ticket.count) tickets")
                                .foregroundColor(.gray)
                                .onAppear {
                                    selectedTicket = ticket
                                }
                        }
                        
                        Button(action: {
                            checkIn()
                        }) {
                            Text("Check In Now")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedTicket != nil ? Color.pink : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(selectedTicket == nil)
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
    private var ticketSelectionMenu: some View {
        Menu {
            ForEach(userTickets, id: \.ticketId) { ticket in
                Button(action: {
                    selectedTicket = ticket
                }) {
                    Text("\(ticket.tier) - \(ticket.count) tickets")
                }
            }
        } label: {
            HStack {
                Text(selectedTicket == nil ? "Select a ticket" : "\(selectedTicket!.tier) - \(selectedTicket!.count) tickets")
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var attendeesListView: some View {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Who's Here")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    if attendees.isEmpty {
                        Text("No one has checked in yet")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(attendees, id: \.uid) { user in
                                    HStack(spacing: 15) {
                                        // User avatar (simplified)
                                        ZStack {
                                            Circle()
                                                .fill(Color.pink)
                                                .frame(width: 40, height: 40)
                                            
                                            Text(String(user.name.prefix(1)).uppercased())
                                                .foregroundColor(.white)
                                                .font(.headline)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(user.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                
                                                // Simple verification badges
                                                if user.isHostVerified == true {
                                                    Text("🏆")
                                                        .font(.caption)
                                                }
                                                
                                                if user.isGuestVerified == true {
                                                    Text("⭐")
                                                        .font(.caption)
                                                }
                                            }
                                            
                                            Text("Checked in")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 15)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
    }
    
    private func fetchAttendees() {
        checkInManager.fetchEventAttendees(eventId: event.id.uuidString) { userIds in
            if userIds.isEmpty {
                attendees = []
                return
            }
            
            let db = Firestore.firestore()
            var users: [AppUser] = []
            
            let group = DispatchGroup()
            
            for userId in userIds {
                group.enter()
                
                db.collection("users").document(userId).getDocument(source: .default) { snapshot, error in
                    defer { group.leave() }
                    
                    if let data = snapshot?.data(),
                       let name = data["name"] as? String,
                       let email = data["email"] as? String,
                       let dobTimestamp = data["dob"] as? Timestamp,
                       let phoneNumber = data["phoneNumber"] as? String {
                        
                        let dob = dobTimestamp.dateValue()
                        
                        // --- Verification & Reputation ---
                        let isHostVerified = data["isHostVerified"] as? Bool ?? false
                        let isGuestVerified = data["isGuestVerified"] as? Bool ?? false
                        let hostedPartiesCount = data["hostedPartiesCount"] as? Int ?? 0
                        let attendedPartiesCount = data["attendedPartiesCount"] as? Int ?? 0
                        let hostRating = data["hostRating"] as? Double ?? 0.0
                        let guestRating = data["guestRating"] as? Double ?? 0.0
                        let hostRatingsCount = data["hostRatingsCount"] as? Int ?? 0
                        let guestRatingsCount = data["guestRatingsCount"] as? Int ?? 0
                        let totalLikesReceived = data["totalLikesReceived"] as? Int ?? 0

                        let user = AppUser(
                            uid: userId,
                            name: name,
                            email: email,
                            dob: dob,
                            phoneNumber: phoneNumber,
                            partiesHosted: hostedPartiesCount,
                            partiesAttended: attendedPartiesCount,
                            isHostVerified: isHostVerified,
                            isGuestVerified: isGuestVerified
                        )
                        users.append(user)
                    }
                }
            }
            
            group.notify(queue: .main) {
                attendees = users
            }
        }
    }
    
    private func fetchUserTickets() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("tickets")
            .whereField("event", isEqualTo: event.id.uuidString)
            .getDocuments { snapshot, error in
                if let snapshot = snapshot {
                    userTickets = snapshot.documents.compactMap { doc -> TicketModel? in
                        var data = doc.data()
                        data["ticketId"] = doc.documentID // Set the document ID as ticketId
                        return try? TicketModel(
                            event: data["event"] as? String ?? "",
                            tier: data["tier"] as? String ?? "",
                            count: data["count"] as? Int ?? 0,
                            genders: data["genders"] as? [String] ?? [],
                            prCode: data["prCode"] as? String ?? "",
                            timestamp: data["timestamp"] as? String ?? "",
                            ticketId: doc.documentID,
                            phoneNumber: data["phoneNumber"] as? String ?? ""
                        )
                    }
                }
            }
    }
    
    private func checkIn() {
        guard let ticketId = selectedTicket?.ticketId else {
            alertTitle = "Error"
            alertMessage = "Please select a ticket to check in."
            showCheckInAlert = true
            return
        }
        
        isLoading = true
        
        checkInManager.checkInToEvent(eventId: event.id.uuidString, ticketId: ticketId) { success, message in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    self.isSuccess = true
                    self.alertTitle = "Success"
                    self.alertMessage = message
                } else {
                    self.isSuccess = false
                    self.alertTitle = "Check-in Failed"
                    self.alertMessage = message
                }
                self.showCheckInAlert = true
            }
        }
    }
    
    private func checkOut() {
        isLoading = true
        
        checkInManager.checkOut { success, message in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    self.isSuccess = true
                    self.alertTitle = "Checked Out"
                    self.alertMessage = message
                } else {
                    self.isSuccess = false
                    self.alertTitle = "Check-out Failed"
                    self.alertMessage = message
                }
                self.showCheckInAlert = true
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}