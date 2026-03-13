import SwiftUI
import AVFoundation

// MARK: - VineRecorderView

struct VineRecorderView: View {
    let onComplete: (URL, UIImage) -> Void
    var maxSeconds: Double = 10.0
    @Environment(\.dismiss) private var dismiss

    @StateObject private var cameraManager = CameraManager()

    @State private var isRecording = false
    @State private var totalDuration: Double = 0
    @State private var segmentDurations: [Double] = []
    @State private var currentSegmentDuration: Double = 0
    @State private var recordTimer: Timer?

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
                cleanupSegments()
                dismiss()
            }
            Button("Keep Recording", role: .cancel) {}
        } message: {
            Text("Your recorded clips will be lost if you go back.")
        }
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            // Live camera preview
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar at very top
                progressBar
                    .padding(.top, 0)

                // Top controls
                topControls
                    .padding(.top, InvlogTheme.Spacing.xs)

                Spacer()

                // Bottom controls
                bottomControls
                    .padding(.bottom, InvlogTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                // Segment sections
                HStack(spacing: 0) {
                    let allDurations = segmentDurations + (isRecording ? [currentSegmentDuration] : [])
                    ForEach(Array(allDurations.enumerated()), id: \.offset) { index, duration in
                        let fraction = duration / maxDuration
                        let segmentWidth = fraction * totalWidth

                        if index > 0 {
                            // White divider between segments
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2, height: 4)
                        }

                        Rectangle()
                            .fill(Color.brandPrimary)
                            .frame(width: max(0, segmentWidth), height: 4)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: 4)
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            // Close button
            Button {
                if !cameraManager.segments.isEmpty {
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
            .accessibilityLabel("Close")

            Spacer()

            // Flip camera button
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
            // Flash / torch toggle
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
                .accessibilityLabel(cameraManager.isTorchOn ? "Turn off flash" : "Turn on flash")
            }
            .frame(width: 60)

            Spacer()

            // Record button
            recordButton

            Spacer()

            // Right side: delete + next
            VStack(spacing: 16) {
                // Next / checkmark button
                if totalDuration > 1.0 {
                    Button {
                        finishRecording()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.brandPrimary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Next")
                    .transition(.scale.combined(with: .opacity))
                }

                // Delete last segment button
                if !cameraManager.segments.isEmpty {
                    Button {
                        deleteLastSegment()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Delete last clip")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 60)
            .animation(.easeInOut(duration: 0.2), value: cameraManager.segments.count)
            .animation(.easeInOut(duration: 0.2), value: totalDuration > 1.0)
        }
        .padding(.horizontal, InvlogTheme.Spacing.md)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        let buttonSize: CGFloat = isRecording ? 88 : 80

        return ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white, lineWidth: 4)
                .frame(width: buttonSize + 8, height: buttonSize + 8)

            // Inner red circle
            Circle()
                .fill(Color.red)
                .frame(width: buttonSize, height: buttonSize)
        }
        .animation(.easeInOut(duration: 0.15), value: isRecording)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isRecording {
                        startRecordingSegment()
                    }
                }
                .onEnded { _ in
                    if isRecording {
                        stopRecordingSegment()
                    }
                }
        )
        .accessibilityLabel("Hold to record")
        .accessibilityHint("Press and hold to record a clip. Release to stop.")
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

    // MARK: - Recording Controls

    private func startRecordingSegment() {
        guard totalDuration < maxDuration else { return }

        currentSegmentDuration = 0
        cameraManager.startRecording()
        isRecording = true
        startTimer()
    }

    private func stopRecordingSegment() {
        guard isRecording else { return }

        stopTimer()
        isRecording = false
        cameraManager.stopRecording()

        // Duration is finalized in the delegate callback,
        // but we already tracked it via the timer for UI purposes.
        let segmentDur = currentSegmentDuration
        segmentDurations.append(segmentDur)
        totalDuration = segmentDurations.reduce(0, +)
        currentSegmentDuration = 0

        // Check if we hit max
        if totalDuration >= maxDuration {
            finishRecording()
        }
    }

    private func startTimer() {
        recordTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                currentSegmentDuration += timerInterval
                let running = segmentDurations.reduce(0, +) + currentSegmentDuration

                if running >= maxDuration {
                    currentSegmentDuration = maxDuration - segmentDurations.reduce(0, +)
                    stopRecordingSegment()
                }
            }
        }
    }

    private func stopTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
    }

    private func deleteLastSegment() {
        guard !cameraManager.segments.isEmpty else { return }

        let removed = cameraManager.segments.removeLast()
        try? FileManager.default.removeItem(at: removed)

        if !segmentDurations.isEmpty {
            segmentDurations.removeLast()
        }
        totalDuration = segmentDurations.reduce(0, +)
    }

    private func finishRecording() {
        guard !cameraManager.segments.isEmpty else { return }

        // If currently recording, stop first
        if isRecording {
            stopRecordingSegment()
        }

        isExporting = true
        Task {
            do {
                let (videoURL, thumbnail) = try await stitchSegments(cameraManager.segments)
                await MainActor.run {
                    isExporting = false
                    onComplete(videoURL, thumbnail)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }

    // MARK: - Segment Stitching

    private func stitchSegments(_ segments: [URL]) async throws -> (URL, UIImage) {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw StitchError.failedToCreateTrack
        }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var insertTime = CMTime.zero

        for segmentURL in segments {
            let asset = AVURLAsset(url: segmentURL)
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            // Insert video track
            if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: insertTime)

                // Apply the preferred transform from the first segment
                if insertTime == .zero {
                    let transform = try await assetVideoTrack.load(.preferredTransform)
                    videoTrack.preferredTransform = transform
                }
            }

            // Insert audio track
            if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: insertTime)
            }

            insertTime = CMTimeAdd(insertTime, duration)
        }

        // Export
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vine_\(UUID().uuidString).mp4")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw StitchError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw exportSession.error ?? StitchError.exportSessionFailed
        }

        // Generate thumbnail
        let thumbnailAsset = AVURLAsset(url: outputURL)
        let generator = AVAssetImageGenerator(asset: thumbnailAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)

        let thumbnail: UIImage
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            thumbnail = UIImage(cgImage: cgImage)
        } catch {
            thumbnail = UIImage(systemName: "video.fill") ?? UIImage()
        }

        // Clean up segment temp files
        for segment in segments {
            try? FileManager.default.removeItem(at: segment)
        }

        return (outputURL, thumbnail)
    }

    private func cleanupSegments() {
        for segment in cameraManager.segments {
            try? FileManager.default.removeItem(at: segment)
        }
        cameraManager.segments.removeAll()
    }

    // MARK: - Errors

    private enum StitchError: LocalizedError {
        case failedToCreateTrack
        case exportSessionFailed

        var errorDescription: String? {
            switch self {
            case .failedToCreateTrack:
                return "Failed to create video track for composition."
            case .exportSessionFailed:
                return "Failed to export the final video."
            }
        }
    }
}

