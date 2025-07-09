//
//  TicketConfirmationView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import EventKit

struct TicketConfirmationView: View {
    let ticket: TicketModel
    
    // State for UI controls
    @State private var showQR = false
    @State private var isOfflineAvailable = false
    @State private var isSavingOffline = false
    @State private var showOfflineMessage = false
    
    // Calendar states
    @State private var showCalendarActionSheet = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertTitle = ""
    @State private var calendarAlertMessage = ""
    @State private var showConflictsAlert = false
    @State private var conflictingEvents: [EKEvent] = []
    @State private var isAddingToCalendar = false
    
    // QR code generation
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        mainContentView
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .onAppear {
                checkOfflineAvailability()
            }
            .confirmationDialog("Add to Calendar", isPresented: $showCalendarActionSheet, titleVisibility: .visible) {
                Button("Add to Calendar") {
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
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            headerView
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Ticket details
            ticketDetailsView
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // QR Code Button
            qrCodeButtonView
            
            // QR Code Display (if shown)
            if showQR {
                qrCodeDisplayView
            }
            
            // Add to Calendar button
            calendarButtonView
            
            // Save for Offline button
            saveOfflineButtonView
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        HStack {
            Text(ticket.event)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(ticket.tier)
                .font(.subheadline)
                .padding(5)
                .background(Color.pink.opacity(0.2))
                .cornerRadius(5)
                .foregroundColor(.pink)
        }
    }
    
    private var ticketDetailsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailRow(title: "Ticket ID", value: String(ticket.ticketId.prefix(8)))
            DetailRow(title: "Date", value: formatDate(ticket.timestamp))
            DetailRow(title: "Tickets", value: "\(ticket.count) (\(formatGenders(ticket.genders)))")
            if !ticket.prCode.isEmpty {
                DetailRow(title: "PR Code", value: ticket.prCode)
            }
        }
    }
    
    private var qrCodeButtonView: some View {
        Button(action: {
            showQR.toggle()
        }) {
            HStack {
                Image(systemName: showQR ? "qrcode.viewfinder" : "qrcode")
                    .foregroundColor(.pink)
                Text(showQR ? "Hide QR Code" : "Show QR Code")
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(showQR ? 180 : 0))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var qrCodeDisplayView: some View {
        VStack {
            if let qrImage = generateQRCode(from: ticket.ticketId) {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 200)
                    .padding()
            } else {
                Text("Error generating QR code")
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var calendarButtonView: some View {
        Button(action: {
            showCalendarActionSheet = true
        }) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.pink)
                Text("Add to Calendar")
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var saveOfflineButtonView: some View {
        Button(action: {
            saveTicketForOffline()
        }) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.pink)
                Text("Save Ticket for Offline")
                    .foregroundColor(.white)
                Spacer()
                
                if isOfflineAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if isSavingOffline {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                } else if showOfflineMessage {
                    Text("✓ Saved")
                        .foregroundColor(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .disabled(isOfflineAvailable || isSavingOffline)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatGenders(_ genders: [String]) -> String {
        let counts = Dictionary(grouping: genders, by: { $0 }).mapValues { $0.count }
        
        var result = ""
        if let maleCount = counts["Male"], maleCount > 0 {
            result += "\(maleCount)M"
        }
        
        if let femaleCount = counts["Female"], femaleCount > 0 {
            if !result.isEmpty {
                result += ", "
            }
            result += "\(femaleCount)F"
        }
        
        if let otherCount = counts["Non-Binary"], otherCount > 0 {
            if !result.isEmpty {
                result += ", "
            }
            result += "\(otherCount)NB"
        }
        
        return result
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return nil
    }
    
    // Check if this ticket is available offline
    private func checkOfflineAvailability() {
        let offlineURL = OfflineDataManager.shared.getOfflineTicketURL(for: ticket.ticketId)
        isOfflineAvailable = offlineURL != nil
    }
    
    // Save ticket for offline use
    private func saveTicketForOffline() {
        isSavingOffline = true
        
        Task {
            let _ = await OfflineDataManager.shared.saveOfflineTicketAsync(for: ticket)
            
            DispatchQueue.main.async {
                self.isSavingOffline = false
                self.isOfflineAvailable = true
                
                // Show confirmation message
                withAnimation {
                    self.showOfflineMessage = true
                }
                
                // Hide message after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.showOfflineMessage = false
                    }
                }
            }
        }
    }
    
    // MARK: - Calendar Integration
    
    // Add event to device calendar
    private func addEventToCalendar() {
        isAddingToCalendar = true
        
        // CRITICAL FIX: Better date parsing with multiple format fallbacks
        let date: Date
        
        // Try ISO8601 first
        if let isoDate = ISO8601DateFormatter().date(from: ticket.timestamp) {
            date = isoDate
        } else {
            // Try standard format as fallback
            let standardFormatter = DateFormatter()
            standardFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let standardDate = standardFormatter.date(from: ticket.timestamp) {
                date = standardDate
            } else {
                // If all parsing fails, use current date as last resort
                print("Warning: Could not parse ticket timestamp '\(ticket.timestamp)', using current date")
                date = Date()
            }
        }
        
        // Create an Event-like structure for the CalendarManager
        let eventForCalendar = CalendarEvent(
            id: UUID().uuidString,
            name: ticket.event,
            description: "Your \(ticket.tier) ticket for \(ticket.event)",
            date: formattedCalendarDate(date),
            time: formattedCalendarTime(date),
            location: "",
            ticketId: ticket.ticketId
        )
        
        CalendarManager.shared.addTicketToCalendar(event: eventForCalendar) { result in
            DispatchQueue.main.async {
                self.isAddingToCalendar = false
            
            switch result {
            case .success(_):
                self.calendarAlertTitle = "Success"
                self.calendarAlertMessage = "This ticket has been added to your calendar."
                self.showCalendarAlert = true
                
            case .failure(let error):
                self.calendarAlertTitle = "Error"
                
                    // CRITICAL FIX: More comprehensive error handling
                switch error {
                case .accessDenied:
                        self.calendarAlertMessage = "Calendar access denied. Please enable calendar access in Settings → Bondfyr → Calendar."
                case .eventCreationFailed:
                        self.calendarAlertMessage = "Failed to create calendar event. Your calendar might be full or there may be a permission issue."
                default:
                        self.calendarAlertMessage = "An unexpected error occurred: \(error.localizedDescription). Please try again."
                }
                
                self.showCalendarAlert = true
                }
            }
        }
    }
    
    // Check for calendar conflicts
    private func checkCalendarConflicts() {
        isAddingToCalendar = true
        
        // CRITICAL FIX: Better date parsing with multiple format fallbacks
        let date: Date
        
        // Try ISO8601 first
        if let isoDate = ISO8601DateFormatter().date(from: ticket.timestamp) {
            date = isoDate
        } else {
            // Try standard format as fallback
            let standardFormatter = DateFormatter()
            standardFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let standardDate = standardFormatter.date(from: ticket.timestamp) {
                date = standardDate
            } else {
                // If all parsing fails, show error
                DispatchQueue.main.async {
                    self.calendarAlertTitle = "Error"
                    self.calendarAlertMessage = "Could not parse event date from ticket. Please add to calendar manually."
                    self.showCalendarAlert = true
                    self.isAddingToCalendar = false
                }
            return
            }
        }
        
        // Create an Event-like structure for the CalendarManager
        let eventForCalendar = CalendarEvent(
            id: UUID().uuidString,
            name: ticket.event,
            description: "Your \(ticket.tier) ticket for \(ticket.event)",
            date: formattedCalendarDate(date),
            time: formattedCalendarTime(date),
            location: "",
            ticketId: ticket.ticketId
        )
        
        CalendarManager.shared.checkForConflicts(event: eventForCalendar) { result in
            DispatchQueue.main.async {
                self.isAddingToCalendar = false
            
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
                
                    // CRITICAL FIX: More comprehensive error handling
                switch error {
                case .accessDenied:
                        self.calendarAlertMessage = "Calendar access denied. Please enable calendar access in Settings → Bondfyr → Calendar."
                default:
                        self.calendarAlertMessage = "An unexpected error occurred while checking for conflicts: \(error.localizedDescription). You can still add the event manually."
                }
                
                self.showCalendarAlert = true
                }
            }
        }
    }
    
    // Format conflicts message
    private func getConflictsMessage() -> String {
        if conflictingEvents.isEmpty {
            return "No conflicts found."
        }
        
        var message = "This event conflicts with:\n"
        for (index, event) in conflictingEvents.prefix(3).enumerated() {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            
            message += "\(index + 1). \(event.title ?? "Untitled") on \(formatter.string(from: event.startDate))"
            if index < min(2, conflictingEvents.count - 1) {
                message += "\n"
            }
        }
        
        if conflictingEvents.count > 3 {
            message += "\nAnd \(conflictingEvents.count - 3) more..."
        }
        
        return message
    }
    
    private func formattedCalendarDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formattedCalendarTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date) + " onwards"
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.white)
        }
    }
}
