import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

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

    // Segment tracking for progress bar markers
    @State private var segmentStartTimes: [Double] = []
    @State private var segmentEndTimes: [Double] = []

    // Speed control
    @State private var selectedSpeed: RecordingSpeed = .normal

    // Live filter preview
    @State private var selectedFilter: VideoFilter = .original
    @State private var showFilterSelector = false

    private var maxDuration: Double { maxSeconds }
    private let timerInterval: Double = 0.05

    private var remainingSeconds: Double {
        max(0, maxDuration - recordedDuration)
    }

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
            // Live filtered camera preview
            FilteredCameraPreviewView(cameraManager: cameraManager, filter: selectedFilter)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            cameraManager.setZoom(scale: scale)
                        }
                        .onEnded { _ in
                            cameraManager.finalizeZoom()
                        }
                )

            VStack(spacing: 0) {
                // Progress bar with segment markers
                segmentedProgressBar

                // Top controls
                topControls
                    .padding(.top, InvlogTheme.Spacing.xs)

                Spacer()

                // Countdown timer label
                if isRecording || recordedDuration > 0 {
                    countdownLabel
                        .padding(.bottom, 8)
                }

                // Speed control buttons
                if !isRecording || !hasStartedRecording {
                    speedControlButtons
                        .padding(.bottom, 12)
                }

                // Filter selector strip
                if showFilterSelector {
                    filterSelectorStrip
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }

                // Bottom controls
                bottomControls
                    .padding(.bottom, InvlogTheme.Spacing.xl)
            }
        }
    }

    // MARK: - Segmented Progress Bar

    private var segmentedProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                // Current progress fill
                Rectangle()
                    .fill(Color.brandPrimary)
                    .frame(width: geo.size.width * (recordedDuration / maxDuration), height: 4)
                    .animation(.linear(duration: timerInterval), value: recordedDuration)

                // Segment boundary markers (white dividers between segments)
                ForEach(Array(segmentEndTimes.enumerated()), id: \.offset) { _, endTime in
                    if endTime < recordedDuration {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 6)
                            .offset(x: geo.size.width * (endTime / maxDuration) - 1)
                    }
                }
            }
        }
        .frame(height: 6)
    }

    // MARK: - Countdown Label

    private var countdownLabel: some View {
        HStack(spacing: 8) {
            // Remaining time
            Text(String(format: "%.1fs", remainingSeconds))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(remainingSeconds <= 3.0 ? .red : .white)

            // Elapsed / total
            Text(formatDuration(recordedDuration))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Speed Control Buttons

    private var speedControlButtons: some View {
        HStack(spacing: 12) {
            ForEach(RecordingSpeed.allCases, id: \.self) { speed in
                Button {
                    selectedSpeed = speed
                    cameraManager.setRecordingSpeed(speed)
                } label: {
                    Text(speed.label)
                        .font(.system(size: 13, weight: selectedSpeed == speed ? .bold : .medium))
                        .foregroundColor(selectedSpeed == speed ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedSpeed == speed ? Color.white : Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Filter Selector Strip

    private var filterSelectorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(VideoFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(InvlogTheme.caption(12, weight: selectedFilter == filter ? .bold : .regular))
                            .foregroundColor(selectedFilter == filter ? Color.brandPrimary : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.white.opacity(0.25) : Color.black.opacity(0.4))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, InvlogTheme.Spacing.md)
        }
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

            // Record button + filter toggle
            VStack(spacing: 12) {
                recordButton

                // Filter toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilterSelector.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.filters")
                            .font(.system(size: 14, weight: .semibold))
                        if selectedFilter != .original {
                            Text(selectedFilter.rawValue)
                                .font(InvlogTheme.caption(11, weight: .semibold))
                        }
                    }
                    .foregroundColor(selectedFilter != .original ? Color.brandPrimary : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

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
        segmentStartTimes.append(recordedDuration)
        cameraManager.startRecording()
        isRecording = true
        startTimer()
    }

    private func pauseRecording() {
        guard isRecording else { return }
        stopTimer()
        segmentEndTimes.append(recordedDuration)
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

// MARK: - Recording Speed

enum RecordingSpeed: CaseIterable {
    case half
    case normal
    case double

    var label: String {
        switch self {
        case .half: return "0.5x"
        case .normal: return "1x"
        case .double: return "2x"
        }
    }

    var frameRateDivisor: Int {
        switch self {
        case .half: return 2     // half speed = double frame duration
        case .normal: return 1
        case .double: return 1   // double speed handled via minFrameDuration
        }
    }

    var targetFPS: Double {
        switch self {
        case .half: return 15    // 15fps capture -> plays back at 30fps = 0.5x speed
        case .normal: return 30
        case .double: return 60  // 60fps capture -> plays back at 30fps = 2x speed (or we drop frames)
        }
    }
}

// MARK: - CameraManager (multi-segment with video data output for live filter preview)

private class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataQueue = DispatchQueue(label: "com.invlog.videoDataOutput", qos: .userInitiated)

    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var videoDeviceInput: AVCaptureDeviceInput?

    @Published var isTorchOn = false
    @Published var segmentURLs: [URL] = []
    @Published var currentPixelBuffer: CVPixelBuffer?

    // Zoom state
    private var lastZoomFactor: CGFloat = 1.0

    var hasRecording: Bool { !segmentURLs.isEmpty }

    func setupSession() {
        session.beginConfiguration()

        // Use 1920x1080 resolution
        session.sessionPreset = .hd1920x1080

        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            do {
                // Configure the device for best quality
                try videoDevice.lockForConfiguration()

                // Select the best 1080p format available
                let targetWidth: Int32 = 1920
                let targetHeight: Int32 = 1080
                var bestFormat: AVCaptureDevice.Format?
                var bestFrameRate: AVFrameRateRange?

                for format in videoDevice.formats {
                    let desc = format.formatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
                    if dimensions.width == targetWidth && dimensions.height == targetHeight {
                        for range in format.videoSupportedFrameRateRanges {
                            if bestFrameRate == nil || range.maxFrameRate > bestFrameRate!.maxFrameRate {
                                bestFormat = format
                                bestFrameRate = range
                            }
                        }
                    }
                }

                if let format = bestFormat, let frameRate = bestFrameRate {
                    videoDevice.activeFormat = format
                    videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(frameRate.maxFrameRate, 30)))
                    videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(frameRate.maxFrameRate, 30)))
                }

                videoDevice.unlockForConfiguration()

                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    videoDeviceInput = videoInput
                }
            } catch {}
        }

        // Audio input - select best built-in mic configuration
        if let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified) {
            do {
                try audioDevice.lockForConfiguration()

                // Select the highest sample rate format available
                var bestAudioFormat: AVCaptureDevice.Format?
                var bestSampleRate: Float64 = 0

                for format in audioDevice.formats {
                    let desc = format.formatDescription
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
                    if let sampleRate = asbd?.pointee.mSampleRate, sampleRate > bestSampleRate {
                        bestSampleRate = sampleRate
                        bestAudioFormat = format
                    }
                }

                if let format = bestAudioFormat {
                    audioDevice.activeFormat = format
                }

                audioDevice.unlockForConfiguration()

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

                // Enable video stabilization
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .cinematic
                }
            }
        }

        // Add video data output for live preview filtering
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
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

            // Ensure stabilization is enabled for each segment
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .cinematic
            }
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
                // Configure 1080p on the new device too
                try newDevice.lockForConfiguration()

                let targetWidth: Int32 = 1920
                let targetHeight: Int32 = 1080
                var bestFormat: AVCaptureDevice.Format?
                var bestFrameRate: AVFrameRateRange?

                for format in newDevice.formats {
                    let desc = format.formatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
                    if dimensions.width == targetWidth && dimensions.height == targetHeight {
                        for range in format.videoSupportedFrameRateRanges {
                            if bestFrameRate == nil || range.maxFrameRate > bestFrameRate!.maxFrameRate {
                                bestFormat = format
                                bestFrameRate = range
                            }
                        }
                    }
                }

                if let format = bestFormat, let frameRate = bestFrameRate {
                    newDevice.activeFormat = format
                    newDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(frameRate.maxFrameRate, 30)))
                    newDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(frameRate.maxFrameRate, 30)))
                }

                newDevice.unlockForConfiguration()

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

            // Re-enable stabilization after camera switch
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .cinematic
            }
        }

        if let connection = videoDataOutput.connection(with: .video) {
            setPortraitOrientation(on: connection)
        }

        // Reset zoom on camera switch
        lastZoomFactor = 1.0

        session.commitConfiguration()
    }

    private func setPortraitOrientation(on connection: AVCaptureConnection) {
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    // MARK: - Zoom

    func setZoom(scale: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6.0)
            let newFactor = min(max(lastZoomFactor * scale, 1.0), maxZoom)
            device.videoZoomFactor = newFactor
            device.unlockForConfiguration()
        } catch {}
    }

    func finalizeZoom() {
        guard let device = videoDeviceInput?.device else { return }
        lastZoomFactor = device.videoZoomFactor
    }

    // MARK: - Recording Speed

    func setRecordingSpeed(_ speed: RecordingSpeed) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            let targetFPS = speed.targetFPS

            // Find a format that supports the target FPS at 1080p
            var bestFormat: AVCaptureDevice.Format?
            var bestRange: AVFrameRateRange?

            for format in device.formats {
                let desc = format.formatDescription
                let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
                if dimensions.width == 1920 && dimensions.height == 1080 {
                    for range in format.videoSupportedFrameRateRanges {
                        if range.maxFrameRate >= targetFPS {
                            if bestRange == nil || range.maxFrameRate < bestRange!.maxFrameRate {
                                // Prefer the format with the smallest max that still meets our target
                                bestFormat = format
                                bestRange = range
                            }
                        }
                    }
                }
            }

            if let format = bestFormat {
                device.activeFormat = format
            }

            let clampedFPS = min(targetFPS, bestRange?.maxFrameRate ?? 30)
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(clampedFPS))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(clampedFPS))

            device.unlockForConfiguration()
        } catch {}
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

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        DispatchQueue.main.async {
            self.currentPixelBuffer = pixelBuffer
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

// MARK: - Filtered Camera Preview (renders CIFilter on live camera frames via Metal)

private struct FilteredCameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    let filter: VideoFilter

    func makeUIView(context: Context) -> FilteredCameraUIView {
        FilteredCameraUIView()
    }

    func updateUIView(_ uiView: FilteredCameraUIView, context: Context) {
        uiView.currentFilter = filter
        if let pixelBuffer = cameraManager.currentPixelBuffer {
            uiView.renderFilteredFrame(pixelBuffer)
        }
    }
}

