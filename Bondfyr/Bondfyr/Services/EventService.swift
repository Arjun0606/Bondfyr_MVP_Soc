import Foundation
import FirebaseFirestore

class EventService {
    static let shared = EventService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Fetch all events from Firestore
    func fetchEvents(completion: @escaping ([Event]?, Error?) -> Void) {
        Task {
            do {
                let snapshot = try await db.collection("events").getDocuments()
                
                let events = snapshot.documents.compactMap { document -> Event? in
                    let data = document.data()
                    let docId = document.documentID
                    
                    guard let name = data["name"] as? String,
                          let venue = data["venue"] as? String,
                          let description = data["description"] as? String,
                          let date = data["date"] as? String,
                          let time = data["time"] as? String,
                          let hostId = data["hostId"] as? String,
                          let host = data["host"] as? String,
                          let coverPhoto = data["coverPhoto"] as? String,
                          let venueLogoImage = data["venueLogoImage"] as? String else {
                        return nil
                    }
                    
                    // Convert ticketTiers from Firestore format to Event.TicketTier array
                    let ticketTiersData = data["ticketTiers"] as? [[String: Any]] ?? []
                    let ticketTiers = ticketTiersData.compactMap { tierData -> Event.TicketTier? in
                        guard let name = tierData["name"] as? String,
                              let price = tierData["price"] as? Double,
                              let quantity = tierData["quantity"] as? Int else {
                            return nil
                        }
                        return Event.TicketTier(
                            id: UUID(),
                            name: name,
                            price: price,
                            quantity: quantity
                        )
                    }
                    
                    return Event(
                        id: UUID(uuidString: docId) ?? UUID(),
                        name: name,
                        date: date,
                        time: time,
                        venue: venue,
                        description: description,
                        hostId: hostId,
                        host: host,
                        coverPhoto: coverPhoto,
                        ticketTiers: ticketTiers,
                        venueLogoImage: venueLogoImage
                    )
                }
                
                DispatchQueue.main.async {
                    completion(events, nil)
                }
            } catch {
                
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    // Fetch a single event by ID
    func fetchEvent(id: String, completion: @escaping (Event?, Error?) -> Void) {
        Task {
            do {
                let document = try await db.collection("events").document(id).getDocument()
                
                guard document.exists, let data = document.data() else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "EventService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found"]))
                    }
                    return
                }
                
                guard let name = data["name"] as? String,
                      let venue = data["venue"] as? String,
                      let description = data["description"] as? String,
                      let date = data["date"] as? String,
                      let time = data["time"] as? String,
                      let hostId = data["hostId"] as? String,
                      let host = data["host"] as? String,
                      let coverPhoto = data["coverPhoto"] as? String,
                      let venueLogoImage = data["venueLogoImage"] as? String else {
                    DispatchQueue.main.async {
                        completion(nil, NSError(domain: "EventService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid event data"]))
                    }
                    return
                }
                
                // Convert ticketTiers from Firestore format to Event.TicketTier array
                let ticketTiersData = data["ticketTiers"] as? [[String: Any]] ?? []
                let ticketTiers = ticketTiersData.compactMap { tierData -> Event.TicketTier? in
                    guard let name = tierData["name"] as? String,
                          let price = tierData["price"] as? Double,
                          let quantity = tierData["quantity"] as? Int else {
                        return nil
                    }
                    return Event.TicketTier(
                        id: UUID(),
                        name: name,
                        price: price,
                        quantity: quantity
                    )
                }
                
                let event = Event(
                    id: UUID(uuidString: id) ?? UUID(),
                    name: name,
                    date: date,
                    time: time,
                    venue: venue,
                    description: description,
                    hostId: hostId,
                    host: host,
                    coverPhoto: coverPhoto,
                    ticketTiers: ticketTiers,
                    venueLogoImage: venueLogoImage
                )
                
                DispatchQueue.main.async {
                    completion(event, nil)
                }
            } catch {
                
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    // Toggle photo contest active status
    func togglePhotoContest(eventId: String, active: Bool, completion: @escaping (Bool, Error?) -> Void) {
        let data: [String: Any] = [
            "photoContestActive": active,
            active ? "photoContestStartTime" : "photoContestEndTime": FieldValue.serverTimestamp()
        ]
        
        Task {
            do {
                try await db.collection("events").document(eventId).updateData(data)
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }
} 