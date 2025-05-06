import SwiftUI

struct PlannerMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

struct PlannerChatView: View {
    @ObservedObject var cityManager = CityManager.shared
    @State private var messages: [PlannerMessage] = [
        PlannerMessage(isUser: false, text: "Hi! Ask me where to go tonight and I'll plan your night out.")
    ]
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            // City picker
            if cityManager.isLoading {
                ProgressView().padding()
            } else {
                Picker("City", selection: $cityManager.selectedCity) {
                    ForEach(cityManager.cities, id: \ .self) { city in
                        Text(city).tag(Optional(city))
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
            }
            // Chat
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            HStack {
                                if msg.isUser { Spacer() }
                                Text(msg.text)
                                    .padding(10)
                                    .background(msg.isUser ? Color.pink : Color(.systemGray6).opacity(0.2))
                                    .foregroundColor(msg.isUser ? .white : .white)
                                    .cornerRadius(12)
                                if !msg.isUser { Spacer() }
                            }
                        }
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Thinking...")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.clear)
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }
            // Input bar
            HStack {
                TextField("Ask about tonight's plan...", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color(.systemGray6).opacity(0.15))
                    .cornerRadius(8)
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .gray : .pink)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.bottom)
            }
        }
        .background(BackgroundGradientView())
        .navigationTitle("AI Night Planner")
        .onAppear {
            if cityManager.selectedCity == nil, let first = cityManager.cities.first {
                cityManager.selectedCity = first
            }
        }
    }
    func sendMessage() {
        guard let selectedCity = cityManager.selectedCity else { return }
        let userMsg = PlannerMessage(isUser: true, text: inputText)
        messages.append(userMsg)
        isLoading = true
        errorMessage = nil
        let userQuery = inputText
        inputText = ""
        // Fetch events/crowd data and call OpenAI
        PlannerFirestoreManager.shared.fetchEventsAndCrowd(city: selectedCity) { context in
            #if DEBUG
            // Mock AI response in development
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                messages.append(PlannerMessage(isUser: false, text: "Mock AI: Try Club XYZ for techno tonight!"))
                isLoading = false
            }
            #else
            Task {
                do {
                    let prompt = buildRAGPrompt(context: context, userQuery: userQuery)
                    let aiReply = try await OpenAIHelper.getPlannerSuggestion(prompt: prompt)
                    await MainActor.run {
                        messages.append(PlannerMessage(isUser: false, text: aiReply))
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        if (error.localizedDescription.contains("API key") || error.localizedDescription.contains("401")) {
                            errorMessage = "AI error: Missing or invalid OpenAI API key. Please set a valid key in the app."
                        } else {
                            errorMessage = "AI error: \(error.localizedDescription)"
                        }
                        isLoading = false
                    }
                }
            }
            #endif
        }
    }
    func buildRAGPrompt(context: String, userQuery: String) -> String {
        "\(context)\nUser asks: '\(userQuery)'"
    }
}

// Extend OpenAIHelper for planner
extension OpenAIHelper {
    static func getPlannerSuggestion(prompt: String) async throws -> String {
        // Use the same OpenAI API as before, but with a custom prompt
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [[
                "role": "user",
                "content": prompt
            ]],
            "max_tokens": 400,
            "temperature": 0.7
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API error"])
        }
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw NSError(domain: "OpenAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response from OpenAI"])
        }
        return content
    }
} 