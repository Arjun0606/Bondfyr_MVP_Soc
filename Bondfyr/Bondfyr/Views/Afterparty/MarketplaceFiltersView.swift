import SwiftUI

// MARK: - Marketplace Filters View
struct MarketplaceFiltersView: View {
    @Binding var isPresented: Bool
    
    // Filter state
    @State private var selectedPriceRange: ClosedRange<Double> = 5...100
    @State private var selectedVibes: Set<String> = []
    @State private var selectedTimeFilter: AfterpartyManager.TimeFilter = .all
    @State private var showOnlyAvailable = true
    @State private var maxGuestCount: Int = 200
    
    let vibeOptions = Afterparty.vibeOptions
    
    // Callback for applying filters
    let onApplyFilters: (MarketplaceFilters) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Price Range
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price Range")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("$\(Int(selectedPriceRange.lowerBound))")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("$\(Int(selectedPriceRange.upperBound))\(selectedPriceRange.upperBound >= 200 && selectedPriceRange.lowerBound >= 200 ? "+" : "")")
                                    .foregroundColor(.white)
                            }
                            
                            RangeSlider(
                                range: $selectedPriceRange,
                                bounds: 5...200,
                                step: 5
                            )
                        }
                        
                        // Quick price buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([5...15, 15...30, 30...50, 50...75, 75...200], id: \.lowerBound) { range in
                                    Button("$\(Int(range.lowerBound))-\(Int(range.upperBound))") {
                                        selectedPriceRange = range
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedPriceRange == range ? Color.pink : Color(.systemGray6))
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                }
                                
                                // No upper limit button
                                Button("$200+") {
                                    selectedPriceRange = 200...200
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedPriceRange.lowerBound >= 200 ? Color.pink : Color(.systemGray6))
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                    
                    // MARK: - Time Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            ForEach([
                                (AfterpartyManager.TimeFilter.all, "All"),
                                (.tonight, "Tonight"),
                                (.upcoming, "Upcoming"),
                                (.ongoing, "Live Now")
                            ], id: \.0) { filter, title in
                                Button(title) {
                                    selectedTimeFilter = filter
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTimeFilter == filter ? Color.pink : Color(.systemGray6))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                            }
                        }
                    }
                    
                    // MARK: - Vibes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vibes")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(vibeOptions, id: \.self) { vibe in
                                Button(action: {
                                    if selectedVibes.contains(vibe) {
                                        selectedVibes.remove(vibe)
                                    } else {
                                        selectedVibes.insert(vibe)
                                    }
                                }) {
                                    Text(vibe)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(selectedVibes.contains(vibe) ? Color.purple : Color(.systemGray6))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Additional Filters
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional Filters")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Show only available parties
                        HStack {
                            Button(action: { showOnlyAvailable.toggle() }) {
                                Image(systemName: showOnlyAvailable ? "checkmark.square.fill" : "square")
                                    .foregroundColor(showOnlyAvailable ? .pink : .gray)
                            }
                            Text("Only show available parties")
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        // Max party size
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Max party size: \(maxGuestCount) people")
                                .foregroundColor(.white)
                            
                            Slider(value: Binding(
                                get: { Double(maxGuestCount) },
                                set: { maxGuestCount = Int($0) }
                            ), in: 5...200, step: 5)
                            .accentColor(.pink)
                        }
                    }
                    
                    // MARK: - Clear & Apply Buttons
                    VStack(spacing: 12) {
                        Button("Clear All Filters") {
                            selectedPriceRange = 5...100
                            selectedVibes.removeAll()
                            selectedTimeFilter = .all
                            showOnlyAvailable = true
                            maxGuestCount = 200
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        
                        Button("Apply Filters") {
                            let filters = MarketplaceFilters(
                                priceRange: selectedPriceRange,
                                vibes: Array(selectedVibes),
                                timeFilter: selectedTimeFilter,
                                showOnlyAvailable: showOnlyAvailable,
                                maxGuestCount: maxGuestCount
                            )
                            onApplyFilters(filters)
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 16)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Filter Parties")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.white)
            )
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Marketplace Filters Model
struct MarketplaceFilters {
    let priceRange: ClosedRange<Double>
    let vibes: [String]
    let timeFilter: AfterpartyManager.TimeFilter
    let showOnlyAvailable: Bool
    let maxGuestCount: Int
}

// MARK: - Custom Range Slider
struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double
    
    @State private var lowHandle: Double = 0
    @State private var highHandle: Double = 1
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let lowPosition = (lowHandle * width)
            let highPosition = (highHandle * width)
            
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Selected range
                Rectangle()
                    .fill(Color.pink)
                    .frame(width: highPosition - lowPosition, height: 4)
                    .offset(x: lowPosition)
                    .cornerRadius(2)
                
                // Low handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: lowPosition - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = max(0, min(width, value.location.x))
                                let newValue = bounds.lowerBound + (newPosition / width) * (bounds.upperBound - bounds.lowerBound)
                                let steppedValue = round(newValue / step) * step
                                lowHandle = min(highHandle - 0.01, (steppedValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
                                updateRange()
                            }
                    )
                
                // High handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: highPosition - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = max(0, min(width, value.location.x))
                                let newValue = bounds.lowerBound + (newPosition / width) * (bounds.upperBound - bounds.lowerBound)
                                let steppedValue = round(newValue / step) * step
                                highHandle = max(lowHandle + 0.01, (steppedValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound))
                                updateRange()
                            }
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            lowHandle = (range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
            highHandle = (range.upperBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        }
    }
    
    private func updateRange() {
        let low = bounds.lowerBound + lowHandle * (bounds.upperBound - bounds.lowerBound)
        let high = bounds.lowerBound + highHandle * (bounds.upperBound - bounds.lowerBound)
        range = low...high
    }
} 