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
    
    // Load the ML Model
    let model: VNCoreMLModel = {
        do {
            let config = MLModelConfiguration()
            let model = try asl(configuration: config)
            return try VNCoreMLModel(for: model.model)
        } catch {
            fatalError("Could not load model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupLabel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // For testing: Check if label is working at all
        predictionLabel.text = "Waiting for prediction..."
        testModelWithDetectionImage()
    }
    
    
    func setupLabel() {
        predictionLabel = UILabel(frame: CGRect(x: 10, y: 80, width: view.frame.width - 20, height: 50))
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
            
            print("Starting camera session...")
            captureSession.startRunning()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("⚠️ Couldn't get pixel buffer")
            return
        }
        
        do {
            let config = MLModelConfiguration()
            let coreMLModel = try asl(configuration: config)
            
            // Resize to model's input size (608x608)
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let uiImage = UIImage(cgImage: cgImage)
            guard let resizedImage = uiImage.resize(to: CGSize(width: 608, height: 608)),
                  let modelBuffer = resizedImage.toCVPixelBuffer() else {
                print("⚠️ Failed to resize or convert image")
                return
            }
            
            let output = try coreMLModel.prediction(imagePath: modelBuffer,
                                                    iouThreshold: 0.3,
                                                    confidenceThreshold: 0.01)
            
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
                if bestConfidence > 0.5 {
                    bestLabel = String(UnicodeScalar(65 + bestIndex) ?? "?") // A = 65
                    self.predictionLabel.text = "Detected: \(bestLabel) (\(String(format: "%.2f", bestConfidence * 100))%)"
                    print("🎯 Detected: \(bestLabel), Confidence: \(bestConfidence)")
                } else {
                    self.predictionLabel.text = "Detecting..."
                }
            }
            
        } catch {
            print("❌ Real-time prediction failed: \(error)")
        }
    }
    
    func testModelWithDetectionImage() {
        print("🧪 Running object detection test...")
        
        guard let uiImage = UIImage(named: "TestImage"),
              let resizedImage = uiImage.resize(to: CGSize(width: 608, height: 608)),
              let pixelBuffer = resizedImage.toCVPixelBuffer() else {
            print("❌ Could not load or convert test image")
            return
        }
        
        do {
            let config = MLModelConfiguration()
            let model = try asl(configuration: config)
            
            let output = try model.prediction(imagePath: pixelBuffer,
                                              iouThreshold: 0.3,
                                              confidenceThreshold: 0.01)
            
            let confidenceArray = output.confidence
            let coordinateArray = output.coordinates
            
            // Post-processing
            for i in 0..<confidenceArray.shape[0].intValue {
                for j in 0..<confidenceArray.shape[1].intValue {
                    let confidence = confidenceArray[[NSNumber(value: i), NSNumber(value: j)]].doubleValue
                    if confidence > 0.5 {
                        print("✅ Detected class \(j) with confidence \(confidence)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.predictionLabel.text = "Check console for detected objects"
            }
            
        } catch {
            print("❌ Prediction failed: \(error)")
        }
    }
    
    
}
extension UIImage {
    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
    
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!] as CFDictionary
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
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}
