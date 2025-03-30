//
//  CameraViewController.swift
//  ObjectDetection
//
//  Created by Maham Imran on 28/03/2025.
//

import UIKit
import AVFoundation
import Vision
import CoreML

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var predictionLabel: UILabel!
    var frameCount = 0

    // Load ML model once
    let coreMLModel: asl = {
        do {
            let config = MLModelConfiguration()
            return try asl(configuration: config)
        } catch {
            fatalError("Failed to load model: \(error)")
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupLabel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        predictionLabel.text = "Waiting for prediction..."
    }

    func setupLabel() {
        predictionLabel = UILabel(frame: CGRect(x: 10, y: 80, width: view.frame.width - 20, height: 70))
        predictionLabel.textColor = .white
        predictionLabel.font = UIFont.boldSystemFont(ofSize: 20)
        predictionLabel.numberOfLines = 0
        predictionLabel.textAlignment = .center
        predictionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        predictionLabel.layer.cornerRadius = 10
        predictionLabel.clipsToBounds = true
        view.addSubview(predictionLabel)
        view.bringSubviewToFront(predictionLabel)
    }

    func setupCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.captureSession = AVCaptureSession()
            guard let captureSession = self.captureSession else { return }
            captureSession.sessionPreset = .photo

            guard let backCamera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: backCamera),
                  captureSession.canAddInput(input) else {
                print("Failed to get camera input")
                return
            }

            captureSession.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            } else {
                print("Failed to add video output")
            }

            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                self.previewLayer?.videoGravity = .resizeAspectFill
                self.previewLayer?.frame = self.view.bounds
                if let previewLayer = self.previewLayer {
                    self.view.layer.insertSublayer(previewLayer, at: 0)
                }
                self.view.bringSubviewToFront(self.predictionLabel)
            }

            print("🎥 Starting camera session...")
            captureSession.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        print("📸 Frame received: \(frameCount)")

        // Run prediction every 5th frame
        if frameCount % 5 != 0 { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("⚠️ Couldn't get pixel buffer")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            print("🧠 Running prediction on frame \(self.frameCount)")

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                print("❌ Failed to get CGImage")
                return
            }

            let uiImage = UIImage(cgImage: cgImage)
            guard let resizedImage = uiImage.resize(to: CGSize(width: 608, height: 608)),
                  let modelBuffer = resizedImage.toCVPixelBuffer() else {
                print("⚠️ Failed to resize or convert image")
                return
            }

            do {
                let output = try self.coreMLModel.prediction(imagePath: modelBuffer,
                                                             iouThreshold: 0.3,
                                                             confidenceThreshold: 0.1)

                let confidenceArray = output.confidence
                var bestLabel = "No object"
                var bestConfidence: Double = 0.0
                var bestIndex = -1

                for i in 0..<confidenceArray.shape[0].intValue {
                    for j in 0..<confidenceArray.shape[1].intValue {
                        let conf = confidenceArray[[NSNumber(value: i), NSNumber(value: j)]].doubleValue
                        if conf > bestConfidence {
                            bestConfidence = conf
                            bestIndex = j
                        }
                    }
                }

                DispatchQueue.main.async {
                    if bestConfidence > 0.6 {
                        bestLabel = String(UnicodeScalar(65 + bestIndex) ?? "?")
                        self.predictionLabel.text = "🔤 Detected: \(bestLabel) (\(String(format: "%.1f", bestConfidence * 100))%)"
                        print("🎯 Detected: \(bestLabel), Confidence: \(bestConfidence)")
                    } else {
                        self.predictionLabel.text = "⏳ Detecting..."
                        print("🤔 Low confidence")
                    }
                }

            } catch {
                print("❌ Prediction error: \(error)")
                DispatchQueue.main.async {
                    self.predictionLabel.text = "⚠️ Prediction failed"
                }
            }
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }

    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let width = Int(size.width)
        let height = Int(size.height)

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)

        guard let buffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
}
