import SwiftUI
import FirebaseFirestore

struct PartyGenderRatioDisplay: View {
    let afterparty: Afterparty
    @State private var genderRatio: GenderRatio?
    @State private var isLoading = true
    
    private var shouldShowRatio: Bool {
        let capacityPercentage = Double(afterparty.activeUsers.count) / Double(afterparty.maxGuestCount)
        return capacityPercentage >= 0.7 // Show when 70% full
    }
    
    var body: some View {
        if shouldShowRatio {
            VStack(spacing: 8) {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Loading gender ratio...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else if let ratio = genderRatio {
                    GenderRatioCard(ratio: ratio, totalGuests: afterparty.activeUsers.count)
                }
            }
            .task {
                await loadGenderRatio()
            }
        }
    }
    
    private func loadGenderRatio() async {
        isLoading = true
        
        do {
            let db = Firestore.firestore()
            var maleCount = 0
            var femaleCount = 0
            var otherCount = 0
            
            // Get gender info for all active users
            for userId in afterparty.activeUsers {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data(),
                   let gender = userData["gender"] as? String {
                    switch gender.lowercased() {
                    case "male", "m":
                        maleCount += 1
                    case "female", "f":
                        femaleCount += 1
                    default:
                        otherCount += 1
                    }
                }
            }
            
            let total = maleCount + femaleCount + otherCount
            guard total > 0 else { return }
            
            await MainActor.run {
                self.genderRatio = GenderRatio(
                    maleCount: maleCount,
                    femaleCount: femaleCount,
                    otherCount: otherCount,
                    totalCount: total
                )
                self.isLoading = false
            }
            
        } catch {
            print("🔴 GENDER: Error loading gender ratio - \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Gender Ratio Data Model
struct GenderRatio {
    let maleCount: Int
    let femaleCount: Int
    let otherCount: Int
    let totalCount: Int
    
    var malePercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(maleCount) / Double(totalCount) * 100
    }
    
    var femalePercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(femaleCount) / Double(totalCount) * 100
    }
    
    var otherPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(otherCount) / Double(totalCount) * 100
    }
    
    var displayText: String {
        if otherCount > 0 {
            return "\(Int(malePercentage))% M / \(Int(femalePercentage))% F / \(Int(otherPercentage))% Other"
        } else {
            return "\(Int(malePercentage))% Male / \(Int(femalePercentage))% Female"
        }
    }
    
    var isBalanced: Bool {
        let diff = abs(malePercentage - femalePercentage)
        return diff <= 20 // Within 20% is considered balanced
    }
}

// MARK: - Gender Ratio Card Component
struct GenderRatioCard: View {
    let ratio: GenderRatio
    let totalGuests: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("Gender Ratio")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Text("\(totalGuests) attending")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Visual ratio bar
            HStack(spacing: 2) {
                if ratio.maleCount > 0 {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: CGFloat(ratio.malePercentage) * 1.5, height: 4)
                }
                if ratio.femaleCount > 0 {
                    Rectangle()
                        .fill(Color.pink)
                        .frame(width: CGFloat(ratio.femalePercentage) * 1.5, height: 4)
                }
                if ratio.otherCount > 0 {
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: CGFloat(ratio.otherPercentage) * 1.5, height: 4)
                }
                Spacer()
            }
            .cornerRadius(2)
            
            // Ratio text
            HStack {
                Text(ratio.displayText)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                if ratio.isBalanced {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Balanced")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        PartyGenderRatioDisplay(afterparty: Afterparty.sampleData)
        
        GenderRatioCard(
            ratio: GenderRatio(maleCount: 8, femaleCount: 12, otherCount: 1, totalCount: 21),
            totalGuests: 21
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
} 