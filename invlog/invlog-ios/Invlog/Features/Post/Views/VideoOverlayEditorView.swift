import SwiftUI
import AVFoundation

// MARK: - Overlay Item Model

struct VideoOverlayItem: Identifiable {
    let id = UUID()
    var kind: OverlayKind
    var position: CGPoint
    var fontSize: OverlayFontSize
    var color: OverlayColor
    var scale: CGFloat = 1.0  // For sticker pinch-to-resize

    enum OverlayKind: Equatable {
        case text(String)
        case location(String)
        case mention(String)
        case sticker(url: URL, width: CGFloat, height: CGFloat)

        var displayText: String {
            switch self {
            case .text(let t): return t
            case .location(let name): return name
            case .mention(let username): return "@\(username)"
            case .sticker: return ""
            }
        }

        var isSticker: Bool {
            if case .sticker = self { return true }
            return false
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

// MARK: - VideoOverlayEditorView (supports both video and photo)

@MainActor
struct VideoOverlayEditorView: View {
    // Video mode
    let videoURL: URL?
    let thumbnail: UIImage
    let placeName: String?
    let onComplete: (URL, UIImage) -> Void

    // Photo mode
    let photoImage: UIImage?
    let onCompletePhoto: ((UIImage) -> Void)?

    /// Video mode initializer
    init(videoURL: URL, thumbnail: UIImage, placeName: String? = nil, onComplete: @escaping (URL, UIImage) -> Void) {
        self.videoURL = videoURL
        self.thumbnail = thumbnail
        self.placeName = placeName
        self.onComplete = onComplete
        self.photoImage = nil
        self.onCompletePhoto = nil
    }

    /// Photo mode initializer
    init(image: UIImage, placeName: String? = nil, onCompletePhoto: @escaping (UIImage) -> Void) {
        self.videoURL = nil
        self.thumbnail = image
        self.placeName = placeName
        self.onComplete = { _, _ in }
        self.photoImage = image
        self.onCompletePhoto = onCompletePhoto
    }

    private var isPhotoMode: Bool { photoImage != nil }

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

    // Sticker picker
    @State private var showStickerPicker = false

    // Editing state
    @State private var selectedOverlayId: UUID?

    // Preview size for coordinate mapping
    @State private var previewSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                mediaPreviewWithOverlays
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
        .onAppear {
            if !isPhotoMode { setupPlayer() }
        }
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
        .sheet(isPresented: $showStickerPicker) {
            StickerPickerView { sticker in
                addStickerOverlay(sticker)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Media Preview with Overlays

    private var mediaPreviewWithOverlays: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * (5.0 / 4.0)

            ZStack {
                Color.black

                if isPhotoMode, let photoImage {
                    Image(uiImage: photoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
                } else if let player {
                    SimpleVideoPlayerView(player: player)
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

    @ViewBuilder
    private func overlayItemView(item: Binding<VideoOverlayItem>, containerSize: CGSize) -> some View {
        let isSelected = selectedOverlayId == item.wrappedValue.id

        if case .sticker(let url, let width, let height) = item.wrappedValue.kind {
            // Sticker overlay
            let aspectRatio = width / max(height, 1)
            let baseWidth: CGFloat = 120
            let stickerWidth = baseWidth * item.wrappedValue.scale
            let stickerHeight = stickerWidth / aspectRatio

            ZStack {
                AnimatedGIFView(url: url)
                    .allowsHitTesting(false)
                Color.clear
            }
            .frame(width: stickerWidth, height: stickerHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .position(item.wrappedValue.position)
            .gesture(stickerGesture(item: item, containerSize: containerSize))
            .onTapGesture {
                selectedOverlayId = (selectedOverlayId == item.wrappedValue.id) ? nil : item.wrappedValue.id
            }
        } else {
            // Text/location/mention overlay — draggable AND pinch-resizable
            Text(item.wrappedValue.kind.displayText)
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
                .scaleEffect(item.wrappedValue.scale)
                .position(item.wrappedValue.position)
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let newX = min(max(value.location.x, 0), containerSize.width)
                                let newY = min(max(value.location.y, 0), containerSize.height)
                                item.wrappedValue.position = CGPoint(x: newX, y: newY)
                            },
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = item.wrappedValue.scale * value
                                item.wrappedValue.scale = min(max(newScale, 0.5), 3.0)
                            }
                    )
                )
                .onTapGesture {
                    selectedOverlayId = (selectedOverlayId == item.wrappedValue.id) ? nil : item.wrappedValue.id
                }
        }
    }

    private func stickerGesture(item: Binding<VideoOverlayItem>, containerSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    let newX = min(max(value.location.x, 0), containerSize.width)
                    let newY = min(max(value.location.y, 0), containerSize.height)
                    item.wrappedValue.position = CGPoint(x: newX, y: newY)
                },
            MagnificationGesture()
                .onChanged { value in
                    let newScale = item.wrappedValue.scale * value
                    item.wrappedValue.scale = min(max(newScale, 0.3), 4.0)
                }
        )
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: InvlogTheme.Spacing.sm) {
            Spacer().frame(height: InvlogTheme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InvlogTheme.Spacing.sm) {
                    overlayActionButton(icon: "face.smiling", label: "Sticker") {
                        showStickerPicker = true
                    }

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
                Text("Add stickers, text, location, or mentions")
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

    private func addStickerOverlay(_ sticker: GiphySticker) {
        let center = CGPoint(x: previewSize.width / 2, y: previewSize.height / 2)
        let item = VideoOverlayItem(
            kind: .sticker(url: sticker.url, width: sticker.width, height: sticker.height),
            position: center,
            fontSize: .medium,
            color: .white,
            scale: 1.0
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
                Text(isPhotoMode ? "Applying stickers..." : "Burning overlays...")
                    .font(InvlogTheme.body(14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(InvlogTheme.Spacing.xl)
            .background(Color.brandText.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: InvlogTheme.Radius.md))
        }
    }

    // MARK: - Player Setup (Video only)

    private func setupPlayer() {
        guard let videoURL else { return }
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
        if isPhotoMode {
            handlePhotoExport()
        } else {
            handleVideoExport()
        }
    }

    private func handlePhotoExport() {
        guard let photoImage else { return }

        if overlays.isEmpty {
            onCompletePhoto?(photoImage)
            // Don't dismiss — parent (PhotoOverlayFlowView) manages dismissal
            return
        }

        isExporting = true
        let overlaysCopy = overlays
        let previewSizeCopy = previewSize

        Task.detached(priority: .userInitiated) {
            let result = await Self.compositePhotoOverlays(
                baseImage: photoImage,
                overlays: overlaysCopy,
                previewSize: previewSizeCopy
            )
            await MainActor.run {
                isExporting = false
                onCompletePhoto?(result)
                // Don't dismiss — parent manages dismissal
            }
        }
    }

    private func handleVideoExport() {
        guard let videoURL else { return }

        if overlays.isEmpty {
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
                let (exportedURL, exportedThumb) = try await exportVideoWithOverlays(
                    videoURL: videoURL,
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

    // MARK: - Photo Export (composite overlays onto image)

    private static func compositePhotoOverlays(
        baseImage: UIImage,
        overlays: [VideoOverlayItem],
        previewSize: CGSize
    ) async -> UIImage {
        let imageSize = baseImage.size
        let scaleX = imageSize.width / previewSize.width
        let scaleY = imageSize.height / previewSize.height

        // Prefetch sticker images
        var stickerImages: [URL: UIImage] = [:]
        for item in overlays {
            if case .sticker(let url, _, _) = item.kind {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    stickerImages[url] = img
                }
            }
        }

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            // Draw base image
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))

            for item in overlays {
                switch item.kind {
                case .sticker(let url, let w, let h):
                    guard let stickerImg = stickerImages[url] else { continue }
                    let aspectRatio = w / max(h, 1)
                    let baseWidth: CGFloat = 120 * item.scale
                    let stickerWidth = baseWidth * scaleX
                    let stickerHeight = stickerWidth / aspectRatio
                    let x = item.position.x * scaleX - stickerWidth / 2
                    let y = item.position.y * scaleY - stickerHeight / 2
                    stickerImg.draw(in: CGRect(x: x, y: y, width: stickerWidth, height: stickerHeight))

                case .text(let text), .location(let text), .mention(let text):
                    let displayText = item.kind.displayText
                    let fontSize = item.fontSize.pointSize * item.scale * scaleX
                    let font = UIFont.boldSystemFont(ofSize: fontSize)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: item.color.uiColor,
                        .shadow: {
                            let shadow = NSShadow()
                            shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
                            shadow.shadowOffset = CGSize(width: 1 * scaleX, height: 1 * scaleY)
                            shadow.shadowBlurRadius = 2 * scaleX
                            return shadow
                        }()
                    ]
                    let maxWidth = imageSize.width * 0.9
                    let textSize = (displayText as NSString).boundingRect(
                        with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attributes,
                        context: nil
                    ).size

                    let bgWidth = textSize.width + 20 * scaleX
                    let bgHeight = textSize.height + 12 * scaleY
                    let x = item.position.x * scaleX - bgWidth / 2
                    let y = item.position.y * scaleY - bgHeight / 2

                    // Draw background
                    let bgRect = CGRect(x: x, y: y, width: bgWidth, height: bgHeight)
                    let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 6 * scaleX)
                    UIColor.black.withAlphaComponent(0.3).setFill()
                    bgPath.fill()

                    // Draw text
                    let textRect = CGRect(
                        x: x + 10 * scaleX,
                        y: y + 6 * scaleY,
                        width: textSize.width,
                        height: textSize.height
                    )
                    (displayText as NSString).draw(in: textRect, withAttributes: attributes)
                }
            }
        }
    }

    // MARK: - Video Export (burn overlays into video)

    private func exportVideoWithOverlays(
        videoURL: URL,
        overlays: [VideoOverlayItem],
        previewSize: CGSize
    ) async throws -> (URL, UIImage) {
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

        // Prefetch sticker images for video burn
        var stickerCGImages: [URL: CGImage] = [:]
        for item in overlays {
            if case .sticker(let url, _, _) = item.kind {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data),
                   let cgImg = img.cgImage {
                    stickerCGImages[url] = cgImg
                }
            }
        }

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
            switch item.kind {
            case .sticker(let url, let w, let h):
                guard let cgImage = stickerCGImages[url] else { continue }
                let stickerLayer = CALayer()
                stickerLayer.contents = cgImage
                stickerLayer.contentsGravity = .resizeAspect

                let aspectRatio = w / max(h, 1)
                let baseWidth: CGFloat = 120 * item.scale
                let stickerWidth = baseWidth * scaleX
                let stickerHeight = stickerWidth / aspectRatio
                let x = item.position.x * scaleX - stickerWidth / 2
                // CA coordinates: y=0 is bottom
                let y = videoSize.height - (item.position.y * scaleY) - stickerHeight / 2

                stickerLayer.frame = CGRect(x: x, y: y, width: stickerWidth, height: stickerHeight)
                overlayLayer.addSublayer(stickerLayer)

            default:
                let scaledFontSize = item.fontSize.pointSize * item.scale * scaleX
                let textLayer = CATextLayer()
                textLayer.string = item.kind.displayText
                textLayer.font = UIFont.boldSystemFont(ofSize: scaledFontSize) as CFTypeRef
                textLayer.fontSize = scaledFontSize
                textLayer.foregroundColor = item.color.uiColor.cgColor
                textLayer.shadowColor = UIColor.black.cgColor
                textLayer.shadowOpacity = 0.6
                textLayer.shadowOffset = CGSize(width: 1 * scaleX, height: 1 * scaleY)
                textLayer.shadowRadius = 2 * scaleX
                textLayer.alignmentMode = .center
                textLayer.contentsScale = screenScale
                textLayer.isWrapped = true

                let maxWidth = videoSize.width * 0.9
                let textSize = (item.kind.displayText as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: UIFont.boldSystemFont(ofSize: scaledFontSize)],
                    context: nil
                ).size

                let layerWidth = min(textSize.width + 20 * scaleX, maxWidth)
                let layerHeight = textSize.height + 12 * scaleY
                let videoX = item.position.x * scaleX - layerWidth / 2
                let videoY = videoSize.height - (item.position.y * scaleY) - layerHeight / 2

                textLayer.frame = CGRect(x: videoX, y: videoY, width: layerWidth, height: layerHeight)
                textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.3).cgColor
                textLayer.cornerRadius = 6 * scaleX

                overlayLayer.addSublayer(textLayer)
            }
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

// Uses shared SimpleVideoPlayerView from Components/
