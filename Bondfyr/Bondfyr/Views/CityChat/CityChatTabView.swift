import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CityChatMessage: Identifiable {
    let id: String
    let userId: String
    let text: String
    let timestamp: Date
}

class CityChatManager: ObservableObject {
    @Published var messages: [CityChatMessage] = []
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    func startListening(city: String) {
        stopListening()
        let chatId = CityChatManager.chatDocId(for: city)
        listener = db.collection("cityChats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.messages = docs.compactMap { doc in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          let text = data["text"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else { return nil }
                    return CityChatMessage(id: doc.documentID, userId: userId, text: text, timestamp: timestamp)
                }
            }
    }
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    func sendMessage(city: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "CityChat", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])) )
            return
        }
        let chatId = CityChatManager.chatDocId(for: city)
        let data: [String: Any] = [
            "userId": userId,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]
        db.collection("cityChats").document(chatId).collection("messages").addDocument(data: data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    static func chatDocId(for city: String) -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: date)
        return "\(city)_\(dateStr)"
    }
}

struct CityChatTabView: View {
    @ObservedObject var cityManager = CityManager.shared
    @State private var inputText: String = ""
    @ObservedObject var chatManager = CityChatManager()
    @State private var isSending = false
    @State private var sendError: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if cityManager.isLoading {
                    ProgressView().padding()
                } else {
                    Picker("City", selection: $cityManager.selectedCity) {
                        ForEach(cityManager.cities, id: \ .self) { city in
                            Text(city).tag(Optional(city))
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                }
                // Chat messages
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(chatManager.messages) { msg in
                            HStack(alignment: .top) {
                                Text(msg.userId.prefix(8))
                                    .font(.caption2)
                                    .foregroundColor(.pink)
                                Text(msg.text)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color(.systemGray6).opacity(0.15))
                                    .cornerRadius(8)
                                Spacer()
                                Text(msg.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                // Input bar
                HStack {
                    TextField("Type a message...", text: $inputText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(.systemGray6).opacity(0.15))
                        .cornerRadius(8)
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .pink)
                    }
                    .disabled(inputText.isEmpty || isSending)
                }
                .padding()
                if let sendError = sendError {
                    Text(sendError)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .background(BackgroundGradientView())
            .navigationTitle("City Chat")
            .onAppear {
                if cityManager.selectedCity == nil, let first = cityManager.cities.first {
                    cityManager.selectedCity = first
                }
                if let city = cityManager.selectedCity {
                    chatManager.startListening(city: city)
                }
            }
            .onDisappear { chatManager.stopListening() }
            .onChange(of: cityManager.selectedCity) { city in
                if let city = city {
                    chatManager.startListening(city: city)
                }
            }
        }
    }
    func sendMessage() {
        guard let city = cityManager.selectedCity else { return }
        isSending = true
        sendError = nil
        chatManager.sendMessage(city: city, text: inputText) { result in
            isSending = false
            switch result {
            case .success:
                inputText = ""
            case .failure(let error):
                sendError = error.localizedDescription
            }
        }
    }
} 