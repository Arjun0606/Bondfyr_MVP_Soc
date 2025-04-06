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
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
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
                
                // Event info
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
                
                // Check-in status
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if checkInManager.activeCheckIn != nil {
                    // User is checked in
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.green)
                        
                        Text("You're checked in!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Checked in at \(formatDate(checkInManager.activeCheckIn?.timestamp ?? Date()))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            checkOut()
                        }) {
                            Text("Check Out")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else if userTickets.isEmpty {
                    // No tickets
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
                } else {
                    // Has tickets but not checked in
                    VStack(spacing: 12) {
                        Text("Ready to check in?")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if userTickets.count > 1 {
                            // Choose which ticket to use
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
                
                // Attendees list
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
                                            Text(user.name)
                                                .foregroundColor(.white)
                                                .font(.body)
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
                
                Spacer()
            }
        }
        .onAppear {
            isLoading = true
            loadData()
        }
        .alert(isPresented: $showCheckInAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadData() {
        // Fetch check-in status
        checkInManager.fetchActiveCheckIn()
        
        // Fetch user's tickets for this event
        userTickets = TicketStorage.load().filter { $0.event == event.name }
        
        // Fetch attendees
        fetchAttendees()
        
        isLoading = false
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
                
                db.collection("users").document(userId).getDocument { snapshot, error in
                    defer { group.leave() }
                    
                    if let data = snapshot?.data(),
                       let name = data["name"] as? String,
                       let email = data["email"] as? String,
                       let dobTimestamp = data["dob"] as? Timestamp,
                       let phoneNumber = data["phoneNumber"] as? String {
                        
                        let dob = dobTimestamp.dateValue()
                        let user = AppUser(uid: userId, name: name, email: email, dob: dob, phoneNumber: phoneNumber)
                        users.append(user)
                    }
                }
            }
            
            group.notify(queue: .main) {
                attendees = users
            }
        }
    }
    
    private func checkIn() {
        guard let ticket = selectedTicket else { return }
        
        isLoading = true
        checkInManager.checkInToEvent(eventId: event.id.uuidString, ticketId: ticket.ticketId) { success, message in
            isLoading = false
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            isSuccess = success
            showCheckInAlert = true
            
            if success {
                loadData()
            }
        }
    }
    
    private func checkOut() {
        isLoading = true
        checkInManager.checkOut { success, message in
            isLoading = false
            alertTitle = success ? "Success" : "Error"
            alertMessage = message
            isSuccess = success
            showCheckInAlert = true
            
            if success {
                loadData()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
} 