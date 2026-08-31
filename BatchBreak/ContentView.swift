//
//  ContentView.swift
//  BatchBreak
//
//  Created by Kanishka Madusanka on 2026-08-30.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import PDFKit
import QuickLook
import CoreImage

enum ViewMode {
    case grid
    case list
}

struct ContentView: View {
    @State private var photos: [PhotoItem] = []
    @State private var selectedPhotoIDs: Set<UUID> = []
    @State private var isTargeted: Bool = false
    @State private var isShowingFileImporter: Bool = false
    @State private var isShowingAboutSheet: Bool = false
    @State private var viewMode: ViewMode = .grid
    @State private var quality: Double = 0.60
    @State private var selectedOutputFormat: OutputFormat = .jpeg
    @State private var quickLookURL: URL? = nil
    
    // Keyboard Event Monitor State
    @State private var keyMonitor: Any? = nil
    
    // MARK: - Conversion & Summary State
    @State private var isConverting: Bool = false
    @State private var convertedCount: Int = 0
    @State private var totalConversionCount: Int = 0
    
    @State private var showSummaryToast: Bool = false
    @State private var lastConvertedCount: Int = 0
    @State private var lastSavedText: String = ""
    @State private var lastSavedPercentage: Int = 0
    @State private var isSizeIncreased: Bool = false
    @State private var isConversionCompleted: Bool = false
    @State private var lastDestinationFolder: URL? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Grid columns layout matching screenshot (4 adaptive columns)
    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 20)
    ]
    
    private var allowedContentTypes: [UTType] {
        var types: [UTType] = [.image, .pdf, .folder, .dng, .rawImage, .ico]
        if let icoType = UTType(filenameExtension: "ico") ?? UTType("com.microsoft.ico") ?? UTType("public.ico") {
            types.append(icoType)
        }
        if let curType = UTType(filenameExtension: "cur") ?? UTType("com.microsoft.cur") {
            types.append(curType)
        }
        if let jpsType = UTType(filenameExtension: "jps") ?? UTType("public.jps") {
            types.append(jpsType)
        }
        if let pictType = UTType(filenameExtension: "pict") ?? UTType("com.apple.pict") {
            types.append(pictType)
        }
        if let pctType = UTType(filenameExtension: "pct") {
            types.append(pctType)
        }
        if let picType = UTType(filenameExtension: "pic") {
            types.append(picType)
        }
        if let sgiType = UTType(filenameExtension: "sgi") ?? UTType("com.sgi.sgi-image") {
            types.append(sgiType)
        }
        if let rgbType = UTType(filenameExtension: "rgb") ?? UTType("com.sgi.rgb-image") {
            types.append(rgbType)
        }
        if let rgbaType = UTType(filenameExtension: "rgba") {
            types.append(rgbaType)
        }
        if let bwType = UTType(filenameExtension: "bw") {
            types.append(bwType)
        }
        if let intType = UTType(filenameExtension: "int") {
            types.append(intType)
        }
        if let intaType = UTType(filenameExtension: "inta") {
            types.append(intaType)
        }
        if let ppmType = UTType(filenameExtension: "ppm") ?? UTType("public.ppm") ?? UTType("public.pnm") {
            types.append(ppmType)
        }
        if let pnmType = UTType(filenameExtension: "pnm") {
            types.append(pnmType)
        }
        if let pgmType = UTType(filenameExtension: "pgm") {
            types.append(pgmType)
        }
        if let pbmType = UTType(filenameExtension: "pbm") {
            types.append(pbmType)
        }
        if let rw4Type = UTType(filenameExtension: "rw4") {
            types.append(rw4Type)
        }
        if let rw2Type = UTType(filenameExtension: "rw2") ?? UTType("com.panasonic.raw-image") {
            types.append(rw2Type)
        }
        if let rwlType = UTType(filenameExtension: "rwl") ?? UTType("com.leica.raw-image") {
            types.append(rwlType)
        }
        if let orfType = UTType(filenameExtension: "orf") ?? UTType("com.olympus.raw-image") ?? UTType("com.olympus.orf-raw-image") {
            types.append(orfType)
        }
        if let srfType = UTType(filenameExtension: "srf") ?? UTType("com.sony.raw-image") {
            types.append(srfType)
        }
        if let sr2Type = UTType(filenameExtension: "sr2") {
            types.append(sr2Type)
        }
        if let arwType = UTType(filenameExtension: "arw") {
            types.append(arwType)
        }
        if let nefType = UTType(filenameExtension: "nef") ?? UTType("com.nikon.nef-raw-image") ?? UTType("com.nikon.raw-image") {
            types.append(nefType)
        }
        if let nrwType = UTType(filenameExtension: "nrw") ?? UTType("com.nikon.nrw-raw-image") {
            types.append(nrwType)
        }
        if let jpeType = UTType(filenameExtension: "jpe") {
            types.append(jpeType)
        }
        if let jp2Type = UTType(filenameExtension: "jp2") ?? UTType("public.jpeg-2000") {
            types.append(jp2Type)
        }
        if let j2kType = UTType(filenameExtension: "j2k") {
            types.append(j2kType)
        }
        if let jpxType = UTType(filenameExtension: "jpx") {
            types.append(jpxType)
        }
        if let jpfType = UTType(filenameExtension: "jpf") {
            types.append(jpfType)
        }
        if let rafType = UTType(filenameExtension: "raf") ?? UTType("com.fuji.raw-image") {
            types.append(rafType)
        }
        if let rasType = UTType(filenameExtension: "ras") ?? UTType("public.sun-raster") {
            types.append(rasType)
        }
        if let sunType = UTType(filenameExtension: "sun") {
            types.append(sunType)
        }
        if let srType = UTType(filenameExtension: "sr") {
            types.append(srType)
        }
        if let pamType = UTType(filenameExtension: "pam") ?? UTType("public.pam") {
            types.append(pamType)
        }
        if let mngType = UTType(filenameExtension: "mng") ?? UTType("com.libpng.mng") ?? UTType("public.mng") {
            types.append(mngType)
        }
        if let cr3Type = UTType(filenameExtension: "cr3") ?? UTType("com.canon.cr3-raw-image") {
            types.append(cr3Type)
        }
        if let wbmpType = UTType(filenameExtension: "wbmp") ?? UTType("com.wap.wbmp") {
            types.append(wbmpType)
        }
        if let cr2Type = UTType(filenameExtension: "cr2") ?? UTType("com.canon.cr2-raw-image") {
            types.append(cr2Type)
        }
        if let dngExtType = UTType(filenameExtension: "dng") {
            types.append(dngExtType)
        }
        if let adobeRawType = UTType("com.adobe.raw-image") {
            types.append(adobeRawType)
        }
        if let psdType = UTType(filenameExtension: "psd") {
            types.append(psdType)
        }
        if let adobePsdType = UTType("com.adobe.photoshop-image") {
            types.append(adobePsdType)
        }
        return types
    }
    
    var body: some View {
        ZStack {
            // Native macOS window background extending under title bar
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
                .onTapGesture {
                    selectedPhotoIDs.removeAll()
                }
            
            if photos.isEmpty {
                // MARK: - Empty State View
                emptyStateView
            } else {
                // MARK: - Main Photo Gallery & Converter Layout
                VStack(spacing: 0) {
                    // Main Photo Grid/List Content Area with Floating Badges/Summary & Liquid Glass Header
                    ZStack(alignment: .top) {
                        ScrollView {
                            if viewMode == .grid {
                                LazyVGrid(columns: gridColumns, spacing: 20) {
                                    ForEach(photos) { item in
                                        PhotoCardView(
                                            item: item,
                                            format: selectedOutputFormat,
                                            quality: quality,
                                            isSelected: selectedPhotoIDs.contains(item.id),
                                            onSelect: { isCommandPressed in
                                                handleSelect(item: item, isCommandPressed: isCommandPressed)
                                            },
                                            onQuickLook: {
                                                quickLookURL = item.url
                                            },
                                            onDelete: {
                                                removePhotos([item])
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 80)
                                .padding(.bottom, 56)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(photos) { item in
                                        PhotoListRowView(
                                            item: item,
                                            format: selectedOutputFormat,
                                            quality: quality,
                                            isSelected: selectedPhotoIDs.contains(item.id),
                                            onSelect: { isCommandPressed in
                                                handleSelect(item: item, isCommandPressed: isCommandPressed)
                                            },
                                            onQuickLook: {
                                                quickLookURL = item.url
                                            },
                                            onDelete: {
                                                removePhotos([item])
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 80)
                                .padding(.bottom, 56)
                            }
                        }
                        .onTapGesture {
                            selectedPhotoIDs.removeAll()
                        }
                        
                        // Top Header Bar with Liquid Glass Background Material
                        topHeaderBar
                        
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
                        .frame(maxHeight: .infinity, alignment: .bottom)
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
        .quickLookPreview($quickLookURL, in: photos.map { $0.url })
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
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                addFiles(urls: urls)
            case .failure(let error):
                print("Error picking files: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $isShowingAboutSheet) {
            AboutView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAboutSheet)) { _ in
            isShowingAboutSheet = true
        }
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }
    
    // MARK: - Top Header Bar
    private var topHeaderBar: some View {
        ZStack {
            // Right Action Buttons
            HStack(alignment: .center) {
                Spacer()
                
                // Trash (Delete Selected), Add Files & Clear Buttons
                HStack(spacing: 10) {
                    // Circle-Shaped Delete Selected Trash Button (Left of Add Files)
                    Button(action: deleteSelectedPhotos) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedPhotoIDs.isEmpty || isConverting ? Color.secondary.opacity(0.4) : Color.red)
                            .padding(6)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(selectedPhotoIDs.isEmpty || isConverting)
                    .onHover { inside in
                        if inside && !selectedPhotoIDs.isEmpty && !isConverting {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
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
                            selectedPhotoIDs.removeAll()
                            showSummaryToast = false
                            isConversionCompleted = false
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
        .glassEffect(.regular, in: Rectangle())
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
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
                Text(lastConvertedCount == 1 ? "1 file converted" : "\(lastConvertedCount) files converted")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                if isSizeIncreased {
                    Text("Size increased by \(lastSavedText) (+\(lastSavedPercentage)%)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Saved \(lastSavedText) · \(lastSavedPercentage)% smaller")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
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
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Converting \(convertedCount) of \(totalConversionCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    ProgressView(value: Double(convertedCount), total: Double(max(totalConversionCount, 1)))
                        .progressViewStyle(.linear)
                        .frame(width: 110)
                    
                    Text("\(Int((Double(convertedCount) / Double(max(totalConversionCount, 1))) * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
        Text(photos.count == 1 ? "1 file" : "\(photos.count) files")
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSummaryToast = false
                            isConversionCompleted = false
                        }
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
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedOutputFormat = format
                                showSummaryToast = false
                                isConversionCompleted = false
                            }
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
                
                // Convert Button (Dimmed and unclickable when conversion completes; re-enables on format/quality change)
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
                .disabled(isConverting || photos.isEmpty || isConversionCompleted)
                .opacity(isConversionCompleted ? 0.55 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isConversionCompleted)
                .onHover { inside in
                    if inside && !isConverting && !photos.isEmpty && !isConversionCompleted {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
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
        VStack(spacing: 20) {
            Spacer()
            
            MinimalHeroVisual(isTargeted: isTargeted) {
                isShowingFileImporter = true
            }
            
            VStack(spacing: 6) {
                Text("Drop your files here")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Drag in images or folders to batch convert.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    isShowingFileImporter = true
                }) {
                    Text("Add Files...")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                Button(action: {
                    isShowingAboutSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .medium))
                        Text("About BatchBreak")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            
            Spacer()
        }
        .padding(36)
    }
    
    // MARK: - Keyboard Monitor
    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Keycode 49 = Space bar
            if event.keyCode == 49 {
                if !self.selectedPhotoIDs.isEmpty && self.quickLookURL == nil {
                    if let firstID = self.selectedPhotoIDs.first,
                       let photo = self.photos.first(where: { $0.id == firstID }) {
                        Task { @MainActor in
                            self.quickLookURL = photo.url
                        }
                        return nil // Handled, suppress system beep
                    }
                }
            }
            // Keycode 51 = Delete / Backspace, Keycode 117 = Forward Delete
            else if (event.keyCode == 51 || event.keyCode == 117) && event.modifierFlags.contains(.command) {
                if !self.selectedPhotoIDs.isEmpty {
                    Task { @MainActor in
                        self.deleteSelectedPhotos()
                    }
                    return nil // Handled, suppress system beep
                }
            }
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    // MARK: - Selection & Removal Logic
    private func handleSelect(item: PhotoItem, isCommandPressed: Bool) {
        if isCommandPressed {
            if selectedPhotoIDs.contains(item.id) {
                selectedPhotoIDs.remove(item.id)
            } else {
                selectedPhotoIDs.insert(item.id)
            }
        } else {
            selectedPhotoIDs = [item.id]
        }
    }
    
    private func deleteSelectedPhotos() {
        guard !selectedPhotoIDs.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showSummaryToast = false
            isConversionCompleted = false
            photos.removeAll(where: { selectedPhotoIDs.contains($0.id) })
            selectedPhotoIDs.removeAll()
        }
    }
    
    private func removePhotos(_ items: [PhotoItem]) {
        withAnimation(.easeInOut(duration: 0.2)) {
            showSummaryToast = false
            isConversionCompleted = false
            let idsToRemove = Set(items.map { $0.id }).union(selectedPhotoIDs.contains(where: { id in items.contains(where: { $0.id == id }) }) ? selectedPhotoIDs : Set(items.map { $0.id }))
            photos.removeAll(where: { idsToRemove.contains($0.id) })
            selectedPhotoIDs.subtract(idsToRemove)
        }
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
        withAnimation(.easeInOut(duration: 0.2)) {
            showSummaryToast = false
            isConversionCompleted = false
        }
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
        
        // Capture security-scoped bookmark
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
                    isConversionCompleted = false
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
                
                let outputBytes = await processConversion(
                    item: item,
                    destinationFolder: destinationFolder,
                    destinationBookmark: destinationBookmark,
                    destURL: destURL,
                    format: targetFormat,
                    quality: targetQuality
                )
                
                if outputBytes > 0 {
                    successfulConversions += 1
                    totalOut += outputBytes
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        convertedCount += 1
                    }
                }
            }
            
            let isIncreased = totalOut > totalOrig
            let diffBytes = abs(totalOrig - totalOut)
            let percentage = totalOrig > 0 ? Int(round((Double(diffBytes) / Double(totalOrig)) * 100.0)) : 0
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            let diffFormattedText = formatter.string(fromByteCount: diffBytes)
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isConverting = false
                    lastConvertedCount = successfulConversions
                    lastSavedText = diffFormattedText
                    lastSavedPercentage = percentage
                    isSizeIncreased = isIncreased
                    lastDestinationFolder = destinationFolder
                    showSummaryToast = true
                    isConversionCompleted = true
                }
            }
        }
    }
    
    private func getUniqueDestinationURL(in folder: URL, baseName: String, ext: String) -> URL {
        return Self.getUniqueDestinationURLStatic(in: folder, baseName: baseName, ext: ext)
    }
    
    nonisolated private static func getUniqueDestinationURLStatic(in folder: URL, baseName: String, ext: String) -> URL {
        var destination = folder.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1
        let fm = FileManager.default
        while fm.fileExists(atPath: destination.path) {
            destination = folder.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }
        return destination
    }
    
    nonisolated private static func renderPDFPageToCGImage(page: PDFPage, scale: CGFloat = 2.0) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width = max(Int(bounds.width * scale), 1)
        let height = max(Int(bounds.height * scale), 1)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        
        return context.makeImage()
    }
    
    nonisolated private static func decodeImage(from sourceURL: URL) -> CGImage? {
        let ext = sourceURL.pathExtension.lowercased()
        if (ext == "ico" || ext == "cur"),
           let inputData = try? Data(contentsOf: sourceURL),
           let icoCGImage = PhotoItem.decodeICO(data: inputData) {
            return icoCGImage
        }
        if ext == "wbmp",
           let inputData = try? Data(contentsOf: sourceURL),
           let wbmpCGImage = PhotoItem.decodeWBMP(data: inputData) {
            return wbmpCGImage
        }
        if ext == "mng",
           let inputData = try? Data(contentsOf: sourceURL),
           let mngCGImage = PhotoItem.decodeMNG(data: inputData) {
            return mngCGImage
        }
        if ext == "pam",
           let inputData = try? Data(contentsOf: sourceURL),
           let pamCGImage = PhotoItem.decodePAM(data: inputData) {
            return pamCGImage
        }
        if (ext == "ppm" || ext == "pnm" || ext == "pgm" || ext == "pbm"),
           let inputData = try? Data(contentsOf: sourceURL),
           let ppmCGImage = PhotoItem.decodePPM(data: inputData) {
            return ppmCGImage
        }
        if (ext == "sgi" || ext == "rgb" || ext == "rgba" || ext == "bw" || ext == "int" || ext == "inta"),
           let inputData = try? Data(contentsOf: sourceURL),
           let sgiCGImage = PhotoItem.decodeSGI(data: inputData) {
            return sgiCGImage
        }
        if (ext == "pict" || ext == "pct" || ext == "pic"),
           let inputData = try? Data(contentsOf: sourceURL),
           let pictCGImage = PhotoItem.decodePICT(data: inputData) {
            return pictCGImage
        }
        if (ext == "ras" || ext == "sun" || ext == "sr"),
           let inputData = try? Data(contentsOf: sourceURL),
           let rasCGImage = PhotoItem.decodeRAS(data: inputData) {
            return rasCGImage
        }
        
        let decodeOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            ("kCGImageSourcePrioritizeQuality" as CFString): true
        ]
        if let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, decodeOptions as CFDictionary) {
            var orientation: Int32 = 1
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
               let orientNum = properties[kCGImagePropertyOrientation] as? NSNumber {
                orientation = orientNum.int32Value
            }
            
            if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, decodeOptions as CFDictionary) {
                if orientation > 1 {
                    let ciImage = CIImage(cgImage: cgImage).oriented(forExifOrientation: orientation)
                    let ciContext = CIContext(options: nil)
                    if let orientedCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                        return orientedCGImage
                    }
                }
                return cgImage
            }
        }
        if let inputData = try? Data(contentsOf: sourceURL) {
            if let icoCGImage = PhotoItem.decodeICO(data: inputData) {
                return icoCGImage
            }
            if let wbmpCGImage = PhotoItem.decodeWBMP(data: inputData) {
                return wbmpCGImage
            }
            if let mngCGImage = PhotoItem.decodeMNG(data: inputData) {
                return mngCGImage
            }
            if let pamCGImage = PhotoItem.decodePAM(data: inputData) {
                return pamCGImage
            }
            if let ppmCGImage = PhotoItem.decodePPM(data: inputData) {
                return ppmCGImage
            }
            if let sgiCGImage = PhotoItem.decodeSGI(data: inputData) {
                return sgiCGImage
            }
            if let pictCGImage = PhotoItem.decodePICT(data: inputData) {
                return pictCGImage
            }
            if let rasCGImage = PhotoItem.decodeRAS(data: inputData) {
                return rasCGImage
            }
            if let imageSource = CGImageSourceCreateWithData(inputData as CFData, decodeOptions as CFDictionary) {
                var orientation: Int32 = 1
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                   let orientNum = properties[kCGImagePropertyOrientation] as? NSNumber {
                    orientation = orientNum.int32Value
                }
                
                if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, decodeOptions as CFDictionary) {
                    if orientation > 1 {
                        let ciImage = CIImage(cgImage: cgImage).oriented(forExifOrientation: orientation)
                        let ciContext = CIContext(options: nil)
                        if let orientedCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                            return orientedCGImage
                        }
                    }
                    return cgImage
                }
            }
            if let nsImage = NSImage(data: inputData) {
                var rect = CGRect(origin: .zero, size: nsImage.size)
                return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            }
        }
        return nil
    }
    
    nonisolated private static func writeImage(cgImage: CGImage, format: OutputFormat, quality: Double, to destURL: URL) -> Int64 {
        let uti = format.utiIdentifier
        let outputData = NSMutableData()
        if let destinationData = CGImageDestinationCreateWithData(outputData as CFMutableData, uti, 1, nil) {
            var options: [CFString: Any] = [:]
            if format == .jpeg || format == .heic {
                options[kCGImageDestinationLossyCompressionQuality] = quality
            }
            CGImageDestinationAddImage(destinationData, cgImage, options as CFDictionary)
            if CGImageDestinationFinalize(destinationData) {
                do {
                    let data = outputData as Data
                    try data.write(to: destURL)
                    return Int64(data.count)
                } catch {
                    print("BatchBreak Error writing output data to \(destURL.path): \(error)")
                }
            }
        }
        
        // Fallback via NSBitmapImageRep representation
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let fileData: Data?
        switch format {
        case .jpeg, .heic, .webp:
            fileData = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .png:
            fileData = rep.representation(using: .png, properties: [:])
        case .tiff:
            fileData = rep.representation(using: .tiff, properties: [:])
        case .pdf:
            fileData = nil
        }
        
        if let fileData = fileData {
            do {
                try fileData.write(to: destURL)
                return Int64(fileData.count)
            } catch {
                print("BatchBreak Fallback Error writing file to \(destURL.path): \(error)")
            }
        }
        return 0
    }
    
    private func processConversion(
        item: PhotoItem,
        destinationFolder: URL,
        destinationBookmark: Data?,
        destURL: URL,
        format: OutputFormat,
        quality: Double
    ) async -> Int64 {
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
            
            return item.withSecurityScopedAccess { () -> Int64 in
                let sourceURL = item.url
                let isInputPDF = item.fileExtension.lowercased() == "pdf"
                
                // CASE 1: Exporting to PDF format
                if format == .pdf {
                    if isInputPDF, let pdfDoc = PDFDocument(url: sourceURL) {
                        let pdfData = NSMutableData()
                        if let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                           let firstPage = pdfDoc.page(at: 0) {
                            var mediaBox = firstPage.bounds(for: .mediaBox)
                            if let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
                                for i in 0..<pdfDoc.pageCount {
                                    if let page = pdfDoc.page(at: i) {
                                        var pageMediaBox = page.bounds(for: .mediaBox)
                                        pdfContext.beginPDFPage([kCGPDFContextMediaBox as String: NSData(bytes: &pageMediaBox, length: MemoryLayout<CGRect>.size)] as CFDictionary)
                                        pdfContext.saveGState()
                                        page.draw(with: .mediaBox, to: pdfContext)
                                        pdfContext.restoreGState()
                                        pdfContext.endPDFPage()
                                    }
                                }
                                pdfContext.closePDF()
                                do {
                                    let data = pdfData as Data
                                    try data.write(to: destURL)
                                    return Int64(data.count)
                                } catch {
                                    print("BatchBreak Error writing PDF output to \(destURL.path): \(error)")
                                }
                            }
                        }
                    } else if let cgImage = Self.decodeImage(from: sourceURL) {
                        let pdfData = NSMutableData()
                        var mediaBox = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
                        if let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                           let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
                            pdfContext.beginPDFPage(nil)
                            pdfContext.draw(cgImage, in: mediaBox)
                            pdfContext.endPDFPage()
                            pdfContext.closePDF()
                            do {
                                let data = pdfData as Data
                                try data.write(to: destURL)
                                return Int64(data.count)
                            } catch {
                                print("BatchBreak Error writing PDF output to \(destURL.path): \(error)")
                            }
                        }
                    }
                    return 0
                }
                
                // CASE 2: Exporting to non-PDF Image format (JPEG, PNG, HEIC, WEBP, TIFF)
                if isInputPDF, let pdfDoc = PDFDocument(url: sourceURL) {
                    let pageCount = pdfDoc.pageCount
                    var totalBytesWritten: Int64 = 0
                    
                    for pageIndex in 0..<pageCount {
                        guard let page = pdfDoc.page(at: pageIndex),
                              let cgImage = Self.renderPDFPageToCGImage(page: page) else { continue }
                        
                        let targetURL: URL
                        if pageCount > 1 {
                            targetURL = Self.getUniqueDestinationURLStatic(
                                in: destinationFolder,
                                baseName: "\(item.name)_Page_\(pageIndex + 1)",
                                ext: format.extensionName
                            )
                        } else {
                            targetURL = destURL
                        }
                        
                        let bytes = Self.writeImage(cgImage: cgImage, format: format, quality: quality, to: targetURL)
                        totalBytesWritten += bytes
                    }
                    return totalBytesWritten
                } else {
                    guard let cgImage = Self.decodeImage(from: sourceURL) else {
                        print("BatchBreak Error: Failed to decode image from \(sourceURL.path)")
                        return 0
                    }
                    return Self.writeImage(cgImage: cgImage, format: format, quality: quality, to: destURL)
                }
            }
        }.value
    }
}

