//
//  CameraScreen.swift
//  ObjectDetection
//
//  Created by Maham Imran on 30/03/2025.
//

import SwiftUI

struct CameraScreen: View {
    @Binding var isPresented: Bool
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: {
                    isPresented = false
                    
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Constants.Colors.textColor)
                        .padding(.leading)
                }
                
                Spacer()
                Text("ASL Detector")
                    .font(.custom(Constants.Fonts.lexendBold, size: 30))
                    .foregroundColor(Constants.Colors.primary)
                Spacer()
            }
            .frame(height: 60)
            .background(Constants.Colors.systemBackground)
            .shadow(radius: 4)
            
            // Camera preview below
            CameraView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        }
    }
}

#Preview {
    CameraScreen(isPresented: .constant(true))
}
