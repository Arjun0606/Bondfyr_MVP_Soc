import SwiftUI

struct SavedEventsView: View {
    @StateObject private var savedEventsManager = SavedEventsManager.shared
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedEvent: Event?
    @State private var showEventDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if savedEventsManager.savedEvents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Saved Events")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Events you save will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(savedEventsManager.savedEvents) { event in
                            EventRow(event: event)
                                .onTapGesture {
                                    selectedEvent = event
                                    showEventDetail = true
                                }
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await loadSavedEvents()
                    }
                }
            }
            .navigationTitle("Saved Events")
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showEventDetail, content: {
                if let event = selectedEvent {
                    NavigationView {
                        EventDetailView(event: event)
                    }
                }
            })
            .onAppear {
                Task {
                    await loadSavedEvents()
                }
            }
        }
    }
    
    private func loadSavedEvents() async {
        isLoading = true
        savedEventsManager.fetchSavedEvents { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    // Events are automatically updated in the @Published savedEvents property
                    break
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct EventRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 16) {
            // Event Image
            if let url = URL(string: event.venueLogoImage), !event.venueLogoImage.isEmpty, event.venueLogoImage.hasPrefix("http") {
                AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Placeholder or local asset fallback
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headline)
                Text(event.date)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(event.venue)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SavedEventsView()
} 