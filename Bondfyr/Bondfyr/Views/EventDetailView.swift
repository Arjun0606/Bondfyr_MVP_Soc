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
    @State private var zoomedImage: String? = nil
    @State private var zoomScale: CGFloat = 1.0
    @State private var navigateToGallery = false
    @State private var navigateToCheckIn = false
    @State private var showAttendeesView = false

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

                        Button(action: {
                            navigateToGallery = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Event Photos")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: {
                            showAttendeesView = true
                        }) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                Text("Live Attendance")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // Instagram button
                        Button(action: {
                            openInstagram(for: event.name)
                        }) {
                            HStack {
                                Image(systemName: "camera.circle.fill")
                                Text("Follow on Instagram")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }

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
                                preparePayment()
                            }
                        }) {
                            Text("Get Tickets")
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
                presentationMode.wrappedValue.dismiss()
                tabSelection.selectedTab = .tickets
            }
        }, message: {
            Text("Your ticket has been successfully purchased.")
        })
        .sheet(isPresented: $navigateToGallery) {
            EventPhotoGalleryView(eventId: event.id.uuidString, eventName: event.name)
        }
        .sheet(isPresented: $showAttendeesView) {
            EventAttendeesView(event: event)
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
            ticketId: UUID().uuidString,
            phoneNumber: ""
        )
        
        // Save ticket directly without payment processing
        TicketStorage.save(ticket)
        showConfirmationPopup = true
    }
    
    func preparePayment() {
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
        
        // Save ticket directly without payment processing
        TicketStorage.save(ticket)
        showConfirmationPopup = true
    }

    func resetForm() {
        selectedTier = ""
        ticketCount = 1
        prCode = ""
        instagramUsername = ""
        genders = [""]
    }

    private func openInstagram(for clubName: String) {
        var instagramHandle = ""
        
        switch clubName {
        case "High Spirits":
            instagramHandle = "thehighspirits"
        case "Qora":
            instagramHandle = "qora_pune"
        case "Vault":
            instagramHandle = "vault.pune"
        default:
            return
        }
        
        let instagramURL = URL(string: "instagram://user?username=\(instagramHandle)")
        let instagramWebURL = URL(string: "https://www.instagram.com/\(instagramHandle)")
        
        if let instagramURL = instagramURL, UIApplication.shared.canOpenURL(instagramURL) {
            UIApplication.shared.open(instagramURL)
        } else if let instagramWebURL = instagramWebURL {
            UIApplication.shared.open(instagramWebURL)
        }
    }
}
