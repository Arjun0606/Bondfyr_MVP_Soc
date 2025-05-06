import SwiftUI

struct PreGameView: View {
    @State private var groupSize: Int = 2
    @State private var budget: Double = 1000
    @State private var suggestion: String? = nil
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Pre-Game Planner")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 40)
            Stepper("Group Size: \(groupSize)", value: $groupSize, in: 1...20)
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .foregroundColor(.white)
            HStack {
                Text("Budget: ₹\(Int(budget))")
                    .foregroundColor(.white)
                Slider(value: $budget, in: 500...10000, step: 100)
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            Button(action: getSuggestion) {
                Text("Get Drink & Snack Bundle Suggestion")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.pink)
                    .cornerRadius(12)
            }
            .disabled(isLoading)
            if isLoading {
                ProgressView()
            }
            if let suggestion = suggestion {
                Text(suggestion)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
            }
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .padding()
        .background(BackgroundGradientView())
        .navigationTitle("Pre-Game")
    }
    func getSuggestion() {
        isLoading = true
        error = nil
        // For MVP, use a mock AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            suggestion = "Mock AI: For \(groupSize) people and ₹\(Int(budget)), get 2 bottles of vodka, 6 mixers, and 3 snack platters."
            isLoading = false
        }
    }
} 