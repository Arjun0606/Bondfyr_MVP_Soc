import Foundation
import Firebase

class LikeManager: ObservableObject {
    static let shared = LikeManager()
    private let db = Firestore.firestore()
    
    @Published var likesForCurrentUser: [PartyLike] = []
    
    private init() {}
    
    // Like a user and update their like count
    func likeUser(likerId: String, likedId: String, eventId: String) {
        let like = PartyLike(eventId: eventId, likerId: likerId, likedId: likedId, timestamp: Timestamp())
        
        // Add the like document
        do {
            _ = try db.collection("partyLikes").addDocument(from: like)
        } catch {
            print("Error adding like: \(error)")
            return
        }
        
        // Atomically increment the liked user's total like count
        let likedUserRef = db.collection("users").document(likedId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(likedUserRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let currentLikes = userDocument.data()?["totalLikesReceived"] as? Int ?? 0
            let newLikes = currentLikes + 1
            
            transaction.updateData(["totalLikesReceived": newLikes], forDocument: likedUserRef)
            return nil
        }) { _, error in
            if let error = error {
                print("Like count transaction failed: \(error)")
            } else {
                print("User liked and count updated successfully.")
            }
        }
    }
    
    // Unlike a user and update their like count
    func unlikeUser(likerId: String, likedId: String, eventId: String) {
        let query = db.collection("partyLikes")
            .whereField("likerId", isEqualTo: likerId)
            .whereField("likedId", isEqualTo: likedId)
            .whereField("eventId", isEqualTo: eventId)
        
        query.getDocuments { (snapshot, error) in
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("No like document found to delete.")
                return
            }
            
            // Delete the like document
            let docId = documents.first!.documentID
            self.db.collection("partyLikes").document(docId).delete()
            
            // Atomically decrement the liked user's total like count
            let likedUserRef = self.db.collection("users").document(likedId)
            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                let userDocument: DocumentSnapshot
                do {
                    try userDocument = transaction.getDocument(likedUserRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                let currentLikes = userDocument.data()?["totalLikesReceived"] as? Int ?? 0
                let newLikes = max(0, currentLikes - 1)
                
                transaction.updateData(["totalLikesReceived": newLikes], forDocument: likedUserRef)
                return nil
            }) { _, error in
                if let error = error {
                    print("Unlike count transaction failed: \(error)")
                } else {
                    print("User unliked and count updated successfully.")
                }
            }
        }
    }
    
    // Check if a user has liked another user at a specific event
    func hasLiked(likerId: String, likedId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        db.collection("partyLikes")
            .whereField("likerId", isEqualTo: likerId)
            .whereField("likedId", isEqualTo: likedId)
            .whereField("eventId", isEqualTo: eventId)
            .limit(to: 1)
            .getDocuments { (snapshot, _) in
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }

    // Fetch the users who liked a specific user at a party
    func fetchLikers(for userId: String, at eventId: String, completion: @escaping ([AppUser]) -> Void) {
        db.collection("partyLikes")
            .whereField("likedId", isEqualTo: userId)
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let likerIds = documents.compactMap { $0.data()["likerId"] as? String }
                guard !likerIds.isEmpty else {
                    completion([])
                    return
                }
                
                // Now fetch the AppUser objects for the likerIds
                self.db.collection("users").whereField("uid", in: likerIds).getDocuments { (userSnapshot, userError) in
                    guard let userDocuments = userSnapshot?.documents else {
                        completion([])
                        return
                    }
                    
                    let users = userDocuments.compactMap { try? $0.data(as: AppUser.self) }
                    completion(users)
                }
            }
    }
} 