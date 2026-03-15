import SwiftUI
import AVFoundation

// MARK: - VineRecorderView (Vine-style: hold to record, release to pause, hold again to continue)

struct VineRecorderView: View {
    var maxSeconds: Double = 10.0
    let onComplete: (URL, UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var cameraManager = CameraManager()

    @State private var isRecording = false
    @State private var recordedDuration: Double = 0
    @State private var recordTimer: Timer?
    @State private var hasStartedRecording = false

    @State private var isExporting = false
    @State private var showDiscardAlert = false
    @State private var showPermissionDenied = false
    @State private var permissionGranted = false

    private var maxDuration: Double { maxSeconds }
    private let timerInterval: Double = 0.05

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permissionGranted {
                cameraContent
            } else if showPermissionDenied {
                permissionDeniedView
            } else {
                ProgressView()
                    .tint(.white)
            }

            if isExporting {
                exportingOverlay
            }
        }
        .statusBarHidden(true)
        .onAppear {
            checkPermissions()
        }
        .onDisappear {
            stopTimer()
            cameraManager.stopSession()
        }
        .alert("Discard Recording?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                cameraManager.cleanupSegments()
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Your recorded video will be lost.")
        }
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                progressBar

                // Top controls
                topControls
                    .padding(.top, InvlogTheme.Spacing.xs)

                Spacer()

                // Duration label
                if isRecording || recordedDuration > 0 {
                    Text(formatDuration(recordedDuration))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }

                // Bottom controls
                bottomControls
                    .padding(.bottom, InvlogTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: geo.size.width * (recordedDuration / maxDuration), height: 4)
                    .animation(.linear(duration: timerInterval), value: recordedDuration)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            Button {
                if hasStartedRecording {
                    showDiscardAlert = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .disabled(isRecording)
            .opacity(isRecording ? 0.4 : 1)

            Spacer()

            if !isRecording {
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
            }
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
                    cameraManager.toggleTorch()
                } label: {
                    Image(systemName: cameraManager.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(cameraManager.isTorchOn ? Color.brandSecondary : .white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .frame(width: 60)

            Spacer()

            // Record button
            recordButton

            Spacer()

            // Done button (visible when paused with recorded segments)
            VStack {
                Spacer()
                if hasStartedRecording && !isRecording {
                    Button {
                        finishAndExport()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.brandPrimary)
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            .frame(width: 60)
            .animation(.easeInOut(duration: 0.2), value: hasStartedRecording && !isRecording)
        }
        .padding(.horizontal, InvlogTheme.Spacing.md)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        let buttonSize: CGFloat = 80

        return ZStack {
            // Outer ring — pulses red when recording
            Circle()
                .stroke(isRecording ? Color.red : Color.white, lineWidth: 4)
                .frame(width: buttonSize + 8, height: buttonSize + 8)
                .animation(.easeInOut(duration: 0.3), value: isRecording)

            if isRecording {
                // Recording indicator (smaller red circle, pulsing)
                Circle()
                    .fill(Color.red)
                    .frame(width: 36, height: 36)
            } else {
                // Start icon (big red circle)
                Circle()
                    .fill(Color.red)
                    .frame(width: buttonSize, height: buttonSize)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isRecording)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isRecording && recordedDuration < maxDuration {
                        resumeRecording()
                    }
                }
                .onEnded { _ in
                    if isRecording {
                        pauseRecording()
                    }
                }
        )
        .accessibilityLabel(isRecording ? "Recording... release to pause" : "Hold to record")
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

            Text("Invlog needs access to your camera and microphone to record videos.")
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

            Button { dismiss() } label: {
                Text("Go Back")
                    .font(InvlogTheme.body(14))
                    .foregroundColor(Color.brandTextSecondary)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    // MARK: - Exporting Overlay

    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                Text("Preparing video...")
                    .font(InvlogTheme.body(14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Permissions

    private func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch (videoStatus, audioStatus) {
        case (.authorized, .authorized):
            permissionGranted = true
            cameraManager.setupSession()
        case (.denied, _), (.restricted, _), (_, .denied), (_, .restricted):
            showPermissionDenied = true
        default:
            requestPermissions()
        }
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            guard videoGranted else {
                DispatchQueue.main.async { showPermissionDenied = true }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                DispatchQueue.main.async {
                    if audioGranted {
                        permissionGranted = true
                        cameraManager.setupSession()
                    } else {
                        showPermissionDenied = true
                    }
                }
            }
        }
    }

    // MARK: - Recording (multi-segment)

    private func resumeRecording() {
        hasStartedRecording = true
        cameraManager.startRecording()
        isRecording = true
        startTimer()
    }

    private func pauseRecording() {
        guard isRecording else { return }
        stopTimer()
        isRecording = false
        cameraManager.stopRecording()
    }

    private func finishAndExport() {
        guard hasStartedRecording else { return }
        isExporting = true
        Task {
            // Small delay to ensure last segment file is written
            try? await Task.sleep(nanoseconds: 500_000_000)
            await mergeAndFinish()
        }
    }

    private func startTimer() {
        recordTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                recordedDuration += timerInterval
                if recordedDuration >= maxDuration {
                    pauseRecording()
                    finishAndExport()
                }
            }
        }
    }

    private func stopTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
    }

    @MainActor
    private func mergeAndFinish() async {
        let segments = cameraManager.segmentURLs
        guard !segments.isEmpty else {
            isExporting = false
            return
        }

        let outputURL: URL
        if segments.count == 1 {
            // Single segment — no merge needed
            outputURL = segments[0]
        } else {
            // Merge multiple segments
            let composition = AVMutableComposition()
            guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                isExporting = false
                return
            }

            var insertTime = CMTime.zero
            for segmentURL in segments {
                let asset = AVURLAsset(url: segmentURL)
                let duration = asset.duration

                if let videoSource = asset.tracks(withMediaType: .video).first {
                    try? videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoSource, at: insertTime)
                    // Apply the transform from the first video track
                    if insertTime == .zero {
                        videoTrack.preferredTransform = videoSource.preferredTransform
                    }
                }
                if let audioSource = asset.tracks(withMediaType: .audio).first {
                    try? audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioSource, at: insertTime)
                }
                insertTime = CMTimeAdd(insertTime, duration)
            }

            let mergedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("vlog_merged_\(UUID().uuidString).mov")

            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                isExporting = false
                return
            }
            exporter.outputURL = mergedURL
            exporter.outputFileType = .mov

