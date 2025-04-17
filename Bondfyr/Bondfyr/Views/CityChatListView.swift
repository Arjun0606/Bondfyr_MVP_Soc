import SwiftUI

struct CityChatListView: View {
    @ObservedObject private var chatManager = ChatManager.shared
    @State private var showInfoSheet = false
    @State private var navigateToCityChat = false
    @State private var selectedCity: ChatCity?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Replace plain black with gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("City Chats")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            showInfoSheet = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.pink)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, -50)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search cities", text: $searchText)
                            .foregroundColor(.white)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Section title
                    Text("Available Cities")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    // Direct hardcoded list of cities
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Manually create each city row to ensure they appear
                            CityRow(city: ChatCity(id: "mumbai", name: "mumbai", displayName: "Mumbai", memberCount: 329))
                            CityRow(city: ChatCity(id: "delhi", name: "delhi", displayName: "Delhi", memberCount: 204))
                            CityRow(city: ChatCity(id: "bangalore", name: "bangalore", displayName: "Bangalore", memberCount: 451))
                            CityRow(city: ChatCity(id: "pune", name: "pune", displayName: "Pune", memberCount: 176))
                            CityRow(city: ChatCity(id: "hyderabad", name: "hyderabad", displayName: "Hyderabad", memberCount: 183))
                            CityRow(city: ChatCity(id: "chennai", name: "chennai", displayName: "Chennai", memberCount: 147))
                            CityRow(city: ChatCity(id: "kolkata", name: "kolkata", displayName: "Kolkata", memberCount: 135))
                            CityRow(city: ChatCity(id: "ahmedabad", name: "ahmedabad", displayName: "Ahmedabad", memberCount: 112))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                
                NavigationLink(
                    destination: Group {
                        if let city = selectedCity {
                            CityChatView(city: city)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $navigateToCityChat,
                    label: { EmptyView() }
                )
                .hidden()
            }
            .navigationBarHidden(true)
            .onAppear {
                chatManager.loadCities()
                
                // Setup notification observer for city selection
                NotificationCenter.default.addObserver(forName: Notification.Name("OpenCityChat"), object: nil, queue: .main) { notification in
                    if let city = notification.object as? ChatCity {
                        selectedCity = city
                        navigateToCityChat = true
                    }
                }
            }
            .onDisappear {
                // Remove observer when view disappears
                NotificationCenter.default.removeObserver(self)
            }
            .sheet(isPresented: $showInfoSheet) {
                ChatInfoSheet()
            }
        }
    }
}

struct CityRow: View {
    let city: ChatCity
    
    var body: some View {
        HStack(spacing: 16) {
            // City icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.pink, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                
                Text(String(city.displayName.prefix(1)))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(city.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(city.memberCount) people chatting")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onTapGesture {
            // Handle tap directly in the row
            let nc = NotificationCenter.default
            nc.post(name: Notification.Name("OpenCityChat"), object: city)
        }
    }
}

struct ChatInfoSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    // About City Chats
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About City Chats", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                        
                        Text("City Chats let you connect with other Bondfyr users in your city to discuss upcoming events and parties.")
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Anonymity feature
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Anonymous Identity", systemImage: "person.fill.questionmark")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                        
                        Text("For your privacy, you'll be given a unique anonymous username that others will see in the chat. You can regenerate your username anytime.")
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Chat guidelines
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Community Guidelines", systemImage: "hand.raised.fill")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "Be respectful to other users")
                            BulletPoint(text: "Don't share personal contact information")
                            BulletPoint(text: "Discuss events and venues, not individuals")
                            BulletPoint(text: "Report inappropriate behavior")
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("City Chats Info", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("•")
                .foregroundColor(.pink)
            
            Text(text)
                .foregroundColor(.white)
        }
    }
} 