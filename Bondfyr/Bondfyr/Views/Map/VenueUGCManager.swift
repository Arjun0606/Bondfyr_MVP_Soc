import Foundation
import FirebaseFirestore

struct UGCPost: Identifiable {
    let id: String
    let mediaURL: String
    let type: String // "photo" or "video"
    let createdAt: Date
    let userId: String
    let venueId: String
}

class VenueUGCManager: ObservableObject {
    static let shared = VenueUGCManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func fetchRecentUGC(for venueId: String, limit: Int = 4, completion: @escaping ([UGCPost]) -> Void) {
        db.collection("ugc")
            .whereField("venueId", isEqualTo: venueId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    completion([])
                    return
                }
                let posts = docs.compactMap { doc -> UGCPost? in
                    let data = doc.data()
                    guard let mediaURL = data["mediaURL"] as? String,
                          let type = data["type"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          let userId = data["userId"] as? String,
                          let venueId = data["venueId"] as? String else { return nil }
                    return UGCPost(id: doc.documentID, mediaURL: mediaURL, type: type, createdAt: createdAt, userId: userId, venueId: venueId)
                }
                completion(posts)
            }
    }
} 