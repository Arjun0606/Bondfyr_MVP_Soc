import Foundation
import FirebaseFirestore
import CoreLocation

struct ItemPrice: Identifiable {
    let id: String
    let itemName: String
    let price: Double
    let vendor: String
    let updatedAt: Date
}

struct ThekaFirestore: Identifiable {
    let id: String
    let name: String
    let address: String
    let location: CLLocationCoordinate2D
    let hours: String
    let updatedAt: Date
}

class PreGameFirestoreManager {
    static let shared = PreGameFirestoreManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func fetchItemPrices(completion: @escaping (Result<[ItemPrice], Error>) -> Void) {
        db.collection("itemPrices").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let docs = snapshot?.documents else {
                completion(.success([]))
                return
            }
            let items = docs.compactMap { doc -> ItemPrice? in
                let data = doc.data()
                guard let itemName = data["itemName"] as? String,
                      let price = data["price"] as? Double,
                      let vendor = data["vendor"] as? String,
                      let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else { return nil }
                return ItemPrice(id: doc.documentID, itemName: itemName, price: price, vendor: vendor, updatedAt: updatedAt)
            }
            completion(.success(items))
        }
    }
    
    func fetchThekas(completion: @escaping (Result<[ThekaFirestore], Error>) -> Void) {
        db.collection("thekas").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let docs = snapshot?.documents else {
                completion(.success([]))
                return
            }
            let thekas = docs.compactMap { doc -> ThekaFirestore? in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let address = data["address"] as? String,
                      let geo = data["location"] as? GeoPoint,
                      let hours = data["hours"] as? String,
                      let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else { return nil }
                let location = CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude)
                return ThekaFirestore(id: doc.documentID, name: name, address: address, location: location, hours: hours, updatedAt: updatedAt)
            }
            completion(.success(thekas))
        }
    }
} 