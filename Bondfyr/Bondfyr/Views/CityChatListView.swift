import SwiftUI

struct CityChatListView: View {
    @ObservedObject private var chatManager = ChatManager.shared
    @State private var showInfoSheet = false
    @State private var navigateToCityChat = false
    @State private var selectedCity: ChatCity?
    @State private var searchText = ""
    @State private var showCityDropdown = false
    @State private var selectedFilter = "All Cities"
    
    // Major cities for dropdown
    let cityFilters = ["All Cities", "Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai", "Pune", "Kolkata", "Ahmedabad", "Jaipur", "Surat"]
    
    var filteredCities: [ChatCity] {
        var filtered = chatManager.cities
        
        // Apply city filter if not showing all
        if selectedFilter != "All Cities" {
            filtered = filtered.filter { city in
                city.displayName == selectedFilter
            }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            filtered = filtered.filter { city in
                city.displayName.lowercased().contains(searchText.lowercased())
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
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
                    .padding()
                    
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
                    
                    // City dropdown
                    VStack {
                        Button(action: {
                            withAnimation {
                                showCityDropdown.toggle()
                            }
                        }) {
                            HStack {
                                Text(selectedFilter)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: showCityDropdown ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.pink)
                                    .font(.system(size: 14))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        if showCityDropdown {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(cityFilters, id: \.self) { city in
                                        Button(action: {
                                            selectedFilter = city
                                            withAnimation {
                                                showCityDropdown = false
                                            }
                                        }) {
                                            HStack {
                                                Text(city)
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                if selectedFilter == city {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.pink)
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal)
                                            .background(
                                                selectedFilter == city ? 
                                                    Color.pink.opacity(0.2) : 
                                                    Color.clear
                                            )
                                        }
                                        
                                        if city != cityFilters.last {
                                            Divider()
                                                .background(Color.gray.opacity(0.3))
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                                .background(Color.black.opacity(0.9))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .frame(height: min(CGFloat(cityFilters.count) * 44, 300))
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .zIndex(1) // Make sure dropdown appears above the list
                    
                    // City list
                    if chatManager.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if filteredCities.isEmpty {
                        Spacer()
                        Text("No cities found")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredCities) { city in
                                    CityRow(city: city)
                                        .onTapGesture {
                                            selectedCity = city
                                            navigateToCityChat = true
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
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
            }
            .sheet(isPresented: $showInfoSheet) {
                ChatInfoSheet()
            }
            .onTapGesture {
                if showCityDropdown {
                    withAnimation {
                        showCityDropdown = false
                    }
                }
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