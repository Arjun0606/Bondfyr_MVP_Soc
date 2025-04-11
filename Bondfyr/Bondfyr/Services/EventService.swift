import Foundation
import FirebaseFirestore

class EventService {
    static let shared = EventService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Fetch all events from Firestore
    func fetchEvents(completion: @escaping ([Event]?, Error?) -> Void) {
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching events: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([], nil)
                return
            }
            
            let events = documents.compactMap { document -> Event? in
                let data = document.data()
                let docId = document.documentID
                
                guard let name = data["name"] as? String,
                      let description = data["description"] as? String,
                      let date = data["date"] as? String,
                      let time = data["time"] as? String,
                      let venueLogoImage = data["venueLogoImage"] as? String,
                      let eventPosterImage = data["eventPosterImage"] as? String,
                      let location = data["location"] as? String,
                      let city = data["city"] as? String,
                      let mapsURL = data["mapsURL"] as? String,
                      let instagramHandle = data["instagramHandle"] as? String else {
                    return nil
                }
                
                let galleryImages = data["galleryImages"] as? [String]
                let photoContestActive = data["photoContestActive"] as? Bool ?? false
                
                return Event(
                    firestoreId: docId,
                    name: name,
                    description: description,
                    date: date,
                    time: time,
                    venueLogoImage: venueLogoImage,
                    eventPosterImage: eventPosterImage,
                    location: location,
                    city: city,
                    mapsURL: mapsURL,
                    galleryImages: galleryImages,
                    instagramHandle: instagramHandle,
                    photoContestActive: photoContestActive
                )
            }
            
            completion(events, nil)
        }
    }
    
    // Fetch a single event by ID
    func fetchEvent(id: String, completion: @escaping (Event?, Error?) -> Void) {
        db.collection("events").document(id).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching event: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let document = snapshot, document.exists, let data = document.data() else {
                completion(nil, NSError(domain: "EventService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found"]))
                return
            }
            
            guard let name = data["name"] as? String,
                  let description = data["description"] as? String,
                  let date = data["date"] as? String,
                  let time = data["time"] as? String,
                  let venueLogoImage = data["venueLogoImage"] as? String,
                  let eventPosterImage = data["eventPosterImage"] as? String,
                  let location = data["location"] as? String,
                  let city = data["city"] as? String,
                  let mapsURL = data["mapsURL"] as? String,
                  let instagramHandle = data["instagramHandle"] as? String else {
                completion(nil, NSError(domain: "EventService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid event data"]))
                return
            }
            
            let galleryImages = data["galleryImages"] as? [String]
            let photoContestActive = data["photoContestActive"] as? Bool ?? false
            
            let event = Event(
                firestoreId: id,
                name: name,
                description: description,
                date: date,
                time: time,
                venueLogoImage: venueLogoImage,
                eventPosterImage: eventPosterImage,
                location: location,
                city: city,
                mapsURL: mapsURL,
                galleryImages: galleryImages,
                instagramHandle: instagramHandle,
                photoContestActive: photoContestActive
            )
            
            completion(event, nil)
        }
    }
    
    // Toggle photo contest active status
    func togglePhotoContest(eventId: String, active: Bool, completion: @escaping (Bool, Error?) -> Void) {
        let data: [String: Any] = [
            "photoContestActive": active,
            active ? "photoContestStartTime" : "photoContestEndTime": FieldValue.serverTimestamp()
        ]
        
        db.collection("events").document(eventId).updateData(data) { error in
            if let error = error {
                print("Error toggling photo contest: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            completion(true, nil)
        }
    }
} 