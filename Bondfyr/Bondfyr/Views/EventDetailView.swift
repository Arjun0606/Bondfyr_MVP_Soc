//
//  EventDetailView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct EventDetailView: View {
    let event: Event

    @State private var selectedTier = "Standard"
    @State private var ticketCount = 1
    @State private var prCode = ""
    @State private var genders: [String] = ["Male"]
    @State private var showWarning = false
    @State private var showConfirmation = false

    let tiers = ["Early Bird", "Standard", "VIP"]
    let genderOptions = ["Male", "Female", "Trans", "Non-Binary"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(event.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)

                Text(event.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(event.location)
                    .foregroundColor(.gray)

                Text("Date: \(event.date)")
                    .foregroundColor(.gray)

                Divider().background(Color.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Ticket Tier")
                        .foregroundColor(.white)

                    Picker("Tier", selection: $selectedTier) {
                        ForEach(tiers, id: \.self) { tier in
                            Text(tier)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Stepper("Number of Tickets: \(ticketCount)", value: $ticketCount, in: 1...6, onEditingChanged: { _ in
                        adjustGenderArray()
                    })
                    .foregroundColor(.white)

                    ForEach(0..<ticketCount, id: \.self) { index in
                        Picker("Person \(index + 1) Gender", selection: $genders[index]) {
                            ForEach(genderOptions, id: \.self) { gender in
                                Text(gender)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }

                    TextField("PR Code (optional)", text: $prCode)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    if showWarning {
                        Text("⚠️ Entry may be denied at the venue if gender ratio is not met. No refunds will be provided.")
                            .font(.footnote)
                            .foregroundColor(.yellow)
                            .padding(.top, 6)
                    }

                    Button(action: {
                        checkGenderRatio()
                        showConfirmation = true
                    }) {
                        Text("Proceed to Pay")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.pink)
                            .cornerRadius(12)
                    }
                    .padding(.top)
                }

                if showConfirmation {
                    VStack(spacing: 12) {
                        Text("✅ Tickets Confirmed")
                            .foregroundColor(.green)
                            .font(.headline)

                        let qrData = "\(event.name)-\(selectedTier)-\(ticketCount) tickets-\(genders.joined(separator: ","))-\(prCode)"
                        Image(uiImage: QRGenerator.generate(from: qrData))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 200, height: 200)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            adjustGenderArray()
        }
    }

    private func adjustGenderArray() {
        if genders.count < ticketCount {
            genders += Array(repeating: "Male", count: ticketCount - genders.count)
        } else if genders.count > ticketCount {
            genders = Array(genders.prefix(ticketCount))
        }
    }

    private func checkGenderRatio() {
        let maleCount = genders.filter { $0 == "Male" }.count
        let femaleCount = genders.filter { $0 == "Female" }.count

        showWarning = maleCount > femaleCount
    }
}