// MARK: - Minimal Hero Component for Empty State
struct MinimalHeroVisual: View {
    var isTargeted: Bool
    var onAddFilesTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            // Soft Ambient Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(colorScheme == .dark ? (isTargeted ? 0.35 : 0.18) : (isTargeted ? 0.25 : 0.10)),
                            Color.indigo.opacity(colorScheme == .dark ? (isTargeted ? 0.20 : 0.10) : (isTargeted ? 0.15 : 0.05)),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(isTargeted ? 1.3 : (isAnimating ? 1.05 : 0.95))
                .blur(radius: 18)

            // Minimal Glass Drop Zone Circle
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                (isTargeted ? Color.blue : Color.primary).opacity(isTargeted ? 0.6 : (isHovered ? 0.3 : 0.12)),
                                (isTargeted ? Color.cyan : Color.primary).opacity(isTargeted ? 0.4 : (isHovered ? 0.2 : 0.05))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isTargeted ? 2.5 : 1.5
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(isTargeted ? 1.1 : (isHovered ? 1.04 : 1.0))

                // Inner soft filled disc
                Circle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? (isTargeted ? 0.12 : 0.05) : (isTargeted ? 0.08 : 0.03)))
                    .frame(width: 130, height: 130)

                // Minimal Icon
                VStack(spacing: 8) {
                    Image(systemName: isTargeted ? "arrow.down.doc.fill" : "plus.viewfinder")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(
                            isTargeted
                                ? AnyShapeStyle(Color.blue)
                                : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [Color.primary.opacity(0.85), Color.primary.opacity(0.55)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .scaleEffect(isTargeted ? 1.15 : (isHovered ? 1.08 : 1.0))
                }
            }
            .contentShape(Circle())
            .onTapGesture {
                onAddFilesTap()
            }
            .onHover { inside in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHovered = inside
                }
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isTargeted)
        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)
        .frame(height: 180)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - List Row View Option
