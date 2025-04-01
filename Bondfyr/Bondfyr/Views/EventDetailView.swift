//
//  EventDetailView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation
import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore
import Combine

struct EventDetailView: View {
    let event: Event

    @State private var selectedTier = ""
    @State private var ticketCount = 1
    @State private var prCode = ""
    @State private var instagramUsername = ""
    @State private var genders: [String] = [""]
    @State private var showPopup = false
    @State private var showConfirmationPopup = false
    @State private var navigateToTickets = false
    @State private var zoomedImage: String? = nil
    @State private var zoomScale: CGFloat = 1.0

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var tabSelection: TabSelection

    let tiers = ["Early Bird", "Standard", "VIP"]
    let genderOptions = ["Male", "Female", "Non-Binary"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image(event.eventPosterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(10)
                        .onTapGesture {
                            zoomedImage = event.eventPosterImage
                            zoomScale = 1.0
                        }

                    if let gallery = event.galleryImages, !gallery.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(gallery, id: \.self) { imageName in
                                    Image(imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipped()
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            zoomedImage = imageName
                                            zoomScale = 1.0
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

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

                        Text("About this Event")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(event.description)
                            .foregroundColor(.gray)

                        Divider().background(Color.white.opacity(0.2))

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

                        Stepper("Tickets: \(ticketCount)", value: $ticketCount, in: 1...6, onEditingChanged: { _ in
                            adjustGenderArray()
                        })
                        .foregroundColor(.white)

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

                        TextField("Instagram handle (optional)", text: $instagramUsername)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)

                        TextField("PR Code (optional)", text: $prCode)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)

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

                        Text("🎟️ All sales are final. No refunds or cancellations. Entry is at the club's discretion.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            }

            // 🔍 Zoomed Image Popup
            if let image = zoomedImage {
                Color.black.opacity(0.9).ignoresSafeArea()
                VStack {
                    Spacer()
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .gesture(MagnificationGesture().onChanged { value in
                            zoomScale = value
                        })
                        .padding()
                    Spacer()
                    Button("Close") {
                        zoomedImage = nil
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.pink)
                    .cornerRadius(8)
                }
                .transition(.scale)
            }
        }
        .onAppear {
            resetForm()
        }
        .alert("⚠️ Gender Ratio Notice", isPresented: $showPopup, actions: {
            Button("I Agree") {
                generateTicket()
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Entry may be denied at the venue if gender ratio is not met. This is at the discretion of the club. No refunds will be provided.")
        })
        .alert("✅ Ticket Confirmed", isPresented: $showConfirmationPopup, actions: {
            Button("Go to Tickets") {
                tabSelection.selectedTab = .tickets
                presentationMode.wrappedValue.dismiss()
            }
        }, message: {
            Text("Your ticket has been successfully purchased.")
        })
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
            ticketId: UUID().uuidString,
            phoneNumber: ""
        )
        TicketStorage.save(ticket)
        NotificationManager.shared.schedulePhotoNotification(forEvent: event.name)
        showConfirmationPopup = true
    }

    func resetForm() {
        selectedTier = ""
        ticketCount = 1
        prCode = ""
        instagramUsername = ""
        genders = [""]
    }
}
