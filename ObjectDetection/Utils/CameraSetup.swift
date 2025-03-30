//
//  CameraSetup.swift
//  ObjectDetection
//
//  Created by Maham Imran on 30/03/2025.
//


import AVFoundation
import UIKit

struct CameraSetup {
    static func configureCamera(for controller: CameraViewController) {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        controller.captureSession = session

        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera),
              session.canAddInput(input) else {
            print("❌ Could not get camera input")
            return
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(controller, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        DispatchQueue.main.async {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = controller.view.bounds
            controller.previewLayer = layer
            controller.view.layer.insertSublayer(layer, at: 0)
        }

        // background thread to avoid UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            print("🎥 Camera session starting...")
            session.startRunning()
        }
    }

}
