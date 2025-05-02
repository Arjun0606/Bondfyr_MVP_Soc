import Foundation
import FirebaseFirestore
import FirebaseAuth
import EventKit
import UserNotifications

class SavedEventsManager: ObservableObject {
    static let shared = SavedEventsManager()
    private let db = Firestore.firestore()
    private let eventStore = EKEventStore()
    @Published var savedEvents: [Event] = []
    
    private init() {
        requestNotificationPermissions()
    }
    
    // Request notification permissions
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
    }
    
    // Save an event
    func saveEvent(_ event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "SavedEventsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        guard let eventKey = event.firestoreId else {
            completion(.failure(NSError(domain: "SavedEventsManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Event missing Firestore ID, cannot save."])));
            return
        }
        let savedEventData: [String: Any] = [
            "eventId": eventKey,
            "userId": userId,
            "savedAt": Timestamp(date: Date()),
            "reminderSet": false
        ]
        db.collection("saved_events").document("\(userId)_\(eventKey)").setData(savedEventData) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            DispatchQueue.main.async {
                var updatedEvent = event
                updatedEvent.isSaved = true
                if let index = self.savedEvents.firstIndex(where: { $0.firestoreId == eventKey }) {
                    self.savedEvents[index] = updatedEvent
                } else {
                    self.savedEvents.append(updatedEvent)
                }
            }
            self.fetchSavedEvents { _ in
                completion(.success(()))
            }
        }
    }
    
    // Unsave an event
    func unsaveEvent(_ event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "SavedEventsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        guard let eventKey = event.firestoreId else {
            completion(.failure(NSError(domain: "SavedEventsManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Event missing Firestore ID, cannot unsave."])));
            return
        }
        db.collection("saved_events").document("\(userId)_\(eventKey)").delete { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            DispatchQueue.main.async {
                self.savedEvents.removeAll { $0.firestoreId == eventKey }
            }
            self.fetchSavedEvents { _ in
                completion(.success(()))
            }
            self.removeReminder(for: event) { _ in }
        }
    }
    
    // Fetch saved events for current user
    func fetchSavedEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "SavedEventsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        db.collection("saved_events")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                let eventIds = documents.compactMap { $0.data()["eventId"] as? String }
                let group = DispatchGroup()
                var events: [Event] = []
                for eventId in eventIds {
                    group.enter()
                    EventService.shared.fetchEvent(id: eventId) { event, error in
                        if let event = event {
                            var savedEvent = event
                            savedEvent.isSaved = true
                            events.append(savedEvent)
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    let uniqueEvents = Dictionary(grouping: events, by: { $0.firestoreId ?? "" })
                        .compactMap { $0.value.first }
                    self?.savedEvents = uniqueEvents
                    completion(.success(uniqueEvents))
                }
            }
    }
    
    // Set a reminder for an event
    func setReminder(for event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        // Request calendar access if needed
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                if granted {
                    self.createCalendarEvent(for: event, completion: completion)
                } else {
                    completion(.failure(error ?? NSError(domain: "SavedEventsManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])))
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                if granted {
                    self.createCalendarEvent(for: event, completion: completion)
                } else {
                    completion(.failure(error ?? NSError(domain: "SavedEventsManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])))
                }
            }
        }
    }
    
    // Create calendar event
    private func createCalendarEvent(for event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = event.name
        calendarEvent.notes = event.description
        calendarEvent.location = event.location
        
        // Parse date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        guard let eventDate = dateFormatter.date(from: event.date),
              let eventTime = timeFormatter.date(from: event.time.replacingOccurrences(of: " onwards", with: "")) else {
            completion(.failure(NSError(domain: "SavedEventsManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])))
            return
        }
        
        // Combine date and time
        let calendar = Calendar.current
        let eventDateTime = calendar.date(bySettingHour: calendar.component(.hour, from: eventTime),
                                       minute: calendar.component(.minute, from: eventTime),
                                       second: 0,
                                       of: eventDate) ?? eventDate
        
        calendarEvent.startDate = eventDateTime
        calendarEvent.endDate = calendar.date(byAdding: .hour, value: 4, to: eventDateTime) // Default 4-hour duration
        
        // Set reminder alerts
        let reminder1Hour = EKAlarm(relativeOffset: -3600) // 1 hour before
        let reminder1Day = EKAlarm(relativeOffset: -86400) // 1 day before
        calendarEvent.addAlarm(reminder1Hour)
        calendarEvent.addAlarm(reminder1Day)
        
        // Save to default calendar
        calendarEvent.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(calendarEvent, span: .thisEvent)
            
            // Update Firestore with reminder status
            if let userId = Auth.auth().currentUser?.uid {
                db.collection("saved_events").document("\(userId)_\(event.id.uuidString)").updateData([
                    "reminderSet": true,
                    "calendarEventId": calendarEvent.eventIdentifier ?? ""
                ]) { error in
                    if let error = error {
                        print("Error updating reminder status: \(error.localizedDescription)")
                    }
                }
            }
            
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // Remove reminder for an event
    func removeReminder(for event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "SavedEventsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        // Get the saved event document to find the calendar event ID
        db.collection("saved_events").document("\(userId)_\(event.id.uuidString)").getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let calendarEventId = snapshot?.data()?["calendarEventId"] as? String,
               let calendarEvent = self.eventStore.event(withIdentifier: calendarEventId) {
                do {
                    try self.eventStore.remove(calendarEvent, span: .thisEvent)
                    
                    // Update Firestore
                    snapshot?.reference.updateData([
                        "reminderSet": false,
                        "calendarEventId": FieldValue.delete()
                    ])
                    
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.success(()))
            }
        }
    }
} 