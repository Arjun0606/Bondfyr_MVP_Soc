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
    @State private var ticketCount = 0
    @State private var prCode = ""
    @State private var instagramUsername = ""
    @State private var maleCount = 0
    @State private var femaleCount = 0
    @State private var nonBinaryCount = 0
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
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    eventImageSection
                    eventInfoSection
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    actionButtonsSection
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    ticketSection
                    
                    #if DEBUG
                    debugButtonsSection
                    #endif
                }
                .padding()
            }
            
            // Zoomed image overlay
            if let image = zoomedImage {
                ZStack {
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
                }
                .transition(.scale)
            }
            
            // Loading overlay
            if isAddingToCalendar {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                    .frame(width: 60, height: 60)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
        }
        .onAppear { resetForm() }
        // Alerts and sheets
        .alert("⚠️ Gender Ratio Notice", isPresented: $showPopup) {
            Button("I Agree") {
                generateTicket()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Entry may be denied at the venue if gender ratio is not met. This is at the discretion of the club. No refunds will be provided.")
        }
        .alert("✅ Ticket Confirmed", isPresented: $showConfirmationPopup) {
            Button("Go to Tickets") {
                presentationMode.wrappedValue.dismiss()
                tabSelection.selectedTab = .tickets
            }
        } message: {
            Text("Your ticket has been successfully purchased.")
        }
        .sheet(isPresented: $navigateToGallery) {
            EventPhotoGalleryView(event: event)
        }
        .sheet(isPresented: $showAttendeesView) {
            EventAttendeesView(event: event)
        }
        .sheet(isPresented: $navigateToEventChat) {
            EventChatView(event: event)
        }
        .confirmationDialog("Add to Calendar", isPresented: $showCalendarActionSheet) {
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
    }

    // MARK: - Debug Section
    private var debugButtonsSection: some View {
        VStack(spacing: 10) {
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
        }
        .padding(.top, 10)
    }

    func updateTicketCount() {
        ticketCount = maleCount + femaleCount + nonBinaryCount
    }

    func shouldShowWarning() -> Bool {
        return maleCount > femaleCount
    }

    func isFormValid() -> Bool {
        return !selectedTier.isEmpty && ticketCount > 0
    }
    
    func getGenderArray() -> [String] {
        var genders: [String] = []
        
        // Add male tickets
        for _ in 0..<maleCount {
            genders.append("Male")
        }
        
        // Add female tickets
        for _ in 0..<femaleCount {
            genders.append("Female")
        }
        
        // Add non-binary tickets
        for _ in 0..<nonBinaryCount {
            genders.append("Non-Binary")
        }
        
        return genders
    }

    func generateTicket() {
        TicketManager.shared.purchaseTicket(event: event, tier: selectedTier, count: ticketCount, genders: getGenderArray(), prCode: prCode) { result in
            // Handle result
        }
    }
    
    func preparePayment() {
        let ticket = TicketModel(
            event: event.name,
            tier: selectedTier,
            count: ticketCount,
            genders: getGenderArray(),
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
        ticketCount = 0
        prCode = ""
        instagramUsername = ""
        maleCount = 0
        femaleCount = 0
        nonBinaryCount = 0
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

    // MARK: - Subviews
    private var eventImageSection: some View {
        VStack {
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
                gallerySection(gallery: gallery)
            }
        }
    }
    
    func gallerySection(gallery: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(gallery, id: \.self) { imageName in
                    galleryImage(imageName: imageName)
                }
            }
            .padding(.horizontal)
        }
    }
    
    func galleryImage(imageName: String) -> some View {
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
    
    var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(event.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("\(event.location) • \(event.date)")
                .foregroundColor(.gray)
            
            mapButton
            
            Divider().background(Color.white.opacity(0.2))
            
            aboutSection
        }
    }
    
    var mapButton: some View {
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
    }
    
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this Event")
                .font(.headline)
                .foregroundColor(.white)
            Text(event.description)
                .foregroundColor(.gray)
        }
    }

    var actionButtonsSection: some View {
        VStack(spacing: 16) {
            photoGalleryButton
            liveAttendanceButton
            instagramButton
            
            // Event Chat button placed in a HStack to allow left alignment
            HStack {
                eventChatButton
                Spacer()
            }
        }
    }
    
    var photoGalleryButton: some View {
        Button(action: { navigateToGallery = true }) {
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
    }
    
    var liveAttendanceButton: some View {
        Button(action: { showAttendeesView = true }) {
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
    }
    
    var ticketSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ticketHeader
            ticketSelectionSection
            genderSelectionList
            formFields
            purchaseSection
        }
    }
    
    var ticketHeader: some View {
        Text("Select Ticket Tier")
            .font(.headline)
            .foregroundColor(.white)
    }
    
    var ticketSelectionSection: some View {
        VStack(spacing: 12) {
            ticketPicker
            ticketStepper
        }
    }
    
    var ticketPicker: some View {
        Menu {
            ForEach(tiers, id: \.self) { tier in
                Button(tier) {
                    selectedTier = tier
                }
            }
        } label: {
            HStack {
                Text(selectedTier.isEmpty ? "Select a Tier" : selectedTier)
                    .foregroundColor(selectedTier.isEmpty ? .gray : .white)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    var ticketStepper: some View {
        HStack {
            Text("Total Tickets: \(ticketCount)")
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    var genderSelectionList: some View {
        VStack(spacing: 10) {
            // Male counter
            genderCounter(label: "Male", count: $maleCount)
            
            // Female counter
            genderCounter(label: "Female", count: $femaleCount)
            
            // Non-Binary counter
            genderCounter(label: "Non-Binary", count: $nonBinaryCount)
        }
    }
    
    func genderCounter(label: String, count: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 20) {
                Button(action: {
                    if count.wrappedValue > 0 {
                        count.wrappedValue -= 1
                        updateTicketCount()
                    }
                }) {
                    Image(systemName: "minus")
                        .foregroundColor(.white)
                }
                
                Text("\(count.wrappedValue)")
                    .foregroundColor(.white)
                    .frame(minWidth: 30)
                
                Button(action: {
                    if ticketCount < 6 {
                        count.wrappedValue += 1
                        updateTicketCount()
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    var formFields: some View {
        VStack(spacing: 12) {
            customTextField(text: $instagramUsername, placeholder: "Instagram handle (optional)")
            customTextField(text: $prCode, placeholder: "PR Code (optional)")
        }
    }
    
    func customTextField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .autocapitalization(.none)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
    }
    
    var purchaseSection: some View {
        VStack(spacing: 12) {
            getTicketsButton
            disclaimerText
        }
    }
    
    var getTicketsButton: some View {
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
    }
    
    var disclaimerText: some View {
        Text("🎟️ All sales are final. No refunds or cancellations. Entry is at the club's discretion.")
            .font(.footnote)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
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
