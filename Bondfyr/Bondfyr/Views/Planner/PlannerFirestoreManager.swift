import Foundation
import FirebaseFirestore

class PlannerFirestoreManager {
    static let shared = PlannerFirestoreManager()
    private let db = Firestore.firestore()
    private init() {}
    
    func fetchEventsAndCrowd(city: String, completion: @escaping (String) -> Void) {
        let today = Calendar.current.startOfDay(for: Date())
        let tonight = today.addingTimeInterval(18 * 3600) // 6pm today
        let tomorrow = today.addingTimeInterval(36 * 3600) // 6am next day
        db.collection("events")
            .whereField("city", isEqualTo: city)
            .whereField("startTime", isGreaterThan: tonight)
            .whereField("startTime", isLessThan: tomorrow)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    completion("No events found for tonight.")
                    return
                }
                let events = docs.compactMap { doc -> (String, String, String, String, String)? in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let venueId = data["venue"] as? String,
                          let genre = data["genre"] as? String,
                          let startTime = (data["startTime"] as? Timestamp)?.dateValue() else { return nil }
                    let cover = data["coverCharge"] as? String ?? "Free"
                    let timeStr = DateFormatter.localizedString(from: startTime, dateStyle: .none, timeStyle: .short)
                    return (doc.documentID, name, venueId, genre, "starts \(timeStr), cover: \(cover)")
                }
                // Fetch crowd info for all venues
                let venueIds = Set(events.map { $0.2 })
                self.fetchCrowdForVenues(venueIds: Array(venueIds)) { crowdDict in
                    let lines = events.map { (id, name, venueId, genre, info) in
                        let crowd = crowdDict[venueId] ?? "unknown"
                        return "- \(name) (\(genre), \(info), busy: \(crowd))"
                    }
                    let context = "Tonight's events:\n" + lines.joined(separator: "\n")
                    completion(context)
                }
            }
    }
    private func fetchCrowdForVenues(venueIds: [String], completion: @escaping ([String: String]) -> Void) {
        guard !venueIds.isEmpty else { completion([:]); return }
        db.collection("footTraffic").whereField(FieldPath.documentID(), in: venueIds).getDocuments { snapshot, error in
            guard let docs = snapshot?.documents, error == nil else {
                completion([:])
                return
            }
            var dict: [String: String] = [:]
            for doc in docs {
                let data = doc.data()
                let crowd = data["crowdLevel"] as? String ?? "unknown"
                dict[doc.documentID] = crowd
            }
            completion(dict)
        }
    }
} 