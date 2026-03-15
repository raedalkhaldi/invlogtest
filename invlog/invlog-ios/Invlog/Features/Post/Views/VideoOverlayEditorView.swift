import SwiftUI
import AVFoundation

// MARK: - Overlay Item Model

struct VideoOverlayItem: Identifiable {
    let id = UUID()
    var kind: OverlayKind
    var position: CGPoint
    var fontSize: OverlayFontSize
    var color: OverlayColor

    enum OverlayKind: Equatable {
        case text(String)
        case location(String)
        case mention(String)

        var displayText: String {
            switch self {
            case .text(let t): return t
            case .location(let name): return name
            case .mention(let username): return "@\(username)"
            }
        }
    }
}

enum OverlayFontSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var pointSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 24
        case .large: return 36
        }
    }
}

enum OverlayColor: String, CaseIterable {
    case white = "White"
    case black = "Black"
    case brandPrimary = "Primary"
    case brandSecondary = "Secondary"
    case red = "Red"
    case blue = "Blue"

    var swiftUIColor: Color {
        switch self {
        case .white: return .white
        case .black: return .black
        case .brandPrimary: return .brandPrimary
        case .brandSecondary: return .brandSecondary
        case .red: return .red
        case .blue: return .blue
        }
    }

    var uiColor: UIColor {
        switch self {
        case .white: return .white
        case .black: return .black
        case .brandPrimary: return UIColor(Color.brandPrimary)
        case .brandSecondary: return UIColor(Color.brandSecondary)
        case .red: return .systemRed
        case .blue: return .systemBlue
        }
    }
}

// MARK: - VideoOverlayEditorView

struct VideoOverlayEditorView: View {
    let videoURL: URL
    let thumbnail: UIImage
    let placeName: String?
    let onComplete: (URL, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var overlays: [VideoOverlayItem] = []
    @State private var isExporting = false
    @State private var exportError: String?

    // Add text sheet
    @State private var showAddTextSheet = false
    @State private var newTextContent = ""
    @State private var newFontSize: OverlayFontSize = .medium
    @State private var newColor: OverlayColor = .white

    // Add mention sheet
    @State private var showAddMentionSheet = false
    @State private var newMentionUsername = ""

    // Editing state
    @State private var selectedOverlayId: UUID?

    // Video preview size for coordinate mapping
    @State private var previewSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                videoPreviewWithOverlays
                controlsSection
            }

