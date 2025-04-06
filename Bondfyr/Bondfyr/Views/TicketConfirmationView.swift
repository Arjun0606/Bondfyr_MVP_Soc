//
//  TicketConfirmationView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct TicketConfirmationView: View {
    let ticket: TicketModel
    @State private var showQR = false
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Event name and type
            HStack {
                Text(ticket.event)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(ticket.tier)
                    .font(.subheadline)
                    .padding(5)
                    .background(Color.pink.opacity(0.2))
                    .cornerRadius(5)
                    .foregroundColor(.pink)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Ticket details
            VStack(alignment: .leading, spacing: 10) {
                DetailRow(title: "Ticket ID", value: String(ticket.ticketId.prefix(8)))
                DetailRow(title: "Date", value: formatDate(ticket.timestamp))
                DetailRow(title: "Tickets", value: "\(ticket.count) (\(formatGenders(ticket.genders)))")
                if !ticket.prCode.isEmpty {
                    DetailRow(title: "PR Code", value: ticket.prCode)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // QR Code
            Button(action: {
                showQR.toggle()
            }) {
                HStack {
                    Image(systemName: "qrcode")
                    Text(showQR ? "Hide QR Code" : "Show QR Code")
                    Spacer()
                    Image(systemName: showQR ? "chevron.up" : "chevron.down")
                }
                .foregroundColor(.white)
            }
            
            if showQR {
                HStack {
                    Spacer()
                    
                    Image(uiImage: generateQRCode(from: ticket.ticketId))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    
                    Spacer()
                }
                .padding(.top, 10)
                
                Text("Present this QR code at the venue entrance")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return dateString
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatGenders(_ genders: [String]) -> String {
        let counts = Dictionary(grouping: genders, by: { $0 }).mapValues { $0.count }
        
        var result = ""
        if let maleCount = counts["Male"], maleCount > 0 {
            result += "\(maleCount)M"
        }
        
        if let femaleCount = counts["Female"], femaleCount > 0 {
            if !result.isEmpty {
                result += ", "
            }
            result += "\(femaleCount)F"
        }
        
        if let otherCount = counts["Non-Binary"], otherCount > 0 {
            if !result.isEmpty {
                result += ", "
            }
            result += "\(otherCount)NB"
        }
        
        return result
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.white)
        }
    }
}