            await exporter.export()

            guard exporter.status == .completed else {
                isExporting = false
                return
            }

            outputURL = mergedURL
        }

        // Generate thumbnail
        let asset = AVURLAsset(url: outputURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)

        let thumbnail: UIImage
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            thumbnail = UIImage(cgImage: cgImage)
        } catch {
            thumbnail = UIImage(systemName: "video.fill") ?? UIImage()
        }

        // Clean up segment files
        cameraManager.cleanupSegments()

        isExporting = false
        onComplete(outputURL, thumbnail)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - CameraManager (multi-segment)

private class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()

    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var videoDeviceInput: AVCaptureDeviceInput?

    @Published var isTorchOn = false
    @Published var segmentURLs: [URL] = []

    var hasRecording: Bool { !segmentURLs.isEmpty }

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    videoDeviceInput = videoInput
                }
            } catch {}
        }

        if let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {}
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            if let connection = movieOutput.connection(with: .video) {
                setPortraitOrientation(on: connection)
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
        setTorch(on: false)
    }

    func startRecording() {
        guard !movieOutput.isRecording else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vlog_seg_\(UUID().uuidString).mov")

        if let connection = movieOutput.connection(with: .video) {
            setPortraitOrientation(on: connection)
        }

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    func cleanupSegments() {
        for url in segmentURLs {
            try? FileManager.default.removeItem(at: url)
        }
        segmentURLs.removeAll()
    }

    func switchCamera() {
        session.beginConfiguration()

        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }

        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        currentCameraPosition = newPosition

        if newPosition == .front { setTorch(on: false) }

        if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) {
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    videoDeviceInput = newInput
                }
            } catch {
                if let oldInput = videoDeviceInput, session.canAddInput(oldInput) {
                    session.addInput(oldInput)
                }
            }
        }

        if let connection = movieOutput.connection(with: .video) {
            setPortraitOrientation(on: connection)
        }

        session.commitConfiguration()
    }

    private func setPortraitOrientation(on connection: AVCaptureConnection) {
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    func toggleTorch() {
        guard currentCameraPosition == .back else { return }
        setTorch(on: !isTorchOn)
    }

    private func setTorch(on: Bool) {
        guard let device = videoDeviceInput?.device,
              device.hasTorch, device.isTorchAvailable else {
            DispatchQueue.main.async { self.isTorchOn = false }
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.isTorchOn = on }
        } catch {
            DispatchQueue.main.async { self.isTorchOn = false }
        }
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error = error {
            let nsError = error as NSError
            let success = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
            if !success {
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
        }
        DispatchQueue.main.async {
            self.segmentURLs.append(outputFileURL)
        }
    }
}

// MARK: - Camera Preview

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

private class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}
