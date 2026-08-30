//
//  ContentView.swift
//  BatchBreak
//
//  Created by Kanishka Madusanka on 2026-08-30.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum ViewMode {
    case grid
    case list
}

struct ContentView: View {
    @State private var photos: [PhotoItem] = []
    @State private var isTargeted: Bool = false
    @State private var isShowingFileImporter: Bool = false
    @State private var viewMode: ViewMode = .grid
    @State private var quality: Double = 0.60
    @State private var selectedOutputFormat: OutputFormat = .jpeg
    
    // MARK: - Conversion & Summary State
    @State private var isConverting: Bool = false
    @State private var convertedCount: Int = 0
    @State private var totalConversionCount: Int = 0
    
    @State private var showSummaryToast: Bool = false
    @State private var lastConvertedCount: Int = 0
    @State private var lastSavedText: String = ""
    @State private var lastSavedPercentage: Int = 0
    @State private var lastDestinationFolder: URL? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Grid columns layout matching screenshot (4 adaptive columns)
    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            // Native macOS window background extending under title bar
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            if photos.isEmpty {
                // MARK: - Empty State View
                emptyStateView
            } else {
                // MARK: - Main Photo Gallery & Converter Layout
                VStack(spacing: 0) {
                    // Top Header Bar
                    topHeaderBar
                    
                    // Main Photo Grid/List Content Area with Floating Badges/Summary
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            if viewMode == .grid {
                                LazyVGrid(columns: gridColumns, spacing: 20) {
                                    ForEach(photos) { item in
                                        PhotoCardView(
                                            item: item,
                                            format: selectedOutputFormat,
                                            quality: quality
                                        ) {
                                            removePhoto(item)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                                .padding(.bottom, 56)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(photos) { item in
                                        PhotoListRowView(
                                            item: item,
                                            format: selectedOutputFormat,
                                            quality: quality
                                        ) {
                                            removePhoto(item)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                                .padding(.bottom, 56)
                            }
                        }
                        
                        // MARK: - Bottom Floating Overlay (Summary Toast / Progress Bar / Photo Count Badge)
                        Group {
                            if isConverting {
                                conversionProgressToast
                            } else if showSummaryToast {
                                floatingSummaryToast
                            } else {
                                floatingPhotoCountBadge
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isConverting)
                        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: showSummaryToast)
                    }
                    
                    // Bottom Conversion Control Bar
                    bottomControlBar
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .ignoresSafeArea()
        .dropDestination(for: URL.self) { items, _ in
            addFiles(urls: items)
            return true
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                isTargeted = targeted
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.image, .folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                addFiles(urls: urls)
            case .failure(let error):
                print("Error picking files: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Top Header Bar
    private var topHeaderBar: some View {
        ZStack {
            // Right Action Buttons
            HStack(alignment: .center) {
                Spacer()
                
                // Add Files & Clear Buttons
                HStack(spacing: 10) {
                    Button(action: {
                        isShowingFileImporter = true
                    }) {
                        Text("Add Files...")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .disabled(isConverting)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            photos.removeAll()
                            showSummaryToast = false
                        }
                    }) {
                        Text("Clear")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .disabled(isConverting)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            
            // Perfectly Centered View Mode Switcher [ Grid | List ]
            HStack(spacing: 2) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewMode = .grid
                    }
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(viewMode == .grid ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewMode == .grid ? Color.primary.opacity(0.12) : Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 12)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewMode = .list
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(viewMode == .list ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewMode == .list ? Color.primary.opacity(0.12) : Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
    }
    
    // MARK: - Floating Summary Toast (Matching Screenshot with Liquid Glass Material)
    private var floatingSummaryToast: some View {
        HStack(spacing: 12) {
            // Checkmark Circle Icon
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(red: 0.18, green: 0.68, blue: 0.42))
            
            // Text Summary Stack
            VStack(alignment: .leading, spacing: 1) {
                Text("\(lastConvertedCount) photos converted")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Saved \(lastSavedText) · \(lastSavedPercentage)% smaller")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 6)
            
            // "Show in Finder" Button
            Button(action: revealInFinder) {
                Text("Show in Finder")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            // Dismiss button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSummaryToast = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: Capsule())
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 4)
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
        )
        .padding(.bottom, 12)
    }
    
    // MARK: - Conversion Progress Toast
    private var conversionProgressToast: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Converting \(convertedCount) of \(totalConversionCount) photos...")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                ProgressView(value: Double(convertedCount), total: Double(max(totalConversionCount, 1)))
                    .progressViewStyle(.linear)
                    .frame(width: 140)
            }
            
            Text("\(Int((Double(convertedCount) / Double(max(totalConversionCount, 1))) * 100))%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 4)
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
        )
        .padding(.bottom, 12)
    }
    
    // MARK: - Floating Photo Count Badge
    private var floatingPhotoCountBadge: some View {
        Text("\(photos.count) photos")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule())
            .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
            )
            .padding(.bottom, 12)
    }
    
    // MARK: - Bottom Control Bar
    private var bottomControlBar: some View {
        HStack(alignment: .center, spacing: 16) {
            // Left Side: Quality Label + Slider + Percentage + Size Estimate
            HStack(spacing: 12) {
                Text("Quality")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                
                QualitySlider(value: $quality)
                    .onChange(of: quality) { _, _ in
                        showSummaryToast = false
                    }
                
                Text("\(Int(quality * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text("≈ \(formattedEstimatedTotalSize)")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            
            Spacer()
            
            // Right Side: Format Selector Menu + Convert Button
            HStack(spacing: 12) {
                // Format Selector Menu
                Menu {
                    ForEach(OutputFormat.allCases) { format in
                        Button(action: {
                            selectedOutputFormat = format
                            showSummaryToast = false
                        }) {
                            if selectedOutputFormat == format {
                                Label(format.rawValue, systemImage: "checkmark")
                            } else {
                                Text(format.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(selectedOutputFormat.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .menuStyle(.borderlessButton)
                .disabled(isConverting)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                // Convert Button matching top glass capsule buttons
                Button(action: convertPhotos) {
                    HStack(spacing: 6) {
                        if isConverting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Convert")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .disabled(isConverting || photos.isEmpty)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            HeaderCardStack(isTargeted: isTargeted)
                .padding(.bottom, 12)
            
            VStack(spacing: 8) {
                Text("Drop your photos")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Drag in photos or a whole folder, then convert them.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            
            Button(action: {
                isShowingFileImporter = true
            }) {
                Text("Add Files...")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            Spacer()
        }
        .padding(36)
    }
    
    // MARK: - Helpers & Calculation
    private var totalOriginalBytes: Int64 {
        photos.reduce(0) { $0 + $1.fileSize }
    }
    
    private var formattedEstimatedTotalSize: String {
        guard !photos.isEmpty else { return "0 MB" }
        let estimatedBytes = photos.reduce(0) { $0 + $1.estimatedOutputSize(format: selectedOutputFormat, quality: quality) }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedBytes)
    }
    
    private func addFiles(urls: [URL]) {
        showSummaryToast = false
        var newPhotos: [PhotoItem] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            let bookmarkData = (try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil))
                ?? (try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil))
            
            let scanned = PhotoItem.scanForImages(in: url)
            for fileURL in scanned {
                if !photos.contains(where: { $0.url == fileURL }) {
                    newPhotos.append(PhotoItem.from(url: fileURL, bookmarkData: bookmarkData))
                }
            }
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            photos.append(contentsOf: newPhotos)
        }
    }
    
    private func removePhoto(_ item: PhotoItem) {
        showSummaryToast = false
        withAnimation(.easeInOut(duration: 0.2)) {
            photos.removeAll(where: { $0.id == item.id })
        }
    }
    
    private func revealInFinder() {
        guard let folder = lastDestinationFolder else { return }
        NSWorkspace.shared.open(folder)
    }
    
    // MARK: - Convert Logic
    private func convertPhotos() {
        guard !photos.isEmpty else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Output Directory"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.prompt = "Select Folder"
        
        let response = openPanel.runModal()
        guard response == .OK, let destinationFolder = openPanel.url else { return }
        
        // Immediately capture security-scoped bookmark on main thread right after NSOpenPanel returns
        let destinationBookmark = (try? destinationFolder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil))
            ?? (try? destinationFolder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil))
        
        let photosToConvert = photos
        let targetFormat = selectedOutputFormat
        let targetQuality = quality
        
        Task {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConverting = true
                    convertedCount = 0
                    totalConversionCount = photosToConvert.count
                    showSummaryToast = false
                }
            }
            
            var totalOrig: Int64 = 0
            var totalOut: Int64 = 0
            var successfulConversions = 0
            
            for item in photosToConvert {
                totalOrig += item.fileSize
                
                let destURL = getUniqueDestinationURL(
                    in: destinationFolder,
                    baseName: item.name,
                    ext: targetFormat.extensionName
                )
                
                let success = await processConversion(
                    item: item,
                    destinationFolder: destinationFolder,
                    destinationBookmark: destinationBookmark,
                    destURL: destURL,
                    format: targetFormat,
                    quality: targetQuality
                )
                
                if success {
                    successfulConversions += 1
                    let outSize = (try? destURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }
                    totalOut += outSize ?? item.estimatedOutputSize(format: targetFormat, quality: targetQuality)
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        convertedCount += 1
                    }
                }
            }
            
            let saved = max(0, totalOrig - totalOut)
            let percentage = totalOrig > 0 ? Int(round((Double(saved) / Double(totalOrig)) * 100.0)) : 0
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            let savedFormattedText = formatter.string(fromByteCount: saved)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isConverting = false
                    lastConvertedCount = successfulConversions
                    lastSavedText = savedFormattedText
                    lastSavedPercentage = percentage
                    lastDestinationFolder = destinationFolder
                    showSummaryToast = true
                }
            }
        }
    }
    
    private func getUniqueDestinationURL(in folder: URL, baseName: String, ext: String) -> URL {
        var destination = folder.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1
        let fm = FileManager.default
        while fm.fileExists(atPath: destination.path) {
            destination = folder.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }
        return destination
    }
    
    private func processConversion(
        item: PhotoItem,
        destinationFolder: URL,
        destinationBookmark: Data?,
        destURL: URL,
        format: OutputFormat,
        quality: Double
    ) async -> Bool {
        return await Task.detached(priority: .userInitiated) {
            var isStale = false
            let resolvedFolder = destinationBookmark.flatMap { data in
                (try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale))
                ?? (try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale))
            } ?? destinationFolder
            
            let accessingFolder = resolvedFolder.startAccessingSecurityScopedResource()
            let accessingDest = destinationFolder.startAccessingSecurityScopedResource()
            defer {
                if accessingDest {
                    destinationFolder.stopAccessingSecurityScopedResource()
                }
                if accessingFolder {
                    resolvedFolder.stopAccessingSecurityScopedResource()
                }
            }
            
            return item.withSecurityScopedAccess { () -> Bool in
                let sourceURL = item.url
                
                // 1. Read / Decode CGImage
                var cgImage: CGImage? = nil
                if let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) {
                    cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
                }
                
                if cgImage == nil, let inputData = try? Data(contentsOf: sourceURL) {
                    if let imageSource = CGImageSourceCreateWithData(inputData as CFData, nil) {
                        cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
                    }
                    if cgImage == nil, let nsImage = NSImage(data: inputData) {
                        var rect = CGRect(origin: .zero, size: nsImage.size)
                        cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
                    }
                }
                
                guard let finalCGImage = cgImage else {
                    print("BatchBreak Error: Failed to decode image from \(sourceURL.path)")
                    return false
                }
                
                // 2. Encode to Data using CGImageDestinationCreateWithData (avoids ImageIO .sb-xxxx temp file sandbox errors)
                let uti = format.utiIdentifier
                let outputData = NSMutableData()
                if let destinationData = CGImageDestinationCreateWithData(outputData as CFMutableData, uti, 1, nil) {
                    var options: [CFString: Any] = [:]
                    if format == .jpeg || format == .heic {
                        options[kCGImageDestinationLossyCompressionQuality] = quality
                    }
                    CGImageDestinationAddImage(destinationData, finalCGImage, options as CFDictionary)
                    if CGImageDestinationFinalize(destinationData) {
                        do {
                            try (outputData as Data).write(to: destURL)
                            return true
                        } catch {
                            print("BatchBreak Error writing output data to \(destURL.path): \(error)")
                        }
                    }
                }
                
                // 3. Fallback via NSBitmapImageRep representation to Data, then Data.write
                let rep = NSBitmapImageRep(cgImage: finalCGImage)
                let fileData: Data?
                switch format {
                case .jpeg, .heic, .webp:
                    fileData = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
                case .png:
                    fileData = rep.representation(using: .png, properties: [:])
                case .tiff:
                    fileData = rep.representation(using: .tiff, properties: [:])
                }
                
                if let fileData = fileData {
                    do {
                        try fileData.write(to: destURL)
                        return true
                    } catch {
                        print("BatchBreak Fallback Error writing file to \(destURL.path): \(error)")
                        return false
                    }
                }
                
                return false
            }
        }.value
    }
}

// MARK: - Card Stack Visual Component for Empty State
struct HeaderCardStack: View {
    var isTargeted: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Card 1 (Back left - Mint / Teal gradient)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.68, green: 0.88, blue: 0.84),
                            Color(red: 0.82, green: 0.94, blue: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .frame(width: 120, height: 152)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 12, x: -4, y: 8)
                .rotationEffect(.degrees(isTargeted ? -22 : -15))
                .offset(x: isTargeted ? -42 : -30, y: isTargeted ? -14 : -8)
            
            // Card 2 (Middle - Lavender / Purple gradient)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.80, green: 0.78, blue: 0.98),
                            Color(red: 0.90, green: 0.86, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .frame(width: 120, height: 152)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 14, x: -1, y: 9)
                .rotationEffect(.degrees(isTargeted ? -9 : -5))
                .offset(x: isTargeted ? -16 : -10, y: isTargeted ? -7 : -3)
            
            // Card 3 (Front right - Warm Peach / Amber gradient)
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.82, blue: 0.64),
                                Color(red: 0.98, green: 0.90, blue: 0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.65), lineWidth: 1.2)
                    )
                