private class FilteredCameraUIView: UIView {
    private let metalLayer: CAMetalLayer?
    private let ciContext: CIContext
    private let commandQueue: MTLCommandQueue?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    var currentFilter: VideoFilter = .original

    override init(frame: CGRect) {
        let device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()

        if let device {
            ciContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
            let ml = CAMetalLayer()
            ml.device = device
            ml.pixelFormat = .bgra8Unorm
            ml.framebufferOnly = false
            ml.contentsScale = UIScreen.main.scale
            metalLayer = ml
        } else {
            ciContext = CIContext()
            metalLayer = nil
        }

        super.init(frame: frame)

        if let metalLayer {
            layer.addSublayer(metalLayer)
        }
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalLayer?.frame = bounds
        metalLayer?.drawableSize = CGSize(
            width: bounds.width * contentScaleFactor,
            height: bounds.height * contentScaleFactor
        )
    }

    func renderFilteredFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let metalLayer, let commandQueue else { return }

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply the selected filter
        if currentFilter != .original {
            ciImage = applyFilter(to: ciImage, filter: currentFilter)
        }

        // Scale to fill the drawable
        guard let drawable = metalLayer.nextDrawable() else { return }
        let drawableSize = metalLayer.drawableSize

        let scaleX = drawableSize.width / ciImage.extent.width
        let scaleY = drawableSize.height / ciImage.extent.height
        let scale = max(scaleX, scaleY)

        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let offsetX = (drawableSize.width - scaledImage.extent.width) / 2
        let offsetY = (drawableSize.height - scaledImage.extent.height) / 2
        let finalImage = scaledImage.transformed(by: CGAffineTransform(translationX: offsetX - scaledImage.extent.origin.x, y: offsetY - scaledImage.extent.origin.y))

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let destination = CIRenderDestination(
            width: Int(drawableSize.width),
            height: Int(drawableSize.height),
            pixelFormat: metalLayer.pixelFormat,
            commandBuffer: commandBuffer,
            mtlTextureProvider: { drawable.texture }
        )

