import Foundation
import FirebaseAuth
import FirebaseFirestore

// Extension to add admin and vendor role functions
extension AuthManager {
    // Get user's role from Firestore
    func getUserRole(completion: @escaping (UserRole) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.user)
            return
        }
        
        Firestore.firestore().collection("users").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let roleString = data["role"] as? String,
                  let role = UserRole(rawValue: roleString) else {
                completion(.user)
                return
            }
            
            completion(role)
        }
    }
}

// User roles
enum UserRole: String {
    case user = "user"
    case vendor = "vendor"
    case admin = "admin"
} 