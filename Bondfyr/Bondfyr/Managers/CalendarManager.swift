//
//  CalendarManager.swift
//  Bondfyr
//
//  Created by Claude AI on 12/07/25.
//

import Foundation
import EventKit
import UIKit

// Simple data structure for calendar events
struct CalendarEvent {
    let id: String
    let name: String
    let description: String
    let date: String
    let time: String
    let location: String
    let ticketId: String
}

enum CalendarError: Error {
    case accessDenied
    case eventCreationFailed
    case eventNotFound
    case unknown(String)
}

class CalendarManager {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    private var hasCalendarAccess = false
    
    private init() {
        checkCalendarAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    private func checkCalendarAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized:
            hasCalendarAccess = true
        case .denied, .restricted:
            hasCalendarAccess = false
        case .notDetermined:
            // We'll request access when needed
            hasCalendarAccess = false
        @unknown default:
            hasCalendarAccess = false
        }
    }
    
    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            Task {
                let accessGranted = try? await eventStore.requestFullAccessToEvents()
                DispatchQueue.main.async {
                    self.hasCalendarAccess = accessGranted ?? false
                    completion(self.hasCalendarAccess)
                }
            }
        } else {
            // For earlier iOS versions
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    self.hasCalendarAccess = granted
                    completion(granted)
                }
            }
        }
    }
    
    // MARK: - Calendar Operations
    
    // Add event to calendar with completion handler
    func addEventToCalendar(event: Event, completion: @escaping (Result<String, CalendarError>) -> Void) {
        if !hasCalendarAccess {
            requestCalendarAccess { granted in
                if granted {
                    self.createCalendarEvent(event: event, completion: completion)
                } else {
                    completion(.failure(.accessDenied))
                }
            }
        } else {
            createCalendarEvent(event: event, completion: completion)
        }
    }
    
    // Add ticket to calendar
    func addTicketToCalendar(event: CalendarEvent, completion: @escaping (Result<String, CalendarError>) -> Void) {
        if !hasCalendarAccess {
            requestCalendarAccess { granted in
                if granted {
                    self.createTicketCalendarEvent(event: event, completion: completion)
                } else {
                    completion(.failure(.accessDenied))
                }
            }
        } else {
            createTicketCalendarEvent(event: event, completion: completion)
        }
    }
    
    // Create the actual calendar event
    private func createCalendarEvent(event: Event, completion: @escaping (Result<String, CalendarError>) -> Void) {
        // Parse date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        guard let eventDate = dateFormatter.date(from: event.date) else {
            completion(.failure(.eventCreationFailed))
            return
        }
        
        // Extract start time
        var startTime = Date()
        if event.time.contains("onwards") {
            let timeString = event.time.replacingOccurrences(of: " onwards", with: "")
            if let parsedTime = timeFormatter.date(from: timeString) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                startTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                                          minute: timeComponents.minute ?? 0, 
                                          second: 0, 
                                          of: eventDate) ?? eventDate
            } else {
                startTime = eventDate
            }
        } else {
            startTime = eventDate
        }
        
        // Create end time (default to 3 hours after start)
        let endTime = Calendar.current.date(byAdding: .hour, value: 3, to: startTime) ?? startTime
        
        // Create the event
        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = event.name
        calendarEvent.location = event.location
        calendarEvent.notes = event.description
        calendarEvent.startDate = startTime
        calendarEvent.endDate = endTime
        calendarEvent.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add an alarm 2 hours before
        let alarm = EKAlarm(relativeOffset: -7200) // 2 hours in seconds
        calendarEvent.addAlarm(alarm)
        
        // Add custom metadata to identify this event later
        calendarEvent.setValue("bondfyr_\(event.id.uuidString)", forKey: "bondfyrEventId")
        
        do {
            try eventStore.save(calendarEvent, span: .thisEvent)
            completion(.success(calendarEvent.eventIdentifier))
        } catch {
            completion(.failure(.eventCreationFailed))
        }
    }
    
    // Create ticket calendar event from CalendarEvent struct
    private func createTicketCalendarEvent(event: CalendarEvent, completion: @escaping (Result<String, CalendarError>) -> Void) {
        // Parse date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        guard let eventDate = dateFormatter.date(from: event.date) else {
            completion(.failure(.eventCreationFailed))
            return
        }
        
        // Extract start time
        var startTime = Date()
        if event.time.contains("onwards") {
            let timeString = event.time.replacingOccurrences(of: " onwards", with: "")
            if let parsedTime = timeFormatter.date(from: timeString) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                startTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                                          minute: timeComponents.minute ?? 0, 
                                          second: 0, 
                                          of: eventDate) ?? eventDate
            } else {
                startTime = eventDate
            }
        } else {
            startTime = eventDate
        }
        
        // Create end time (default to 3 hours after start)
        let endTime = Calendar.current.date(byAdding: .hour, value: 3, to: startTime) ?? startTime
        
        // Create the event
        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = event.name
        calendarEvent.location = event.location
        calendarEvent.notes = event.description
        calendarEvent.startDate = startTime
        calendarEvent.endDate = endTime
        calendarEvent.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add an alarm 2 hours before
        let alarm = EKAlarm(relativeOffset: -7200) // 2 hours in seconds
        calendarEvent.addAlarm(alarm)
        
        // Add custom metadata to identify this ticket event later
        calendarEvent.setValue("bondfyr_ticket_\(event.ticketId)", forKey: "bondfyrTicketId")
        
        do {
            try eventStore.save(calendarEvent, span: .thisEvent)
            completion(.success(calendarEvent.eventIdentifier))
        } catch {
            completion(.failure(.eventCreationFailed))
        }
    }
    
    // Check for calendar conflicts
    func checkForConflicts(event: Event, completion: @escaping (Result<[EKEvent], CalendarError>) -> Void) {
        if !hasCalendarAccess {
            requestCalendarAccess { granted in
                if granted {
                    self.findConflictingEvents(event: event, completion: completion)
                } else {
                    completion(.failure(.accessDenied))
                }
            }
        } else {
            findConflictingEvents(event: event, completion: completion)
        }
    }
    
    // Check for calendar conflicts with CalendarEvent
    func checkForConflicts(event: CalendarEvent, completion: @escaping (Result<[EKEvent], CalendarError>) -> Void) {
        if !hasCalendarAccess {
            requestCalendarAccess { granted in
                if granted {
                    self.findConflictingEvents(event: event, completion: completion)
                } else {
                    completion(.failure(.accessDenied))
                }
            }
        } else {
            findConflictingEvents(event: event, completion: completion)
        }
    }
    
    // Find conflicts between this event and existing calendar events
    private func findConflictingEvents(event: Event, completion: @escaping (Result<[EKEvent], CalendarError>) -> Void) {
        // Parse event date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        
        guard let eventDate = dateFormatter.date(from: event.date) else {
            completion(.failure(.eventNotFound))
            return
        }
        
        // Create a window for the event (approximately)
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let startDate = calendar.date(from: startComponents) ?? eventDate
        
        // End date (the entire day)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        
        // Create a predicate to search for events in this time range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Get events in this range
        let calendarEvents = eventStore.events(matching: predicate)
        
        // Filter out any events we might have created ourselves
        let conflictingEvents = calendarEvents.filter { existingEvent in
            // Skip events we created ourselves
            if existingEvent.value(forKey: "bondfyrEventId") != nil {
                return false
            }
            
            // Check for overlap with our approximate event time
            // Assuming our event is in the evening (e.g., 7pm to midnight)
            // This is a rough approximation
            let eventStartHour = 19 // 7pm
            let eventEndHour = 23 // 11pm
            
            let existingEventStartHour = calendar.component(.hour, from: existingEvent.startDate)
            let existingEventEndHour = calendar.component(.hour, from: existingEvent.endDate)
            
            // Check if the existing event overlaps with our approximated timeframe
            return (existingEventStartHour >= eventStartHour && existingEventStartHour <= eventEndHour) ||
                   (existingEventEndHour >= eventStartHour && existingEventEndHour <= eventEndHour) ||
                   (existingEventStartHour <= eventStartHour && existingEventEndHour >= eventEndHour)
        }
        
        completion(.success(conflictingEvents))
    }
    
    // Find conflicts between a ticket event and existing calendar events
    private func findConflictingEvents(event: CalendarEvent, completion: @escaping (Result<[EKEvent], CalendarError>) -> Void) {
        // Parse event date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        
        guard let eventDate = dateFormatter.date(from: event.date) else {
            completion(.failure(.eventCreationFailed))
            return
        }
        
        // Create a window for the event (approximately)
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let startDate = calendar.date(from: startComponents) ?? eventDate
        
        // End date (the entire day)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        
        // Create a predicate to search for events in this time range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Get events in this range
        let calendarEvents = eventStore.events(matching: predicate)
        
        // Filter out any events we might have created ourselves
        let conflictingEvents = calendarEvents.filter { existingEvent in
            // Skip events we created ourselves
            if existingEvent.value(forKey: "bondfyrEventId") != nil || 
               existingEvent.value(forKey: "bondfyrTicketId") != nil {
                return false
            }
            
            // Check for overlap with our approximate event time
            // Extract time from event.time (assumed format: "7:00 PM onwards")
            var eventStartHour = 19 // Default to 7pm
            
            if event.time.contains(":") {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                
                let timeString = event.time.replacingOccurrences(of: " onwards", with: "")
                if let parsedTime = timeFormatter.date(from: timeString) {
                    eventStartHour = calendar.component(.hour, from: parsedTime)
                }
            }
            
            let eventEndHour = min(eventStartHour + 4, 23) // Assume 4 hours or until 11pm
            
            let existingEventStartHour = calendar.component(.hour, from: existingEvent.startDate)
            let existingEventEndHour = calendar.component(.hour, from: existingEvent.endDate)
            
            // Check if the existing event overlaps with our approximated timeframe
            return (existingEventStartHour >= eventStartHour && existingEventStartHour <= eventEndHour) ||
                   (existingEventEndHour >= eventStartHour && existingEventEndHour <= eventEndHour) ||
                   (existingEventStartHour <= eventStartHour && existingEventEndHour >= eventEndHour)
        }
        
        completion(.success(conflictingEvents))
    }
    
    // Remove event from calendar
    func removeEventFromCalendar(eventId: String, completion: @escaping (Bool) -> Void) {
        if !hasCalendarAccess {
            completion(false)
            return
        }
        
        guard let calendarEvent = findEvent(withIdentifier: eventId) else {
            completion(false)
            return
        }
        
        do {
            try eventStore.remove(calendarEvent, span: .thisEvent)
            completion(true)
        } catch {
            completion(false)
        }
    }
    
    // Find an event by its identifier
    private func findEvent(withIdentifier identifier: String) -> EKEvent? {
        return eventStore.event(withIdentifier: identifier)
    }
    
    // Open iOS Calendar app
    func openCalendarApp() {
        if let calendarURL = URL(string: "calshow://") {
            UIApplication.shared.open(calendarURL)
        }
    }
} 