        do {
            try ciContext.startTask(toRender: finalImage, to: destination)
        } catch {
            return
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func applyFilter(to image: CIImage, filter: VideoFilter) -> CIImage {
        switch filter {
        case .original:
            return image

        case .vivid:
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(1.5, forKey: "inputSaturation")
            f.setValue(1.1, forKey: "inputContrast")
            return f.outputImage ?? image

        case .warm:
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 5500, y: 0), forKey: "inputNeutral")
            return f.outputImage ?? image

        case .cool:
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(image, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 8000, y: 0), forKey: "inputNeutral")
            return f.outputImage ?? image

        case .noir:
            let f = CIFilter(name: "CIPhotoEffectNoir")!
            f.setValue(image, forKey: kCIInputImageKey)
            return f.outputImage ?? image

        case .fade:
            let f = CIFilter(name: "CIPhotoEffectFade")!
            f.setValue(image, forKey: kCIInputImageKey)
            return f.outputImage ?? image

        case .beauty:
            let blurFilter = CIFilter(name: "CIGaussianBlur")!
            blurFilter.setValue(image, forKey: kCIInputImageKey)
            blurFilter.setValue(3.0, forKey: kCIInputRadiusKey)
            guard let blurred = blurFilter.outputImage else { return image }
            let croppedBlur = blurred.cropped(to: image.extent)

            let alphaFilter = CIFilter(name: "CIColorMatrix")!
            alphaFilter.setValue(croppedBlur, forKey: kCIInputImageKey)
            alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.4), forKey: "inputAVector")
            guard let semiBlur = alphaFilter.outputImage else { return image }

            let origAlpha = CIFilter(name: "CIColorMatrix")!
            origAlpha.setValue(image, forKey: kCIInputImageKey)
            origAlpha.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            origAlpha.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            origAlpha.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            origAlpha.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.6), forKey: "inputAVector")
            guard let semiOrig = origAlpha.outputImage else { return image }

            let composite = CIFilter(name: "CIAdditionCompositing")!
            composite.setValue(semiBlur, forKey: kCIInputImageKey)
            composite.setValue(semiOrig, forKey: kCIInputBackgroundImageKey)
            guard let blended = composite.outputImage else { return image }

            let brighten = CIFilter(name: "CIColorControls")!
            brighten.setValue(blended, forKey: kCIInputImageKey)
            brighten.setValue(0.03, forKey: kCIInputBrightnessKey)
            brighten.setValue(1.05, forKey: "inputContrast")
            return brighten.outputImage ?? blended
        }
    }
}

// MARK: - Camera Preview (kept as fallback)

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
