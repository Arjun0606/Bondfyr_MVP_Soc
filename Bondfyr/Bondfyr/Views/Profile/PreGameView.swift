import SwiftUI
import CoreLocation

struct AlcoholShop: Identifiable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
}

let mockShops: [AlcoholShop] = [
    AlcoholShop(name: "Cheers Liquor Store", latitude: 12.9716, longitude: 77.5946, address: "MG Road, Bangalore"),
    AlcoholShop(name: "The Bottle Shop", latitude: 12.965, longitude: 77.610, address: "Indiranagar, Bangalore"),
    AlcoholShop(name: "Spiritz Wine Shop", latitude: 12.935, longitude: 77.614, address: "Koramangala, Bangalore"),
    AlcoholShop(name: "City Barrels", latitude: 12.980, longitude: 77.640, address: "Whitefield, Bangalore"),
    AlcoholShop(name: "Quick Liquor", latitude: 12.950, longitude: 77.580, address: "Jayanagar, Bangalore"),
]

struct PreGameView: View {
    @State private var groupSize: Int = 2
    @State private var budget: Double = 1000
    @State private var suggestion: String? = nil
    @State private var isLoading = false
    @State private var error: String? = nil
    @StateObject private var locationManager = LocationManager()

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
                Text("Let's Pre-Game!")
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
            if let userLoc = locationManager.userLocation {
                let shops = shopsNearUser(userLoc: userLoc)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alcohol Shops Near You")
                        .font(.headline)
                        .foregroundColor(.white)
                    if shops.isEmpty {
                        Text("No shops found within 7 km.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(shops) { shop in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(shop.name)
                                        .foregroundColor(.white)
                                    Text(shop.address)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(String(format: "%.1f km", shop.distance/1000))
                                    .foregroundColor(.pink)
                                Button(action: {
                                    openInGoogleMaps(lat: shop.latitude, lon: shop.longitude)
                                }) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.pink)
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 8)
            } else {
                Text("Locating you...")
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(Color.black)
        .navigationTitle("Pre-Game")
    }

    struct PreGameItem {
        let name: String
        let price: Double
        let vendor: String
        let abv: Double // percent
        let volume: Double // ml
        let type: String // "beer", "spirit", "mixer"
        let brand: String
    }

    // Sample item list
    let sampleItems: [PreGameItem] = [
        PreGameItem(name: "Kingfisher Beer (650ml)", price: 120, vendor: "Local Shop", abv: 4.8, volume: 650, type: "beer", brand: "Kingfisher"),
        PreGameItem(name: "Budweiser Beer (500ml)", price: 150, vendor: "Local Shop", abv: 5.0, volume: 500, type: "beer", brand: "Budweiser"),
        PreGameItem(name: "Smirnoff Vodka (750ml)", price: 1100, vendor: "Liquor Store", abv: 37.5, volume: 750, type: "spirit", brand: "Smirnoff"),
        PreGameItem(name: "Old Monk Rum (750ml)", price: 900, vendor: "Liquor Store", abv: 42.8, volume: 750, type: "spirit", brand: "Old Monk"),
        PreGameItem(name: "Bacardi White Rum (750ml)", price: 1200, vendor: "Liquor Store", abv: 42.8, volume: 750, type: "spirit", brand: "Bacardi"),
        PreGameItem(name: "Tonic Water (1L)", price: 80, vendor: "Supermarket", abv: 0.0, volume: 1000, type: "mixer", brand: "Generic"),
        PreGameItem(name: "Cola (1.25L)", price: 60, vendor: "Supermarket", abv: 0.0, volume: 1250, type: "mixer", brand: "Generic"),
        PreGameItem(name: "Orange Juice (1L)", price: 90, vendor: "Supermarket", abv: 0.0, volume: 1000, type: "mixer", brand: "Generic"),
    ]

    func drinksPerPerson(for vibe: String) -> Double {
        switch vibe.lowercased() {
        case "light buzz": return 1
        case "moderate buzz": return 2.5
        case "party mode": return 4
        case "party monster": return 6
        default: return 2.5
        }
    }

    func vibeDrinkTypes(for vibe: String) -> [String] {
        switch vibe.lowercased() {
        case "light buzz": return ["beer"]
        case "moderate buzz": return ["beer"]
        case "party mode": return ["spirit"]
        case "party monster": return ["spirit"]
        default: return ["beer", "spirit"]
        }
    }