// MARK: - CameraManager

private class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()

    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var videoDeviceInput: AVCaptureDeviceInput?

    @Published var isTorchOn = false
    @Published var segments: [URL] = []

    private var currentRecordingURL: URL?

    // MARK: - Session Setup

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Video input
        if let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) {
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    videoDeviceInput = videoInput
                }
            } catch {
                // Video input failed
            }
        }

        // Audio input
        if let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                // Audio input failed
            }
        }

        // Movie file output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)

            // Set video connection to portrait
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

    // MARK: - Recording

    func startRecording() {
        guard !movieOutput.isRecording else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("segment_\(UUID().uuidString).mov")
        currentRecordingURL = tempURL

        // Ensure video connection orientation is correct before each recording
        if let connection = movieOutput.connection(with: .video) {
            setPortraitOrientation(on: connection)
        }

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    // MARK: - Switch Camera

    func switchCamera() {
        session.beginConfiguration()

        // Remove current video input
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }

        // Toggle position
        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        currentCameraPosition = newPosition

        // Turn off torch when switching to front
        if newPosition == .front {
            setTorch(on: false)
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

        // Re-apply video rotation on the new connection
        if let connection = movieOutput.connection(with: .video) {
            setPortraitOrientation(on: connection)
        }

        session.commitConfiguration()
    }

    // MARK: - Video Orientation Helper

    private func setPortraitOrientation(on connection: AVCaptureConnection) {
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    // MARK: - Torch

    func toggleTorch() {
        guard currentCameraPosition == .back else { return }
        setTorch(on: !isTorchOn)
    }

    private func setTorch(on: Bool) {
        guard let device = videoDeviceInput?.device,
              device.hasTorch,
              device.isTorchAvailable else {
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
            // Recording may still have saved usable data
            let nsError = error as NSError
            let recordingSuccessful = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
            if !recordingSuccessful {
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
        }

        DispatchQueue.main.async {
            self.segments.append(outputFileURL)
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Session is managed externally; no updates needed here.
    }
}

private class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }
}
