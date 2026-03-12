import SwiftUI
import AVFoundation

// MARK: - PhotoCaptureView

struct PhotoCaptureView: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var cameraManager = PhotoCameraManager()

    @State private var capturedImage: UIImage?
    @State private var showPermissionDenied = false
    @State private var permissionGranted = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = capturedImage {
                photoReviewView(image: image)
            } else if permissionGranted {
                cameraContent
            } else if showPermissionDenied {
                permissionDeniedView
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            checkPermissions()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            PhotoCameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topControls
                    .padding(.top, InvlogTheme.Spacing.md)

                Spacer()

                bottomControls
                    .padding(.bottom, InvlogTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")

            Spacer()

            // Flip camera
            Button {
                cameraManager.switchCamera()
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Flip camera")
        }
        .padding(.horizontal, InvlogTheme.Spacing.md)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(alignment: .bottom) {
            // Flash toggle
            VStack {
                Spacer()
                Button {
                    cameraManager.toggleFlash()
                } label: {
                    Image(systemName: cameraManager.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(cameraManager.flashMode == .on ? Color.brandSecondary : .white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .accessibilityLabel(cameraManager.flashMode == .on ? "Turn off flash" : "Turn on flash")
            }
            .frame(width: 60)

            Spacer()

            // Shutter button
            shutterButton

            Spacer()

            // Spacer to balance layout
            Color.clear.frame(width: 60, height: 44)
        }
        .padding(.horizontal, InvlogTheme.Spacing.md)
    }

    // MARK: - Shutter Button

    private var shutterButton: some View {
        Button {
            cameraManager.capturePhoto { image in
                capturedImage = image
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(Color.white)
                    .frame(width: 68, height: 68)
            }
        }
        .accessibilityLabel("Take photo")
    }

    // MARK: - Photo Review

    private func photoReviewView(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 40) {
                    // Retake
                    Button {
                        capturedImage = nil
                        cameraManager.resumeSession()
                    } label: {
                        Text("Retake")
                            .font(InvlogTheme.body(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    }
                    .accessibilityLabel("Retake photo")

                    // Use Photo
                    Button {
                        onCapture(image)
                        dismiss()
                    } label: {
                        Text("Use Photo")
                            .font(InvlogTheme.body(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(Color.brandPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
                    }
                    .accessibilityLabel("Use this photo")
                }
                .padding(.bottom, InvlogTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.brandTextTertiary)

            Text("Camera Access Required")
                .font(InvlogTheme.heading(20, weight: .bold))
                .foregroundColor(.white)

            Text("Invlog needs access to your camera to take photos.")
                .font(InvlogTheme.body(14))
                .foregroundColor(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Open Settings")
                    .font(InvlogTheme.body(15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 44)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.sm))
            }
            .accessibilityLabel("Open Settings to grant camera access")

            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(InvlogTheme.body(14))
                    .foregroundColor(Color.brandTextSecondary)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: - Permissions (camera only — no microphone needed for photos)

    private func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch videoStatus {
        case .authorized:
            permissionGranted = true
            cameraManager.setupSession()
        case .denied, .restricted:
            showPermissionDenied = true
        default:
            requestPermissions()
        }
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    permissionGranted = true
                    cameraManager.setupSession()
                } else {
                    showPermissionDenied = true
                }
            }
        }
    }
}

// MARK: - PhotoCameraManager

private class PhotoCameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back

    @Published var flashMode: AVCaptureDevice.FlashMode = .off

    private var photoCaptureCompletion: ((UIImage) -> Void)?

    // MARK: - Session Setup

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Video input (camera)
        if let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                    videoDeviceInput = input
                }
            } catch {
                // Camera input failed
            }
        }

        // Photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            if let connection = photoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func resumeSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    // MARK: - Capture Photo

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        photoCaptureCompletion = completion
        let settings = AVCapturePhotoSettings()

        // Configure flash
        if let device = videoDeviceInput?.device, device.hasFlash {
            settings.flashMode = flashMode
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Switch Camera

    func switchCamera() {
        session.beginConfiguration()

        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }

        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        currentCameraPosition = newPosition

        // Turn off flash when switching to front
        if newPosition == .front {
            flashMode = .off
        }

        if let newDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: newPosition
        ) {
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    videoDeviceInput = newInput
                }
            } catch {
                // Switch camera failed — re-add old input if possible
                if let oldInput = videoDeviceInput, session.canAddInput(oldInput) {
                    session.addInput(oldInput)
                }
            }
        }

        // Refresh video orientation
        if let connection = photoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        session.commitConfiguration()
    }

    // MARK: - Flash

    func toggleFlash() {
        guard currentCameraPosition == .back else { return }
        flashMode = (flashMode == .off) ? .on : .off
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.session.stopRunning()
            self?.photoCaptureCompletion?(image)
            self?.photoCaptureCompletion = nil
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

private struct PhotoCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PhotoCameraPreviewUIView {
        let view = PhotoCameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PhotoCameraPreviewUIView, context: Context) {
        // Session is managed externally; no updates needed here.
    }
}

private class PhotoCameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}
