//
//  QRGenerator.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import UIKit
import CoreImage.CIFilterBuiltins

struct QRGenerator {
    static func generate(from ticket: TicketModel) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        // Encode TicketModel as JSON
        guard let jsonData = try? JSONEncoder().encode(ticket),
              let qrString = String(data: jsonData, encoding: .utf8),
              let data = qrString.data(using: .utf8) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
