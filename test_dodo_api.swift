import Foundation

// Test Dodo API directly
let apiKey = "WwodcwFpKfwwrjg5.Or4_3_Zl8Sv3APNRllVNh35fUlyzxZYBV1nrE7W3Xzmfmo"
let testProductId = "pdt_mPFnouRlaQerAPmYz1gY"

// Create payment request
let paymentData: [String: Any] = [
    "payment_link": true,
    "amount": 10.0,
    "currency": "USD",
    "billing": [
        "city": "San Francisco",
        "country": "US",
        "state": "CA",
        "street": "123 Main St",
        "zipcode": "94102"
    ],
    "customer": [
        "email": "testuser@bondfyr.com",
        "name": "Test User"
    ],
    "product_cart": [[
        "product_id": testProductId,
        "quantity": 1
    ]],
    "return_url": "bondfyr://payment-success",
    "metadata": [
        "test": "true"
    ]
]

// Convert to JSON
let jsonData = try! JSONSerialization.data(withJSONObject: paymentData, options: .prettyPrinted)
print("Request JSON:")
print(String(data: jsonData, encoding: .utf8)!)

// Create request - CORRECTED URL
var request = URLRequest(url: URL(string: "https://api.dodopayments.com/api/v1/payments")!)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = jsonData

print("\nSending request to: https://api.dodopayments.com/api/v1/payments")

// Make request
let semaphore = DispatchSemaphore(value: 0)
let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("\nError: \(error)")
    }
    
    if let httpResponse = response as? HTTPURLResponse {
        print("\nStatus Code: \(httpResponse.statusCode)")
    }
    
    if let data = data {
        print("\nResponse:")
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            print("\nParsed JSON:")
            print(json)
        }
    }
    
    semaphore.signal()
}

task.resume()
semaphore.wait()
