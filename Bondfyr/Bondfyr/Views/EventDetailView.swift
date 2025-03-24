//
//  EventDetailView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct EventDetailView: View {
    let event: Event

    @State private var selectedTier = ""
    @State private var ticketCount = 1
    @State private var prCode = ""
    @State private var genders: [String] = [""]
    @State private var showWarning = false
    @State private var showPopup = false
    @State private var agreedToWarning = false

    let tiers = ["Early Bird", "Standard", "VIP"]
    let genderOptions = ["Male", "Female", "Trans", "Non-Binary"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(event.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 16) {
                    Text(event.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("\(event.location) • \(event.date)")
                        .foregroundColor(.gray)

                    Divider().background(Color.white.opacity(0.2))

                    // TIER SELECTION
                    Text("Select Ticket Tier")
                        .font(.headline)
                        .foregroundColor(.white)

                    Picker("Tier", selection: $selectedTier) {
                        Text("Select a Tier").tag("")
                        ForEach(tiers, id: \.self) { tier in
                            Text(tier).tag(tier)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)

                    // TICKET COUNT
                    Stepper("Tickets: \(ticketCount)", value: $ticketCount, in: 1...6, onEditingChanged: { _ in
                        adjustGenderArray()
                    })
                    .foregroundColor(.white)

                    // GENDER PICKERS
                    ForEach(0..<ticketCount, id: \.self) { index in
                        Menu {
                            ForEach(genderOptions, id: \.self) { gender in
                                Button(action: {
                                    genders[index] = gender
                                }) {
                                    Text(gender)
                                }
                            }
                        } label: {
                            Text(genders[index].isEmpty ? "Gender" : genders[index])
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(genders[index].isEmpty ? .gray : .white)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }

                    // PR CODE
                    TextField("PR Code (optional)", text: $prCode)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)

                    // PROCEED BUTTON
                    Button(action: {
                        if shouldShowWarning() {
                            showPopup = true
                        } else {
                            agreedToWarning = true
                        }
                    }) {
                        Text("Proceed to Pay")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid() ? Color.pink : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid())
                }
                .padding()

                if agreedToWarning {
                    TicketConfirmationView(event: event, tier: selectedTier, genders: genders, prCode: prCode, count: ticketCount)
                        .padding(.top)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .alert(isPresented: $showPopup) {
            Alert(
                title: Text("⚠️ Gender Ratio Notice"),
                message: Text("Entry may be denied at the venue if gender ratio is not met. This is at the discretion of the club. No refunds will be provided."),
                primaryButton: .default(Text("I Agree")) {
                    agreedToWarning = true
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            adjustGenderArray()
        }
    }

    func adjustGenderArray() {
        if genders.count < ticketCount {
            genders += Array(repeating: "", count: ticketCount - genders.count)
        } else if genders.count > ticketCount {
            genders = Array(genders.prefix(ticketCount))
        }
    }

    func shouldShowWarning() -> Bool {
        let maleCount = genders.filter { $0 == "Male" }.count
        let femaleCount = genders.filter { $0 == "Female" }.count
        return maleCount > femaleCount
    }

    func isFormValid() -> Bool {
        return !selectedTier.isEmpty && !genders.contains("")
    }
}

// QR confirmation view
struct TicketConfirmationView: View {
    let event: Event
    let tier: String
    let genders: [String]
    let prCode: String
    let count: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("✅ Ticket Confirmed")
                .foregroundColor(.green)
                .font(.headline)

            let qrString = "\(event.name)-\(tier)-\(count) tickets-\(genders.joined(separator: ","))-\(prCode)"
            Image(uiImage: QRGenerator.generate(from: qrString))
                .interpolation(.none)
                .resizable()
                .frame(width: 200, height: 200)
                .background(Color.white)
                .cornerRadius(10)
        }
    }
}
