//
//  CameraView.swift
//  ObjectDetection
//
//  Created by Maham Imran on 28/03/2025.
//


import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
