//
//  Untitled.swift
//  Bondfyr
//
//  Created by Arjun Varma on 26/03/25.
//

import SwiftUI

struct LoadingSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(Color.pink, lineWidth: 4)
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}
