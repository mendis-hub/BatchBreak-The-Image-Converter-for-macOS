//
//  PhotoItem.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-08-30.
//

import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import PDFKit

struct PhotoItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let fileExtension: String
    let fileSize: Int64
    let pageCount: Int
    let pixelWidth: Int?
    let pixelHeight: Int?
    var thumbnail: NSImage?
    let bookmarkData: Data?
    
    nonisolated init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        fileExtension: String,
        fileSize: Int64,
        pageCount: Int = 1,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        thumbnail: NSImage? = nil,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.pageCount = pageCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.thumbnail = thumbnail
        self.bookmarkData = bookmarkData
    }
    
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    nonisolated func estimatedOutputSize(format: OutputFormat, quality: Double) -> Int64 {
        let uppercasedExt = fileExtension.uppercased()
        
        // Direct match for lossless formats when input and output match
        if uppercasedExt == "PNG" && format == .png {
            return fileSize
        }
        if (uppercasedExt == "TIFF" || uppercasedExt == "TIF") && format == .tiff {
            return fileSize
        }
        if uppercasedExt == "PDF" && format == .pdf {
            return fileSize
        }
        
        let pixels: Double
        if let w = pixelWidth, let h = pixelHeight, w > 0, h > 0 {
            pixels = Double(w * h)
        } else {
            let isInputLossless = ["PNG", "TIFF", "TIF", "BMP", "PSD", "PDF", "DNG", "RAW", "CR2", "CR3", "RAF", "NRW", "NEF", "SRF", "SR2", "ARW", "ORF", "JP2", "J2K", "JPX", "JPF", "WBMP", "MNG", "PAM", "RAS", "SUN", "SR"].contains(uppercasedExt)
            let bytesPerPixelInput = isInputLossless ? 0.575 : 0.12
            pixels = max(1000.0, Double(fileSize) / bytesPerPixelInput)
        }
        
        let estimatedBytes: Double
        switch format {
        case .jpeg:
            let bpp = 0.03 + 0.38 * pow(quality, 1.7)
            estimatedBytes = pixels * bpp
        case .png:
            let bpp = 0.32 + 0.55 * pow(quality, 1.5)
            estimatedBytes = pixels * bpp
        case .heic:
            let bpp = 0.015 + 0.19 * pow(quality, 1.7)
            estimatedBytes = pixels * bpp
        case .webp:
            let bpp = 0.02 + 0.26 * pow(quality, 1.7)
            estimatedBytes = pixels * bpp
        case .tiff:
            let bpp = 1.5 + 2.0 * quality
            estimatedBytes = pixels * bpp
        case .pdf:
            let bpp = 0.35 + 0.50 * pow(quality, 1.5)
            estimatedBytes = pixels * bpp
        }
        
        let singlePageEstimate = max(1024, Int64(round(estimatedBytes)))
        if format == .pdf {
            return singlePageEstimate
        } else {
            return singlePageEstimate * Int64(max(pageCount, 1))
        }
    }
    
    nonisolated func formattedEstimatedSize(format: OutputFormat, quality: Double) -> String {
        let bytes = estimatedOutputSize(format: format, quality: quality)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    nonisolated func withSecurityScopedAccess<T>(_ action: () throws -> T) rethrows -> T {
        var isStale = false
        let rootURL = bookmarkData.flatMap { data in
            (try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale))
            ?? (try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale))
        }
        let accessingRoot = rootURL?.startAccessingSecurityScopedResource() ?? false
        let accessingSelf = url.startAccessingSecurityScopedResource()
        defer {
            if accessingSelf { url.stopAccessingSecurityScopedResource() }
            if accessingRoot { rootURL?.stopAccessingSecurityScopedResource() }
        }
        return try action()
    }
    
    // MARK: - Dedicated WBMP Decoder
    nonisolated static func decodeWBMP(data: Data) -> CGImage? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data)
        var index = 0
        
        // Header check: Type 0 (uncompressed B&W), FixHeader 0
        let type = bytes[index]; index += 1
        let fixHeader = bytes[index]; index += 1
        guard type == 0, fixHeader == 0 else { return nil }
        
        // Read uintvar width
        var width = 0
        while index < bytes.count {
            let b = bytes[index]; index += 1
            width = (width << 7) | Int(b & 0x7F)
            if (b & 0x80) == 0 { break }
        }
        
        // Read uintvar height
        var height = 0
        while index < bytes.count {
            let b = bytes[index]; index += 1
            height = (height << 7) | Int(b & 0x7F)
            if (b & 0x80) == 0 { break }
        }
        
        guard width > 0, height > 0 else { return nil }
        
        let bytesPerRow = (width + 7) / 8
        let expectedPixelBytes = bytesPerRow * height
        guard data.count - index >= expectedPixelBytes else { return nil }
        
        // Create RGBA8888 pixel buffer
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        var pixelOffset = 0
        
        for y in 0..<height {
            let rowStart = index + y * bytesPerRow
            for x in 0..<width {
                let byteIndex = rowStart + (x / 8)
                let bitIndex = 7 - (x % 8)
                let bit = (bytes[byteIndex] >> bitIndex) & 1
                let color: UInt8 = (bit == 1) ? 255 : 0
                
                rgba[pixelOffset] = color     // R
                rgba[pixelOffset + 1] = color // G
                rgba[pixelOffset + 2] = color // B
                rgba[pixelOffset + 3] = 255   // A
                pixelOffset += 4
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo,
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }
        
        return cgImage
    }
    
    // MARK: - Dedicated MNG Decoder & PNG Stream Extractor
    nonisolated static func decodeMNG(data: Data) -> CGImage? {
        guard data.count >= 20 else { return nil }
        let bytes = [UInt8](data)
        
        // MNG Signature check: 0x8A, 'M', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
        let mngSignature: [UInt8] = [0x8A, 0x4D, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard Array(bytes.prefix(8)) == mngSignature else { return nil }
        
        var pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        var offset = 8
        var foundIHDR = false
        var foundIEND = false
        
        let validPNGChunks: Set<String> = [
            "IHDR", "PLTE", "IDAT", "tRNS", "gAMA", "cHRM", "sRGB", "iCCP", "IEND", "bKGD", "pHYs", "tIME", "tEXt", "zTXt", "iTXt"
        ]
        
        while offset + 12 <= bytes.count {
            let length = Int(bytes[offset]) << 24 | Int(bytes[offset+1]) << 16 | Int(bytes[offset+2]) << 8 | Int(bytes[offset+3])
            guard length >= 0, offset + 12 + length <= bytes.count else { break }
            
            let typeSlice = bytes[offset+4..<offset+8]
            guard let typeStr = String(bytes: typeSlice, encoding: .ascii) else { break }
            
            let totalChunkSize = 12 + length
            
            if validPNGChunks.contains(typeStr) {
                if typeStr == "IHDR" { foundIHDR = true }
                pngData.append(data.subdata(in: offset..<offset + totalChunkSize))
                if typeStr == "IEND" {
                    foundIEND = true
                    break
                }
            }
            
            offset += totalChunkSize
            if typeStr == "MEND" { break }
        }
        
        if foundIHDR {
            if !foundIEND {
                let iendChunk: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82]
                pngData.append(contentsOf: iendChunk)
            }
            if let imageSource = CGImageSourceCreateWithData(pngData as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                return cgImage
            }
        }
        
        return nil
    }
    
    // MARK: - Dedicated PAM Decoder
    nonisolated static func decodePAM(data: Data) -> CGImage? {
        guard data.count >= 15 else { return nil }
        let bytes = [UInt8](data)
        
        // PAM must start with P7
        guard bytes.count >= 2, bytes[0] == 0x50, bytes[1] == 0x37 else { return nil }
        
        // Find ENDHDR token
        let endhdrBytes: [UInt8] = [0x45, 0x4E, 0x44, 0x48, 0x44, 0x52] // "ENDHDR"
        var endhdrIndex: Int? = nil
        for i in 0..<(bytes.count - 6) {
            if bytes[i..<i+6] == endhdrBytes[...] {
                endhdrIndex = i
                break
            }
        }
        guard let endhdrPos = endhdrIndex else { return nil }
        
        guard let headerString = String(bytes: bytes[0..<endhdrPos], encoding: .ascii) else { return nil }
        
        var width: Int? = nil
        var height: Int? = nil
        var depth: Int? = nil
        var maxval: Int? = nil
        
        let lines = headerString.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "P7" { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].uppercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "WIDTH": width = Int(value)
            case "HEIGHT": height = Int(value)
            case "DEPTH": depth = Int(value)
            case "MAXVAL": maxval = Int(value)
            default: break
            }
        }
        
        guard let w = width, let h = height, let d = depth, let m = maxval, w > 0, h > 0, d > 0, m > 0 else { return nil }
        
        var pixelDataOffset = endhdrPos + 6
        if pixelDataOffset < bytes.count && (bytes[pixelDataOffset] == 0x0D || bytes[pixelDataOffset] == 0x0A || bytes[pixelDataOffset] == 0x20) {
            if bytes[pixelDataOffset] == 0x0D && pixelDataOffset + 1 < bytes.count && bytes[pixelDataOffset + 1] == 0x0A {
                pixelDataOffset += 2
            } else {
                pixelDataOffset += 1
            }
        }
        
        let totalPixels = w * h
        let bytesPerSample = m > 255 ? 2 : 1
        let bytesPerPixel = d * bytesPerSample
        
        guard data.count - pixelDataOffset >= totalPixels * bytesPerPixel else { return nil }
        
        var rgba = [UInt8](repeating: 0, count: totalPixels * 4)
        var outIdx = 0
        var inIdx = pixelDataOffset
        
        let scale: (Int) -> UInt8 = { val in
            if m == 255 { return UInt8(clamping: val) }
            let clampedVal = min(max(val, 0), m)
            return UInt8(clamping: Int(round((Double(clampedVal) / Double(m)) * 255.0)))
        }
        
        let readSample: () -> Int = {
            if bytesPerSample == 1 {
                let v = Int(bytes[inIdx])
                inIdx += 1
                return v
            } else {
                let v = (Int(bytes[inIdx]) << 8) | Int(bytes[inIdx + 1])
                inIdx += 2
                return v
            }
        }
        
        for _ in 0..<totalPixels {
            if d == 1 {
                let v = scale(readSample())
                rgba[outIdx] = v
                rgba[outIdx + 1] = v
                rgba[outIdx + 2] = v
                rgba[outIdx + 3] = 255
            } else if d == 2 {
                let v = scale(readSample())
                let a = scale(readSample())
                rgba[outIdx] = v
                rgba[outIdx + 1] = v
                rgba[outIdx + 2] = v
                rgba[outIdx + 3] = a
            } else if d == 3 {
                let r = scale(readSample())
                let g = scale(readSample())
                let b = scale(readSample())
                rgba[outIdx] = r
                rgba[outIdx + 1] = g
                rgba[outIdx + 2] = b
                rgba[outIdx + 3] = 255
            } else {
                let r = scale(readSample())
                let g = scale(readSample())
                let b = scale(readSample())
                let a = scale(readSample())
                for _ in 4..<d {
                    _ = readSample()
                }
                rgba[outIdx] = r
                rgba[outIdx + 1] = g
                rgba[outIdx + 2] = b
                rgba[outIdx + 3] = a
            }
            outIdx += 4
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImage = CGImage(
                  width: w,
                  height: h,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: w * 4,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo,
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }
        
        return cgImage
    }
    
    // MARK: - Dedicated Sun Raster (.ras) Decoder
    nonisolated static func decodeRAS(data: Data) -> CGImage? {
        guard data.count >= 32 else { return nil }
        let bytes = [UInt8](data)
        
        let readUInt32: (Int) -> UInt32 = { off in
            return (UInt32(bytes[off]) << 24) | (UInt32(bytes[off+1]) << 16) | (UInt32(bytes[off+2]) << 8) | UInt32(bytes[off+3])
        }
        
        let magic = readUInt32(0)
        guard magic == 0x59A66A95 else { return nil }
        
        let width = Int(readUInt32(4))
        let height = Int(readUInt32(8))
        let depth = Int(readUInt32(12))
        let rasType = Int(readUInt32(20))
        let mapType = Int(readUInt32(24))
        let mapLength = Int(readUInt32(28))
        
        guard width > 0, height > 0, depth > 0 else { return nil }
        guard data.count >= 32 + mapLength else { return nil }
        
        var redMap: [UInt8] = []
        var greenMap: [UInt8] = []
        var blueMap: [UInt8] = []
        
        if mapType == 1, mapLength > 0 { // RMT_EQUAL_RGB
            let numEntries = mapLength / 3
            if numEntries > 0 {
                let mapStart = 32
                let rStart = mapStart
                let gStart = mapStart + numEntries
                let bStart = mapStart + 2 * numEntries
                if bStart + numEntries <= data.count {
                    redMap = Array(bytes[rStart..<rStart + numEntries])
                    greenMap = Array(bytes[gStart..<gStart + numEntries])
                    blueMap = Array(bytes[bStart..<bStart + numEntries])
                }
            }
        }
        
        let rawPixelOffset = 32 + mapLength
        var rawPixels: [UInt8] = []
        
        if rasType == 2 { // RT_BYTE_ENCODED (RLE)
            var inIdx = rawPixelOffset
            while inIdx < bytes.count {
                let byte = bytes[inIdx]; inIdx += 1
                if byte == 0x80 {
                    if inIdx < bytes.count {
                        let count = bytes[inIdx]; inIdx += 1
                        if count == 0 {
                            rawPixels.append(0x80)
                        } else {
                            if inIdx < bytes.count {
                                let val = bytes[inIdx]; inIdx += 1
                                rawPixels.append(contentsOf: Array(repeating: val, count: Int(count) + 1))
                            }
                        }
                    }
                } else {
                    rawPixels.append(byte)
                }
            }
        } else {
            rawPixels = Array(bytes[rawPixelOffset...])
        }
        
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        var outIdx = 0
        
        if depth == 1 {
            let rowBytes = ((width + 15) / 16) * 2
            guard rawPixels.count >= rowBytes * height else { return nil }
            for y in 0..<height {
                let rowOffset = y * rowBytes
                for x in 0..<width {
                    let byteIdx = rowOffset + (x / 8)
                    let bitIdx = 7 - (x % 8)
                    let bit = (rawPixels[byteIdx] >> bitIdx) & 1
                    let c: UInt8 = (bit == 0) ? 255 : 0
                    rgba[outIdx] = c
                    rgba[outIdx + 1] = c
                    rgba[outIdx + 2] = c
                    rgba[outIdx + 3] = 255
                    outIdx += 4
                }
            }
        } else if depth == 8 {
            let rowBytes = (width + 1) & ~1
            guard rawPixels.count >= rowBytes * height else { return nil }
            let hasPalette = !redMap.isEmpty && redMap.count == greenMap.count && redMap.count == blueMap.count
            for y in 0..<height {
                let rowOffset = y * rowBytes
                for x in 0..<width {
                    let index = Int(rawPixels[rowOffset + x])
                    if hasPalette, index < redMap.count {
                        rgba[outIdx] = redMap[index]
                        rgba[outIdx + 1] = greenMap[index]
                        rgba[outIdx + 2] = blueMap[index]
                    } else {
                        rgba[outIdx] = UInt8(index)
                        rgba[outIdx + 1] = UInt8(index)
                        rgba[outIdx + 2] = UInt8(index)
                    }
                    rgba[outIdx + 3] = 255
                    outIdx += 4
                }
            }
        } else if depth == 24 {
            let rowBytes = (width * 3 + 1) & ~1
            guard rawPixels.count >= rowBytes * height else { return nil }
            let isRGBOrder = (rasType == 3)
            for y in 0..<height {
                let rowOffset = y * rowBytes
                for x in 0..<width {
                    let pixelStart = rowOffset + (x * 3)
                    let c0 = rawPixels[pixelStart]
                    let c1 = rawPixels[pixelStart + 1]
                    let c2 = rawPixels[pixelStart + 2]
                    if isRGBOrder {
                        rgba[outIdx] = c0
                        rgba[outIdx + 1] = c1
                        rgba[outIdx + 2] = c2
                    } else {
                        rgba[outIdx] = c2     // R
                        rgba[outIdx + 1] = c1 // G
                        rgba[outIdx + 2] = c0 // B
                    }
                    rgba[outIdx + 3] = 255
                    outIdx += 4
                }
            }
        } else if depth == 32 {
            let rowBytes = width * 4
            guard rawPixels.count >= rowBytes * height else { return nil }
            for y in 0..<height {
                let rowOffset = y * rowBytes
                for x in 0..<width {
                    let pixelStart = rowOffset + (x * 4)
                    let b = rawPixels[pixelStart + 1]
                    let g = rawPixels[pixelStart + 2]
                    let r = rawPixels[pixelStart + 3]
                    rgba[outIdx] = r
                    rgba[outIdx + 1] = g
                    rgba[outIdx + 2] = b
                    rgba[outIdx + 3] = 255
                    outIdx += 4
                }
            }
        } else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo,
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }
        
        return cgImage
    }
    
    nonisolated static func from(url: URL, bookmarkData: Data? = nil) -> PhotoItem {
        var isStale = false
        let rootURL = bookmarkData.flatMap { data in
            (try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale))
            ?? (try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale))
        }
        let accessingRoot = rootURL?.startAccessingSecurityScopedResource() ?? false
        let accessingSelf = url.startAccessingSecurityScopedResource()
        defer {
            if accessingSelf { url.stopAccessingSecurityScopedResource() }
            if accessingRoot { rootURL?.stopAccessingSecurityScopedResource() }
        }
        
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.uppercased()
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        
        var width: Int? = nil
        var height: Int? = nil
        var pageCount = 1
        
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            var rawW: Int? = nil
            var rawH: Int? = nil
            if let w = properties[kCGImagePropertyPixelWidth] {
                rawW = (w as? NSNumber)?.intValue ?? (w as? Int)
            }
            if let h = properties[kCGImagePropertyPixelHeight] {
                rawH = (h as? NSNumber)?.intValue ?? (h as? Int)
            }
            let orient = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
            if orient >= 5 && orient <= 8 {
                width = rawH
                height = rawW
            } else {
                width = rawW
                height = rawH
            }
        }
        
        if ext == "WBMP" || ext == "MNG" || ext == "PAM" || ext == "RAS" || ext == "SUN" || ext == "SR" || (width == nil || height == nil) {
            if let data = try? Data(contentsOf: url) {
                if let wbmpCGImage = decodeWBMP(data: data) {
                    width = wbmpCGImage.width
                    height = wbmpCGImage.height
                } else if let mngCGImage = decodeMNG(data: data) {
                    width = mngCGImage.width
                    height = mngCGImage.height
                } else if let pamCGImage = decodePAM(data: data) {
                    width = pamCGImage.width
                    height = pamCGImage.height
                } else if let rasCGImage = decodeRAS(data: data) {
                    width = rasCGImage.width
                    height = rasCGImage.height
                }
            }
        }
        
        if ext == "PDF" {
            if let pdfDoc = PDFDocument(url: url) {
                pageCount = max(pdfDoc.pageCount, 1)
                if let page = pdfDoc.page(at: 0) {
                    let bounds = page.bounds(for: .mediaBox)
                    width = Int(bounds.width * 2.0)
                    height = Int(bounds.height * 2.0)
                }
            }
        }
        
        return PhotoItem(
            url: url,
            name: name.isEmpty ? "Photo" : name,
            fileExtension: ext.isEmpty ? "IMG" : ext,
            fileSize: size,
            pageCount: pageCount,
            pixelWidth: width,
            pixelHeight: height,
            bookmarkData: bookmarkData
        )
    }
    
    nonisolated static func scanForImages(in url: URL) -> [URL] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    return []
                }
                var imageURLs: [URL] = []
                let validExtensions = ["jpg", "jpeg", "jpe", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif", "pdf", "psd", "dng", "raw", "cr2", "cr3", "raf", "nrw", "nef", "srf", "sr2", "arw", "orf", "jp2", "j2k", "jpx", "jpf", "wbmp", "mng", "pam", "ras", "sun", "sr"]
                for case let fileURL as URL in enumerator {
                    if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                        imageURLs.append(fileURL)
                    }
                }
                return imageURLs
            } else {
                let validExtensions = ["jpg", "jpeg", "jpe", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif", "pdf", "psd", "dng", "raw", "cr2", "cr3", "raf", "nrw", "nef", "srf", "sr2", "arw", "orf", "jp2", "j2k", "jpx", "jpf", "wbmp", "mng", "pam", "ras", "sun", "sr"]
                if validExtensions.contains(url.pathExtension.lowercased()) {
                    return [url]
                }
            }
        }
        return []
    }
    
    nonisolated func loadThumbnailAsync(targetSize: CGSize = CGSize(width: 320, height: 320), completion: @escaping @Sendable (NSImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = self.withSecurityScopedAccess { () -> NSImage? in
                let extLower = self.fileExtension.lowercased()
                if extLower == "pdf" {
                    if let pdfDoc = PDFDocument(url: self.url), let page = pdfDoc.page(at: 0) {
                        return page.thumbnail(of: targetSize, for: .mediaBox)
                    }
                }
                if extLower == "wbmp" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodeWBMP(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if extLower == "mng" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodeMNG(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if extLower == "pam" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodePAM(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if extLower == "ras" || extLower == "sun" || extLower == "sr" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodeRAS(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if let imageSource = CGImageSourceCreateWithURL(self.url as CFURL, nil) {
                    let maxPixelSize = max(targetSize.width, targetSize.height) * 2
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
                    ]
                    if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if let data = try? Data(contentsOf: self.url) {
                    if let cgImage = PhotoItem.decodeWBMP(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                    if let cgImage = PhotoItem.decodeMNG(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                    if let cgImage = PhotoItem.decodePAM(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                    if let cgImage = PhotoItem.decodeRAS(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                return NSImage(contentsOf: self.url)
            }
            DispatchQueue.main.async { completion(img) }
        }
    }
}

enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    case webp = "WEBP"
    case tiff = "TIFF"
    case pdf = "PDF"
    
    nonisolated var id: String { rawValue }
    
    nonisolated var extensionName: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .webp: return "webp"
        case .tiff: return "tiff"
        case .pdf: return "pdf"
        }
    }
    
    nonisolated var utiIdentifier: CFString {
        switch self {
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .png: return UTType.png.identifier as CFString
        case .heic: return UTType.heic.identifier as CFString
        case .webp:
            if let webpType = UTType("org.webmproject.webp") ?? UTType(filenameExtension: "webp") {
                return webpType.identifier as CFString
            }
            return "org.webmproject.webp" as CFString
        case .tiff: return UTType.tiff.identifier as CFString
        case .pdf: return UTType.pdf.identifier as CFString
        }
    }
}
