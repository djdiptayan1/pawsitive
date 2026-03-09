//
//  CameraViewModel.swift
//  pawsitive-app
//
//  Created by Diptayan Jash on 09/03/26.
//

import AVFoundation
import SwiftUI
import Combine

@MainActor
final class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var permissionGranted = false
    @Published var isCameraAvailable = false
    @Published var capturedImage: UIImage?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    override init() {
        super.init()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            if !isConfigured { setupSession() }
            startSession()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                permissionGranted = granted
                if granted { 
                    if !self.isConfigured { self.setupSession() }
                    self.startSession()
                }
            }
        default:
            permissionGranted = false
        }
    }

    func setupSession() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            isCameraAvailable = true
        }

        session.commitConfiguration()
        isConfigured = true
        startSession()
    }

    func startSession() {
        guard !session.isRunning else { return }
        Task.detached { [session] in
            session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        Task.detached { [session] in
            session.stopRunning()
        }
    }

    // Async capture function
    func capturePhoto() async -> UIImage? {
        // Run capture on MainActor to set continuation safely
        return await withCheckedContinuation { continuation in
            self.captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // Delegate callback
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let imageData = photo.fileDataRepresentation()
        
        Task { @MainActor in
            guard error == nil, let data = imageData, let image = UIImage(data: data) else {
                self.captureContinuation?.resume(returning: nil)
                self.captureContinuation = nil
                return
            }
            self.capturedImage = image
            self.captureContinuation?.resume(returning: image)
            self.captureContinuation = nil
        }
    }
}
