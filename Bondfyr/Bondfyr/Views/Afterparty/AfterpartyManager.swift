import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct Afterparty: Identifiable {
    let id: String
    let userId: String
    let geoPoint: CLLocationCoordinate2D
    let radius: Double
    let startTime: Date
    let endTime: Date
    let city: String
}

class AfterpartyManager: ObservableObject {
    static let shared = AfterpartyManager()
    private let db = Firestore.firestore()
    private init() {}
    
    func createAfterparty(city: String, location: CLLocationCoordinate2D, radius: Double, startTime: Date, endTime: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "Afterparty", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])) )
            return
        }
        let data: [String: Any] = [
            "userId": userId,
            "geoPoint": GeoPoint(latitude: location.latitude, longitude: location.longitude),
            "radius": radius,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "city": city
        ]
        db.collection("afterparties").addDocument(data: data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    func fetchActiveAfterparties(city: String, completion: @escaping ([Afterparty]) -> Void) {
        let now = Date()
        db.collection("afterparties")
            .whereField("city", isEqualTo: city)
            .whereField("endTime", isGreaterThan: Timestamp(date: now))
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else {
                    completion([])
                    return
                }
                let parties = docs.compactMap { doc -> Afterparty? in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          let geo = data["geoPoint"] as? GeoPoint,
                          let radius = data["radius"] as? Double,
                          let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
                          let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                          let city = data["city"] as? String else { return nil }
                    return Afterparty(id: doc.documentID, userId: userId, geoPoint: CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude), radius: radius, startTime: startTime, endTime: endTime, city: city)
                }
                completion(parties)
            }
    }
} 