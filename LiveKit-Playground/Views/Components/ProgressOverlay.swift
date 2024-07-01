//
//  ProgressOverlay.swift
//  LiveKit-Playground
//
//  Created by Bogdan Vatamanu on 27.06.2024.
//

import SwiftUI

fileprivate struct ProgressOverlayModifier: ViewModifier {
    @Binding var inProgress: Bool
    var onCancel: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!inProgress)
            
            if inProgress {
                Rectangle()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                VStack {
                    ProgressView()
                    
                    Button("Cancel") {
                        onCancel?()
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

extension View {
    func progressOverlay(_ inProgress: Binding<Bool>, onCancel: (() -> Void)? = nil) -> some View {
        modifier(ProgressOverlayModifier(inProgress: inProgress, onCancel: onCancel))
    }
}

#Preview {
    Text("Progress Preview")
        .progressOverlay(.constant(true))
}