            if isExporting {
                exportOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    cleanUpPlayer()
                    dismiss()
                }
                .foregroundColor(.white)
                .frame(minWidth: 44, minHeight: 44)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    handleExport()
                }
                .font(InvlogTheme.body(15, weight: .bold))
                .foregroundColor(Color.brandPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isExporting)
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { setupPlayer() }
        .onDisappear { cleanUpPlayer() }
        .alert("Export Failed", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let exportError { Text(exportError) }
        }
        .sheet(isPresented: $showAddTextSheet) {
            addTextSheet
        }
        .sheet(isPresented: $showAddMentionSheet) {
            addMentionSheet
        }
    }

    // MARK: - Video Preview with Overlays

    private var videoPreviewWithOverlays: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * (5.0 / 4.0)

            ZStack {
                Color.black

                if let player {
                    OverlayVideoPlayerView(player: player)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                }

                // Render overlay items
                ForEach($overlays) { $item in
                    overlayItemView(item: $item, containerSize: CGSize(width: width, height: height))
                }
            }
            .frame(width: width, height: height)
            .onAppear { previewSize = CGSize(width: width, height: height) }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    private func overlayItemView(item: Binding<VideoOverlayItem>, containerSize: CGSize) -> some View {
        let isSelected = selectedOverlayId == item.wrappedValue.id

        return Text(item.wrappedValue.kind.displayText)
            .font(.system(size: item.wrappedValue.fontSize.pointSize, weight: .bold))
            .foregroundColor(item.wrappedValue.color.swiftUIColor)
            .shadow(color: .black.opacity(0.6), radius: 2, x: 1, y: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
            .position(item.wrappedValue.position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newX = min(max(value.location.x, 0), containerSize.width)
                        let newY = min(max(value.location.y, 0), containerSize.height)
                        item.wrappedValue.position = CGPoint(x: newX, y: newY)
                    }
            )
            .onTapGesture {
                selectedOverlayId = (selectedOverlayId == item.wrappedValue.id) ? nil : item.wrappedValue.id
            }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: InvlogTheme.Spacing.sm) {
            Spacer().frame(height: InvlogTheme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InvlogTheme.Spacing.sm) {
                    overlayActionButton(icon: "textformat", label: "Text") {
                        newTextContent = ""
                        newFontSize = .medium
                        newColor = .white
                        showAddTextSheet = true
                    }

                    if let placeName, !placeName.isEmpty {
                        overlayActionButton(icon: "mappin.circle.fill", label: "Location") {
                            addLocationSticker(placeName)
                        }
                    }

                    overlayActionButton(icon: "at", label: "Mention") {
                        newMentionUsername = ""
                        showAddMentionSheet = true
                    }

                    if selectedOverlayId != nil {
                        overlayActionButton(icon: "trash", label: "Delete", color: .red) {
                            removeSelectedOverlay()
                        }
                    }
                }
                .padding(.horizontal, InvlogTheme.Spacing.md)
            }

            if overlays.isEmpty {
                Text("Tap buttons above to add text, location, or mentions")
                    .font(InvlogTheme.caption(12))
                    .foregroundColor(Color.brandTextTertiary)
                    .padding(.bottom, InvlogTheme.Spacing.sm)
            }

            Spacer().frame(height: InvlogTheme.Spacing.md)
        }
        .background(Color.black)
    }

    private func overlayActionButton(icon: String, label: String, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())

                Text(label)
                    .font(InvlogTheme.caption(11))
                    .foregroundColor(color)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Text Sheet

    private var addTextSheet: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextField("Enter text", text: $newTextContent)
                }

                Section("Size") {
                    Picker("Font Size", selection: $newFontSize) {
                        ForEach(OverlayFontSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(OverlayColor.allCases, id: \.self) { color in
                            Button {
                                newColor = color
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(color.swiftUIColor)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(newColor == color ? Color.brandPrimary : Color.brandBorder, lineWidth: newColor == color ? 3 : 1)
                                        )
                                    Text(color.rawValue)
                                        .font(InvlogTheme.caption(10))
                                        .foregroundColor(Color.brandText)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Text(newTextContent.isEmpty ? "Preview" : newTextContent)
                        .font(.system(size: newFontSize.pointSize, weight: .bold))
                        .foregroundColor(newColor.swiftUIColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddTextSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newTextContent.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        addTextOverlay(newTextContent, fontSize: newFontSize, color: newColor)
                        showAddTextSheet = false
                    }
                    .disabled(newTextContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add Mention Sheet

    private var addMentionSheet: some View {
        NavigationStack {
            Form {
                Section("Username") {
                    TextField("username", text: $newMentionUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Add Mention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMentionSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newMentionUsername.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        addMentionOverlay(newMentionUsername)
                        showAddMentionSheet = false
                    }
                    .disabled(newMentionUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Overlay Actions

    private func addTextOverlay(_ text: String, fontSize: OverlayFontSize, color: OverlayColor) {
        let center = CGPoint(x: previewSize.width / 2, y: previewSize.height / 2)
        let item = VideoOverlayItem(
            kind: .text(text),
            position: center,
            fontSize: fontSize,
            color: color
        )
        overlays.append(item)
        selectedOverlayId = item.id
    }

    private func addLocationSticker(_ name: String) {
        let position = CGPoint(x: previewSize.width / 2, y: previewSize.height * 0.85)
        let item = VideoOverlayItem(
            kind: .location(name),
            position: position,
            fontSize: .medium,
            color: .white
        )
        overlays.append(item)
        selectedOverlayId = item.id
    }

    private func addMentionOverlay(_ username: String) {
        let position = CGPoint(x: previewSize.width / 2, y: previewSize.height * 0.15)
        let item = VideoOverlayItem(
            kind: .mention(username),
            position: position,
            fontSize: .medium,
            color: .white
        )
        overlays.append(item)
        selectedOverlayId = item.id
    }

    private func removeSelectedOverlay() {
        guard let id = selectedOverlayId else { return }
        overlays.removeAll { $0.id == id }
        selectedOverlayId = nil
    }

    // MARK: - Export Overlay UI

    private var exportOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: InvlogTheme.Spacing.sm) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Burning overlays...")
                    .font(InvlogTheme.body(14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(InvlogTheme.Spacing.xl)
            .background(Color.brandText.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.isMuted = true
        avPlayer.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        player = avPlayer
        avPlayer.play()
    }

    private func cleanUpPlayer() {
        player?.pause()
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
        }
        player = nil
    }

    // MARK: - Export

    private func handleExport() {
        if overlays.isEmpty {
            // No overlays, pass through directly
            cleanUpPlayer()
            onComplete(videoURL, thumbnail)
            dismiss()
            return
        }

        isExporting = true
        let overlaysCopy = overlays
        let previewSizeCopy = previewSize
        Task {
            do {
                let (exportedURL, exportedThumb) = try await exportWithOverlays(
                    overlays: overlaysCopy,
                    previewSize: previewSizeCopy
                )
                await MainActor.run {
                    isExporting = false
                    cleanUpPlayer()
                    onComplete(exportedURL, exportedThumb)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }

    private func exportWithOverlays(overlays: [VideoOverlayItem], previewSize: CGSize) async throws -> (URL, UIImage) {
        let screenScale = await MainActor.run { UIScreen.main.scale }
        let asset = AVURLAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("overlay_\(UUID().uuidString).mp4")

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoOverlay", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No video track found."])
        }

        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        let isRotated = abs(transform.b) == 1.0 && abs(transform.c) == 1.0
        let videoSize = isRotated ? CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize

        // Build composition
        let composition = AVMutableComposition()
        guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "VideoOverlay", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create video track."])
        }

        let duration = asset.duration
        try compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
        compVideoTrack.preferredTransform = videoTrack.preferredTransform

        // Add audio track if present
        if let audioTrack = asset.tracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
        }

        // Create overlay layer
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: videoSize)

        let scaleX = videoSize.width / previewSize.width
        let scaleY = videoSize.height / previewSize.height

        for item in overlays {
            let textLayer = CATextLayer()
            textLayer.string = item.kind.displayText
            textLayer.font = UIFont.boldSystemFont(ofSize: item.fontSize.pointSize * scaleX) as CFTypeRef
            textLayer.fontSize = item.fontSize.pointSize * scaleX
            textLayer.foregroundColor = item.color.uiColor.cgColor
            textLayer.shadowColor = UIColor.black.cgColor
            textLayer.shadowOpacity = 0.6
            textLayer.shadowOffset = CGSize(width: 1 * scaleX, height: 1 * scaleY)
            textLayer.shadowRadius = 2 * scaleX
            textLayer.alignmentMode = .center
            textLayer.contentsScale = screenScale
            textLayer.isWrapped = true

            // Calculate size
            let maxWidth = videoSize.width * 0.9
            let textSize = (item.kind.displayText as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: UIFont.boldSystemFont(ofSize: item.fontSize.pointSize * scaleX)],
                context: nil
            ).size

            let layerWidth = min(textSize.width + 20 * scaleX, maxWidth)
            let layerHeight = textSize.height + 12 * scaleY

            // Map position from preview coordinates to video coordinates
            // In Core Animation, y=0 is at bottom
            let videoX = item.position.x * scaleX - layerWidth / 2
            let videoY = videoSize.height - (item.position.y * scaleY) - layerHeight / 2

            textLayer.frame = CGRect(x: videoX, y: videoY, width: layerWidth, height: layerHeight)
            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.3).cgColor
            textLayer.cornerRadius = 6 * scaleX

            overlayLayer.addSublayer(textLayer)
        }

        // Build video composition with overlay
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        if isRotated {
            layerInstruction.setTransform(transform, at: .zero)
        }
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "VideoOverlay", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create export session."])
        }

        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(
                domain: "VideoOverlay", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Export failed with status: \(exportSession.status.rawValue)"]
            )
        }

        // Generate thumbnail from exported video
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: outputURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let exportedThumb = UIImage(cgImage: cgImage)

        return (outputURL, exportedThumb)
    }
}

// MARK: - Overlay Video Player (UIViewRepresentable)

private struct OverlayVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> OverlayPlayerUIView {
        OverlayPlayerUIView(player: player)
    }

    func updateUIView(_ uiView: OverlayPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private class OverlayPlayerUIView: UIView {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