struct PhotoListRowView: View {
    let item: PhotoItem
    let format: OutputFormat
    let quality: Double
    let isSelected: Bool
    let onSelect: (Bool) -> Void
    let onQuickLook: () -> Void
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
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.blue)
                        .padding(4)
                        .allowsHitTesting(false)
                }
                
                Text(item.pageCount > 1 ? "\(item.fileExtension) · \(item.pageCount) pgs" : item.fileExtension)
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
                    .foregroundStyle(isSelected ? .blue : .primary)
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
        .background(isSelected ? Color.blue.opacity(0.12) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            let isCommand = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
            onSelect(isCommand)
        }
        .overlay(
            PhotoContextMenuOverlay(
                onRightClickSelect: {
                    if !isSelected {
                        onSelect(false)
                    }
                },
                onQuickLook: onQuickLook,
                onShowOriginal: showOriginal,
                onCopyImage: copyImage,
                onCopyFilePath: copyFilePath,
                onDelete: onDelete
            )
        )
        .onAppear {
            if loadedImage == nil {
                item.loadThumbnailAsync(targetSize: CGSize(width: 112, height: 112)) { img in
                    Task { @MainActor in
                        self.loadedImage = img
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func showOriginal() {
        item.withSecurityScopedAccess {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
    }
    
    private func copyFilePath() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
    }
    
    private func copyImage() {
        item.withSecurityScopedAccess {
            if let image = NSImage(contentsOf: item.url) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            } else if let thumbnail = loadedImage {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([thumbnail])
            }
        }
    }
}

#Preview {
    ContentView()
}
