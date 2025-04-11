//
//  EventDetailView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore
import Combine
import UserNotifications
import EventKit
import FirebaseStorage
import FirebaseMessaging
import FirebaseAnalytics
import GoogleSignIn

struct EventDetailView: View {
    let event: Event

    @State private var selectedTier = ""
    @State private var ticketCount = 1
    @State private var prCode = ""
    @State private var instagramUsername = ""
    @State private var genders: [String] = [""]
    @State private var showPopup = false
    @State private var showConfirmationPopup = false
    @State private var zoomedImage: String? = nil
    @State private var zoomScale: CGFloat = 1.0
    @State private var navigateToGallery = false
    @State private var navigateToCheckIn = false
    @State private var showAttendeesView = false
    @State private var navigateToEventChat = false
    
    // New state variables for calendar and offline features
    @State private var showCalendarActionSheet = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertTitle = ""
    @State private var calendarAlertMessage = ""
    @State private var showConflictsAlert = false
    @State private var conflictingEvents: [EKEvent] = []
    @State private var isAddingToCalendar = false
    @State private var showOfflineMessage = false

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var tabSelection: TabSelection

    let tiers = ["Early Bird", "Standard", "VIP"]
    let genderOptions = ["Male", "Female", "Non-Binary"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image(event.eventPosterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(10)
                        .onTapGesture {
                            zoomedImage = event.eventPosterImage
                            zoomScale = 1.0
                        }

                    if let gallery = event.galleryImages, !gallery.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(gallery, id: \.self) { imageName in
                                    Image(imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipped()
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            zoomedImage = imageName
                                            zoomScale = 1.0
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(event.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("\(event.location) • \(event.date)")
                            .foregroundColor(.gray)

                        Button(action: {
                            if let url = URL(string: event.mapsURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("Open in Google Maps", systemImage: "map")
                                .foregroundColor(.pink)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }

                        Divider().background(Color.white.opacity(0.2))

                        Text("About this Event")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(event.description)
                            .foregroundColor(.gray)

                        Divider().background(Color.white.opacity(0.2))
                        
                        // Removed Calendar and Offline buttons section

                        Button(action: {
                            navigateToGallery = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Event Photos")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: {
                            showAttendeesView = true
                        }) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                Text("Live Attendance")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // Instagram button
                        instagramButton

                        // Event chat button
                        eventChatButton

                        Divider().background(Color.white.opacity(0.2))

                        Text("Select Ticket Tier")
                            .font(.headline)
                            .foregroundColor(.white)

                        Picker("Tier", selection: $selectedTier) {
                            Text("Select a Tier").tag("")
                            ForEach(tiers, id: \.self) { tier in
                                Text(tier).tag(tier)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)

                        Stepper("Tickets: \(ticketCount)", value: $ticketCount, in: 1...6, onEditingChanged: { _ in
                            adjustGenderArray()
                        })
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .accentColor(.pink)

                        ForEach(0..<ticketCount, id: \.self) { index in
                            Menu {
                                ForEach(genderOptions, id: \.self) { gender in
                                    Button(action: {
                                        genders[index] = gender
                                    }) {
                                        Text(gender)
                                    }
                                }
                            } label: {
                                Text(genders[index].isEmpty ? "Gender" : genders[index])
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(genders[index].isEmpty ? .gray : .white)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }

                        TextField("Instagram handle (optional)", text: $instagramUsername)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        TextField("PR Code (optional)", text: $prCode)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        Button(action: {
                            if shouldShowWarning() {
                                showPopup = true
                            } else {
                                preparePayment()
                            }
                        }) {
                            Text("Get Tickets")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isFormValid() ? Color.pink : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!isFormValid())

                        Text("🎟️ All sales are final. No refunds or cancellations. Entry is at the club's discretion.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        
                        // Test notification button (for debugging)
                        Button(action: {
                            NotificationManager.shared.sendTestNotification()
                            print("Test notification scheduled")
                        }) {
                            Text("Test Notification")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                        
                        // Test chat button (for debugging)
                        Button(action: {
                            ChatManager.shared.enableTestMode()
                            navigateToEventChat = true
                        }) {
                            Text("Test Event Chat")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }

            // 🔍 Zoomed Image Popup
            if let image = zoomedImage {
                Color.black.opacity(0.9).ignoresSafeArea()
                VStack {
                    Spacer()
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .gesture(MagnificationGesture().onChanged { value in
                            zoomScale = value
                        })
                        .padding()
                    Spacer()
                    Button("Close") {
                        zoomedImage = nil
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.pink)
                    .cornerRadius(8)
                }
                .transition(.scale)
            }
        }
        .onAppear {
            resetForm()
        }
        .alert("⚠️ Gender Ratio Notice", isPresented: $showPopup, actions: {
            Button("I Agree") {
                generateTicket()
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Entry may be denied at the venue if gender ratio is not met. This is at the discretion of the club. No refunds will be provided.")
        })
        .alert("✅ Ticket Confirmed", isPresented: $showConfirmationPopup, actions: {
            Button("Go to Tickets") {
                presentationMode.wrappedValue.dismiss()
                tabSelection.selectedTab = .tickets
            }
        }, message: {
            Text("Your ticket has been successfully purchased.")
        })
        .sheet(isPresented: $navigateToGallery) {
            EventPhotoGalleryView(eventId: event.id.uuidString, eventName: event.name)
        }
        .sheet(isPresented: $showAttendeesView) {
            EventAttendeesView(event: event)
        }
        .sheet(isPresented: $navigateToEventChat) {
            EventChatView(event: event)
        }
        .confirmationDialog("Add to Calendar", isPresented: $showCalendarActionSheet, titleVisibility: .visible) {
            Button("Add to Default Calendar") {
                addEventToCalendar()
            }
            Button("Check for Conflicts") {
                checkCalendarConflicts()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(isPresented: $showCalendarAlert) {
            Alert(
                title: Text(calendarAlertTitle),
                message: Text(calendarAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Calendar Conflicts", isPresented: $showConflictsAlert) {
            Button("Add Anyway", role: .destructive) {
                addEventToCalendar()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(getConflictsMessage())
        }
        .overlay(
            Group {
                if isAddingToCalendar {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        )
    }

    func adjustGenderArray() {
        if genders.count < ticketCount {
            genders += Array(repeating: "", count: ticketCount - genders.count)
        } else if genders.count > ticketCount {
            genders = Array(genders.prefix(ticketCount))
        }
    }

    func shouldShowWarning() -> Bool {
        let maleCount = genders.filter { $0 == "Male" }.count
        let femaleCount = genders.filter { $0 == "Female" }.count
        return maleCount > femaleCount
    }

    func isFormValid() -> Bool {
        return !selectedTier.isEmpty && !genders.contains("")
    }

    func generateTicket() {
        TicketManager.shared.purchaseTicket(event: event, tier: selectedTier, count: ticketCount, genders: genders, prCode: prCode) { result in
            // Handle result
        }
    }
    
    func preparePayment() {
        let ticket = TicketModel(
            event: event.name,
            tier: selectedTier,
            count: ticketCount,
            genders: genders,
            prCode: prCode,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            ticketId: UUID().uuidString,
            phoneNumber: ""
        )
        
        // Save ticket directly without payment processing
        TicketStorage.save(ticket)
        showConfirmationPopup = true
        
        // Dismiss the current view after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Dismiss confirmation popup
            self.showConfirmationPopup = false
            
            // Dismiss current view and go to tickets tab
            self.presentationMode.wrappedValue.dismiss()
            self.tabSelection.selectedTab = .tickets
            
            // Removed: Photo contest camera opening after ticket purchase
        }
        
        Analytics.logEvent("ticket_purchased", parameters: [
            "event_name": event.name,
            "ticket_tier": selectedTier,
            "ticket_count": ticketCount
        ])
    }

    func resetForm() {
        selectedTier = ""
        ticketCount = 1
        prCode = ""
        instagramUsername = ""
        genders = [""]
    }

    private func openInstagram(for clubName: String) {
        var instagramHandle = ""
        
        switch clubName {
        case "High Spirits":
            instagramHandle = "thehighspirits"
        case "Qora":
            instagramHandle = "qora_pune"
        case "Vault":
            instagramHandle = "vault.pune"
        default:
            return
        }
        
        let instagramURL = URL(string: "instagram://user?username=\(instagramHandle)")
        let instagramWebURL = URL(string: "https://www.instagram.com/\(instagramHandle)")
        
        if let instagramURL = instagramURL, UIApplication.shared.canOpenURL(instagramURL) {
            UIApplication.shared.open(instagramURL)
        } else if let instagramWebURL = instagramWebURL {
            UIApplication.shared.open(instagramWebURL)
        }
    }

    // Social media and chat buttons
    private var instagramButton: some View {
        Button(action: {
            openInstagram(for: event.name)
        }) {
            HStack {
                Image("instagram_logo")
                    .resizable()
                    .frame(width: 22, height: 22)
                Text("Follow on Instagram")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var eventChatButton: some View {
        Button(action: {
            navigateToEventChat = true
        }) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.white)
                Text("Event Chat")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isEventChatAvailable ? Color.pink : Color.gray.opacity(0.5))
            .cornerRadius(8)
        }
        .disabled(!isEventChatAvailable)
        .overlay(
            Group {
                if !isEventChatAvailable {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 10))
                        Text("Scan QR at venue to unlock")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(y: 25)
                }
            }
        )
    }
    
    // Check if event chat is available based on check-in status
    private var isEventChatAvailable: Bool {
        if let firestoreId = event.firestoreId {
            return CheckInManager.shared.hasCheckedInToEvent(eventId: firestoreId)
        }
        return CheckInManager.shared.hasCheckedInToEvent(eventId: event.id.uuidString)
    }

    // MARK: - Calendar Integration
    
    // Add event to device calendar
    private func addEventToCalendar() {
        isAddingToCalendar = true
        
        CalendarManager.shared.addEventToCalendar(event: event) { result in
            isAddingToCalendar = false
            
            switch result {
            case .success(let eventId):
                self.calendarAlertTitle = "Success"
                self.calendarAlertMessage = "This event has been added to your calendar."
                self.showCalendarAlert = true
                
            case .failure(let error):
                self.calendarAlertTitle = "Error"
                
                switch error {
                case .accessDenied:
                    self.calendarAlertMessage = "Calendar access denied. Please enable calendar access in Settings."
                case .eventCreationFailed:
                    self.calendarAlertMessage = "Failed to create calendar event."
                default:
                    self.calendarAlertMessage = "An unexpected error occurred."
                }
                
                self.showCalendarAlert = true
            }
        }
    }
    
    // Check for calendar conflicts
    private func checkCalendarConflicts() {
        isAddingToCalendar = true
        
        CalendarManager.shared.checkForConflicts(event: event) { result in
            isAddingToCalendar = false
            
            switch result {
            case .success(let events):
                if events.isEmpty {
                    // No conflicts, add directly
                    self.addEventToCalendar()
                } else {
                    // Show conflicts
                    self.conflictingEvents = events
                    self.showConflictsAlert = true
                }
                
            case .failure(let error):
                self.calendarAlertTitle = "Error"
                
                switch error {
                case .accessDenied:
                    self.calendarAlertMessage = "Calendar access denied. Please enable calendar access in Settings."
                default:
                    self.calendarAlertMessage = "An unexpected error occurred while checking for conflicts."
                }
                
                self.showCalendarAlert = true
            }
        }
    }
    
    // Format conflicts message
    private func getConflictsMessage() -> String {
        if conflictingEvents.isEmpty {
            return "No conflicts found."
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        var message = "Potential conflicts found:\n\n"
        
        for (index, event) in conflictingEvents.prefix(3).enumerated() {
            let startTime = formatter.string(from: event.startDate)
            let endTime = formatter.string(from: event.endDate)
            
            message += "\(index + 1). \(event.title ?? "Untitled Event") (\(startTime) - \(endTime))\n"
        }
        
        if conflictingEvents.count > 3 {
            message += "\nAnd \(conflictingEvents.count - 3) more..."
        }
        
        message += "\n\nDo you still want to add this event to your calendar?"
        return message
    }

    // Add this method to trigger photo contest events with Firestore IDs
    private func startPhotoContest() {
        guard let firestoreId = event.firestoreId else {
            print("Cannot start contest: No Firestore ID")
            return
        }
        
        NotificationManager.shared.triggerPhotoContestForEvent(eventId: firestoreId)
    }
}

class TicketManager {
    static let shared = TicketManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func purchaseTicket(event: Event, tier: String, count: Int, genders: [String], prCode: String, completion: @escaping (Result<TicketModel, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "TicketManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        let ticketId = UUID().uuidString
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let ticketData: [String: Any] = [
            "ticketId": ticketId,
            "event": event.name,
            "eventId": event.id.uuidString,
            "tier": tier,
            "count": count,
            "genders": genders,
            "prCode": prCode,
            "timestamp": timestamp,
            "userId": userId,
            "status": "active"
        ]
        
        db.collection("tickets").document(ticketId).setData(ticketData) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let ticket = TicketModel(
                event: event.name,
                tier: tier,
                count: count,
                genders: genders,
                prCode: prCode,
                timestamp: timestamp,
                ticketId: ticketId,
                phoneNumber: ""
            )
            
            completion(.success(ticket))
        }
    }
    
    func fetchUserTickets(completion: @escaping (Result<[TicketModel], Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "TicketManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        db.collection("tickets")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let tickets = documents.compactMap { document -> TicketModel? in
                    let data = document.data()
                    return TicketModel(
                        event: data["event"] as? String ?? "",
                        tier: data["tier"] as? String ?? "",
                        count: data["count"] as? Int ?? 0,
                        genders: data["genders"] as? [String] ?? [],
                        prCode: data["prCode"] as? String ?? "",
                        timestamp: data["timestamp"] as? String ?? "",
                        ticketId: data["ticketId"] as? String ?? "",
                        phoneNumber: data["phoneNumber"] as? String ?? ""
                    )
                }
                
                completion(.success(tickets))
            }
    }
}

class StorageManager {
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    
    private init() {}
    
    func uploadEventImage(eventId: String, image: UIImage, type: ImageType, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "StorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        let path: String
        switch type {
        case .poster:
            path = "events/\(eventId)/poster.jpg"
        case .logo:
            path = "events/\(eventId)/logo.jpg"
        case .gallery(let index):
            path = "events/\(eventId)/gallery/\(index).jpg"
        }
        
        let storageRef = storage.child(path)
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Image uploaded successfully")
                storageRef.downloadURL { url, error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        if let url = url {
                            completion(.success(url))
                        }
                    }
                }
            }
        }
    }
    
    func downloadImage(urlString: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "StorageManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "StorageManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to image"])))
                return
            }
            
            completion(.success(image))
        }.resume()
    }
    
    enum ImageType {
        case poster
        case logo
        case gallery(index: Int)
    }
}

class SocialManager {
    static let shared = SocialManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func likePhoto(photoId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "SocialManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        let likeData: [String: Any] = [
            "userId": userId,
            "photoId": photoId,
            "timestamp": Timestamp()
        ]
        
        db.collection("likes").document("\(userId)_\(photoId)").setData(likeData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Increment like count on the photo
                self.db.collection("photo_contests").document(photoId).updateData([
                    "likeCount": FieldValue.increment(Int64(1))
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    func unlikePhoto(photoId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "SocialManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        db.collection("likes").document("\(userId)_\(photoId)").delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Decrement like count on the photo
                self.db.collection("photo_contests").document(photoId).updateData([
                    "likeCount": FieldValue.increment(Int64(-1))
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    func observePhotoLikes(photoId: String, completion: @escaping (Result<Int, Error>) -> Void) -> ListenerRegistration {
        return db.collection("photo_contests").document(photoId).addSnapshotListener { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(.success(0))
                return
            }
            
            let likeCount = data["likeCount"] as? Int ?? 0
            completion(.success(likeCount))
        }
    }
}
