import SwiftUI
import FirebaseFirestore

struct EventAttendeesView: View {
    let event: Event
    
    @State private var attendeeCount: Int = 0
    @State private var isLoading = true
    @State private var listener: ListenerRegistration?
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
                            .frame(width: 44, height: 44, alignment: .center)
                    }
                    
                    Spacer()
                    
                    Text("Live Attendance")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer with width to balance the layout
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
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
                        
                        Text(event.city)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Attendance count card
                VStack(spacing: 15) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .frame(height: 60)
                    } else {
                        VStack(spacing: 15) {
                            HStack(alignment: .top, spacing: 20) {
                                VStack(spacing: 8) {
                                    Text("\(attendeeCount)")
                                        .font(.system(size: 60, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Current Guests")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 160, alignment: .center)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "person.3.fill")
                                            .foregroundColor(.pink)
                                        
                                        Text("Live Attendance")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Real-time count of guests who have scanned their QR code at the entrance")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            
                            HStack(alignment: .top) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                                    .padding(.top, 2)
                                
                                Text("For privacy reasons, individual attendee information is not displayed")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Visual representation of attendance
                if !isLoading {
                    VStack(spacing: 15) {
                        Text("Attendance Trend")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        // Simple visual attendance indicator
                        HStack(spacing: 2) {
                            ForEach(0..<10, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(i < min(attendeeCount/10, 10) ? Color.pink : Color.gray.opacity(0.3))
                                    .frame(height: 50)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Attendance scale indicator
                        HStack {
                            Text("Empty")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text("Crowded")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Empty state
                if attendeeCount == 0 && !isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.sequence.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No one has checked in yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Check back later for live updates")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding()
                }
                
                Spacer()
                
                // Follow venue on Instagram button
                Button(action: {
                    openInstagram(handle: event.instagramHandle)
                }) {
                    HStack {
                        Image(systemName: "camera.circle.fill")
                        Text("Follow \(event.name) on Instagram")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.pink.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .onAppear {
            startListeningForAttendees()
        }
        .onDisappear {
            listener?.remove()
        }
    }
    
    private func startListeningForAttendees() {
        isLoading = true
        
        let db = Firestore.firestore()
        listener = db.collection("check_ins")
            .whereField("eventId", isEqualTo: event.id.uuidString)
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                isLoading = false
                
                guard let documents = snapshot?.documents else {
                    attendeeCount = 0
                    return
                }
                
                attendeeCount = documents.count
            }
    }
    
    private func openInstagram(handle: String) {
        let instagramURL = URL(string: "instagram://user?username=\(handle)")
        let instagramWebURL = URL(string: "https://www.instagram.com/\(handle)")
        
        if let instagramURL = instagramURL, UIApplication.shared.canOpenURL(instagramURL) {
            UIApplication.shared.open(instagramURL)
        } else if let instagramWebURL = instagramWebURL {
            UIApplication.shared.open(instagramWebURL)
        }
    }
} 