    func suggestBundles(groupSize: Int, budget: Double, vibe: String, brandPreference: String? = nil) -> [String] {
        let E_req = Double(groupSize) * drinksPerPerson(for: vibe) * 17.7
        let drinkTypes = vibeDrinkTypes(for: vibe)
        let items = sampleItems.filter { drinkTypes.contains($0.type) || $0.type == "mixer" }
        let mixers = ["Tonic Water", "Cola", "Soda Water", "Ginger Ale", "Lemon-Lime Soda", "Orange Juice", "Cranberry Juice"]
        var bundles: [[(item: PreGameItem, qty: Int)]] = []
        let combos = (items.combinations(ofCount: 2) + items.combinations(ofCount: 3)).prefix(10) // Limit for performance

        func bundleStats(_ bundle: [(item: PreGameItem, qty: Int)]) -> (ethanol: Double, cost: Double) {
            let ethanol = bundle.reduce(0.0) { $0 + Double($1.qty) * $1.item.volume * ($1.item.abv / 100.0) }
            let cost = bundle.reduce(0.0) { $0 + Double($1.qty) * $1.item.price }
            return (ethanol, cost)
        }

        for combo in combos {
            for q1 in 1...2 {
                for q2 in 1...2 {
                    for q3 in 1...(combo.count == 3 ? 2 : 1) {
                        let qtys = combo.count == 2 ? [q1, q2] : [q1, q2, q3]
                        let bundle = zip(combo, qtys).map { ($0, $1) }
                        let (E_supplied, cost) = bundleStats(bundle)
                        if E_supplied >= E_req && cost <= budget {
                            bundles.append(bundle)
                        }
                    }
                }
            }
        }
        let sortedBundles = bundles.sorted { b1, b2 in
            let c1 = b1.reduce(0.0) { $0 + Double($1.qty) * $1.item.price }
            let c2 = b2.reduce(0.0) { $0 + Double($1.qty) * $1.item.price }
            return c1 < c2
        }
        var results: [String] = []
        for (i, bundle) in sortedBundles.prefix(3).enumerated() {
            var s = "\(i+1). Bundle:\n"
            for (item, qty) in bundle {
                s += "- \(item.name) × \(qty) (ABV: \(item.abv)%, \(Int(item.volume))ml) — ₹\(Int(item.price)) each\n"
            }
            s += "  + Mixers: \(mixers.shuffled().prefix(2).joined(separator: ", "))\n"
            let total = bundle.reduce(0.0) { $0 + Double($1.qty) * $1.item.price }
            s += "  Total Cost: ₹\(Int(total))\n"
            results.append(s)
        }
        // Brand preference bundle
        if let brand = brandPreference {
            let brandItems = items.filter { $0.brand.lowercased().contains(brand.lowercased()) }
            if !brandItems.isEmpty {
                for q in 1...2 {
                    let E_supplied = Double(q) * brandItems[0].volume * (brandItems[0].abv / 100.0)
                    let cost = Double(q) * brandItems[0].price
                    if E_supplied >= E_req && cost <= budget {
                        var s = "Brand Bundle (\(brandItems[0].brand)):\n"
                        s += "- \(brandItems[0].name) × \(q) (ABV: \(brandItems[0].abv)%, \(Int(brandItems[0].volume))ml) — ₹\(Int(brandItems[0].price)) each\n"
                        s += "  + Mixers: \(mixers.shuffled().prefix(2).joined(separator: ", "))\n"
                        s += "  Total Cost: ₹\(Int(cost))\n"
                        results.append(s)
                        break
                    }
                }
            }
        }
        if results.isEmpty {
            results.append("No bundles found for your budget and vibe. Try increasing your budget or lowering the buzz level.")
        }
        return results
    }

    func getSuggestion() {
        isLoading = true
        error = nil
        // For MVP, use the new bundle logic
        let vibe = "Party Mode" // TODO: let user pick
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let bundles = suggestBundles(groupSize: groupSize, budget: budget, vibe: vibe)
            suggestion = bundles.joined(separator: "\n\n")
            isLoading = false
        }
    }

    func shopsNearUser(userLoc: CLLocation) -> [ShopWithDistance] {
        let shopsWithDist = mockShops.map { shop in
            let shopLoc = CLLocation(latitude: shop.latitude, longitude: shop.longitude)
            let dist = userLoc.distance(from: shopLoc)
            return ShopWithDistance(shop: shop, distance: dist)
        }
        let closeShops = shopsWithDist.filter { $0.distance <= 5000 }
        if !closeShops.isEmpty {
            return closeShops.sorted { $0.distance < $1.distance }
        } else {
            let fallback = shopsWithDist.filter { $0.distance <= 7000 }
            return fallback.sorted { $0.distance < $1.distance }
        }
    }

    struct ShopWithDistance: Identifiable {
        let shop: AlcoholShop
        let distance: Double
        var id: UUID { shop.id }
        var name: String { shop.name }
        var latitude: Double { shop.latitude }
        var longitude: Double { shop.longitude }
        var address: String { shop.address }
    }

    func openInGoogleMaps(lat: Double, lon: Double) {
        let url = URL(string: "comgooglemaps://?q=Alcohol+Shop&center=\(lat),\(lon)&zoom=16") ??
                  URL(string: "https://maps.google.com/?q=\(lat),\(lon)")!
        UIApplication.shared.open(url)
    }
}

// Helper: combinations
extension Array {
    func combinations(ofCount n: Int) -> [[Element]] {
        guard n > 0 else { return [[]] }
        guard let first = self.first else { return [] }
        let subcombos = Array(self.dropFirst()).combinations(ofCount: n - 1)
        var result = subcombos.map { [first] + $0 }
        result += Array(self.dropFirst()).combinations(ofCount: n)
        return result
    }
} 