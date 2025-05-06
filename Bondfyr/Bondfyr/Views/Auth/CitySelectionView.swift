import SwiftUI
import Combine

struct CitySelectionView: View {
    @State private var searchText = ""
    @State private var suggestions: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var cancellable: AnyCancellable? = nil
    @FocusState private var isFocused: Bool
    
    let onCitySelected: (String) -> Void
    
    var body: some View {
        ZStack {
            // Match onboarding/profile gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(hex: "1A1A1A")]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Text("Choose Your City")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.pink)
                    TextField("Type a city name...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                        .onChange(of: searchText) { newValue in
                            fetchSuggestions(for: newValue)
                        }
                }
                .padding(14)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.top, 20)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 10)
                }
                
                // Suggestions list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \ .self) { city in
                            Button(action: {
                                onCitySelected(city)
                            }) {
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.pink)
                                    Text(city)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
                .background(Color.clear)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
        }
        .onAppear {
            isFocused = true
        }
        .ignoresSafeArea()
    }
    
    private func fetchSuggestions(for query: String) {
        guard !query.isEmpty else {
            suggestions = []
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil
        // Cancel previous request
        cancellable?.cancel()
        // Use Google Places Autocomplete API
        let apiKey = "AIzaSyAuPBQCEYfG9C0wwH5MoHRbNe4xJ8Y_3zk" // <-- Replace with your key
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&types=(cities)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: GooglePlacesAutocompleteResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Failed to fetch suggestions: \(error.localizedDescription)"
                }
            }, receiveValue: { response in
                if response.status == "OK" {
                    suggestions = response.predictions.map { $0.description }
                } else {
                    suggestions = []
                    errorMessage = response.error_message ?? "No results found."
                }
            })
    }
}

struct GooglePlacesAutocompleteResponse: Decodable {
    let predictions: [Prediction]
    let status: String
    let error_message: String?
    struct Prediction: Decodable {
        let description: String
    }
} 