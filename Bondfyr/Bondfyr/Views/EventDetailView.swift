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
    @State private var instagramUsername = ""  // ✅ NEW
    @State private var genders: [String] = [""]
    @State private var showWarning = false
    @State private var showPopup = false
    @State private var agreedToWarning = false
    @State private var confirmedTicket: TicketModel? = nil
    
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
                    
                    Button(action: {
                            if let url = URL(string: event.mapsURL) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("Open in Google Maps", systemImage: "map")
                                .foregroundColor(.pink)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }

                    
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
                    
                    // INSTAGRAM USERNAME (OPTIONAL)
                    TextField("Instagram handle (optional)", text: $instagramUsername)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    
                    // PR CODE (OPTIONAL)
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
                            generateTicket()
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
                
                if let ticket = confirmedTicket {
                    TicketConfirmationView(ticket: ticket)
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
                    generateTicket()
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
    
    func generateTicket() {
        let ticket = TicketModel(
            event: event.name,
            tier: selectedTier,
            count: ticketCount,
            genders: genders,
            prCode: prCode,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            ticketId: UUID().uuidString
            // instagramUsername is optional
        )
        TicketStorage.save(ticket)
        confirmedTicket = ticket
    }
}
