//
//  QRGenerator.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import UIKit
import CoreImage.CIFilterBuiltins

struct QRGenerator {
    static func generate(from string: String) -> UIImage {
        let data = Data(string.utf8)
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage,
           let cgimg = context.createCGImage(outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