                // Icon specified by user in the middle of the app
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.linearGradient(
                        colors: [Color.primary.opacity(0.75), Color.primary.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
            .frame(width: 124, height: 156)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 18, x: 5, y: 12)
            .rotationEffect(.degrees(isTargeted ? 14 : 7))
            .offset(x: isTargeted ? 20 : 12, y: isTargeted ? -4 : 2)
        }
        .scaleEffect(isTargeted ? 1.06 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: isTargeted)
        .frame(height: 210)
    }
}

// MARK: - List Row View Option
struct PhotoListRowView: View {
    let item: PhotoItem
    let format: OutputFormat
    let quality: Double
    let onDelete: () -> Void
    
    @State private var loadedImage: NSImage? = nil
    @State private var isButtonHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .frame(width: 56, height: 56)
                    .overlay(
                        Group {
                            if let loadedImage = loadedImage {
                                Image(nsImage: loadedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.05))
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Text(item.fileExtension)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.9)))
                    .padding(3)
                    .allowsHitTesting(false)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Text(item.formattedSize)
                        .foregroundStyle(.secondary)
                    Text("→")
                        .foregroundStyle(.tertiary)
                    Text(item.formattedEstimatedSize(format: format, quality: quality))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .regular, design: .rounded))
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isButtonHovering ? Color.red : Color.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .onHover { inside in
                isButtonHovering = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            if loadedImage == nil {
                item.loadThumbnailAsync(targetSize: CGSize(width: 112, height: 112)) { img in
                    self.loadedImage = img
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
