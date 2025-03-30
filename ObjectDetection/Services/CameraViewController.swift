//
//  CameraViewController.swift
//  ObjectDetection
//
//  Created by Maham Imran on 28/03/2025.
//
// Refactored CameraViewController.swift

import UIKit
import AVFoundation
import CoreML

class CameraViewController: UIViewController {
     var captureSession: AVCaptureSession?
     var previewLayer: AVCaptureVideoPreviewLayer?

    private var predictionLabel: UILabel!
    private var frameCount = 0
    private let model = try! asl(configuration: MLModelConfiguration())

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLabel()
        CameraSetup.configureCamera(for: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        predictionLabel.text = "Waiting for prediction..."
    }

    private func setupLabel() {
        predictionLabel = UILabel()
        predictionLabel.translatesAutoresizingMaskIntoConstraints = false
        predictionLabel.textColor = .white
        predictionLabel.font = UIFont.boldSystemFont(ofSize: 18)
        predictionLabel.numberOfLines = 0
        predictionLabel.textAlignment = .center
        predictionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        predictionLabel.layer.cornerRadius = 10
        predictionLabel.clipsToBounds = true

        view.addSubview(predictionLabel)

        NSLayoutConstraint.activate([
            predictionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            predictionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            predictionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            predictionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        if frameCount % 5 != 0 { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let uiImage = UIImage(cgImage: cgImage)
            guard let resized = uiImage.resize(to: CGSize(width: 608, height: 608)),
                  let buffer = resized.toCVPixelBuffer() else { return }
            
            do {
                let output = try self.model.prediction(imagePath: buffer, iouThreshold: 0.3, confidenceThreshold: 0.01)
                let confArray = output.confidence
                var resultString = ""

                for i in 0..<confArray.shape[0].intValue {
                    for j in 0..<confArray.shape[1].intValue {
                        let conf = confArray[[NSNumber(value: i), NSNumber(value: j)]].doubleValue
                        if conf > 0.01 {
                            let label = String(UnicodeScalar(65 + j) ?? "?")
                            resultString += "\n\(label): \(String(format: "%.2f", conf))"
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.predictionLabel.text = resultString.isEmpty ? "No detections" : resultString
                    print("\n--- Frame \(self.frameCount) Results ---\n\(resultString)")
                }
            } catch {
                print("❌ Error predicting: \(error)")
            }
        }
    }
}

extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }

    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let width = Int(self.size.width)
        let height = Int(self.size.height)

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32ARGB,
                                         attrs as CFDictionary,
                                         &pixelBuffer)

        guard let buffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue),
              let cgImage = self.cgImage else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        context.draw(cgImage, in: CGRect(origin: .zero, size: self.size))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
