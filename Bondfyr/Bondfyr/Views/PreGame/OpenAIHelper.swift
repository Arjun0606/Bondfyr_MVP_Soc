import Foundation

struct OpenAIHelper {
    static let apiKey = "YOUR_OPENAI_API_KEY" // TODO: Secure this key, do not commit to repo
    static let endpoint = "https://api.openai.com/v1/chat/completions"
    
    static func getBundleSuggestions(itemPrices: [ItemPrice], groupSize: Int, budget: Double) async throws -> String {
        // Build prompt
        let itemsList = itemPrices.map { "\($0.itemName) - $\(String(format: "%.2f", $0.price)) (\($0.vendor))" }.joined(separator: "\n")
        let prompt = """
        You are a party planner. Here are available items and prices:
        \(itemsList)
        The group size is \(groupSize) and the total budget is $\(String(format: "%.2f", budget)).
        Suggest 2-3 drink+snack bundles (with itemized cost) that fit the budget. Each bundle should be a list of items, total cost, and a fun name. Format as:
        Bundle Name: ...\nItems: ...\nTotal: ...\n---
        """
        
        // Prepare request
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
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API error"])
        }
        // Parse response
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw NSError(domain: "OpenAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response from OpenAI"])
        }
        return content
    }
}

// MARK: - OpenAI Response Models
struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
} 