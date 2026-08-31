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
import AppKit

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
            let isInputLossless = [
                "PNG", "TIFF", "TIF", "BMP", "PSD", "PDF", "DNG", "RAW", "CR2", "CR3", "RAF", "NRW",
                "NEF", "SRF", "SR2", "ARW", "ORF", "JP2", "J2K", "JPX", "JPF", "WBMP", "MNG", "PAM",
                "RAS", "SUN", "SR", "RW4", "RW2", "RWL", "PPM", "PNM", "PGM", "PBM", "PICT", "PCT",
                "PIC", "SGI", "RGB", "RGBA", "BW", "INT", "INTA", "ICO", "CUR"
            ].contains(uppercasedExt)
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
    
    // MARK: - Dedicated PPM / PNM Decoder (P1, P2, P3, P4, P5, P6)
    nonisolated static func decodePPM(data: Data) -> CGImage? {
        guard data.count >= 8 else { return nil }
        let bytes = [UInt8](data)
        var index = 0
        
        func skipWhitespaceAndComments() {
            while index < bytes.count {
                let b = bytes[index]
                if b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D {
                    index += 1
                } else if b == 0x23 { // '#' comment
                    while index < bytes.count && bytes[index] != 0x0A && bytes[index] != 0x0D {
                        index += 1
                    }
                } else {
                    break
                }
            }
        }
        
        func readToken() -> String? {
            skipWhitespaceAndComments()
            guard index < bytes.count else { return nil }
            let start = index
            while index < bytes.count {
                let b = bytes[index]
                if b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D || b == 0x23 {
                    break
                }
                index += 1
            }
            guard index > start else { return nil }
            return String(bytes: bytes[start..<index], encoding: .ascii)
        }
        
        guard let magic = readToken() else { return nil }
        guard magic == "P6" || magic == "P3" || magic == "P5" || magic == "P2" || magic == "P4" || magic == "P1" else { return nil }
        
        guard let widthStr = readToken(), let width = Int(widthStr), width > 0 else { return nil }
        guard let heightStr = readToken(), let height = Int(heightStr), height > 0 else { return nil }
        
        var maxval = 255
        if magic != "P1" && magic != "P4" {
            guard let maxvalStr = readToken(), let m = Int(maxvalStr), m > 0 else { return nil }
            maxval = m
        }
        
        let totalPixels = width * height
        var rgba = [UInt8](repeating: 0, count: totalPixels * 4)
        var outIdx = 0
        
        let scale: (Int) -> UInt8 = { val in
            if maxval == 255 { return UInt8(clamping: val) }
            let clampedVal = min(max(val, 0), maxval)
            return UInt8(clamping: Int(round((Double(clampedVal) / Double(maxval)) * 255.0)))
        }
        
        if magic == "P6" { // PPM binary RGB
            if index < bytes.count {
                let b = bytes[index]
                if b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D {
                    index += 1
                    if b == 0x0D && index < bytes.count && bytes[index] == 0x0A {
                        index += 1
                    }
                }
            }
            
            let bytesPerSample = maxval > 255 ? 2 : 1
            let bytesPerPixel = 3 * bytesPerSample
            guard data.count - index >= totalPixels * bytesPerPixel else { return nil }
            
            var inIdx = index
            for _ in 0..<totalPixels {
                let r: UInt8
                let g: UInt8
                let b: UInt8
                if bytesPerSample == 1 {
                    r = scale(Int(bytes[inIdx]))
                    g = scale(Int(bytes[inIdx + 1]))
                    b = scale(Int(bytes[inIdx + 2]))
                    inIdx += 3
                } else {
                    let rVal = (Int(bytes[inIdx]) << 8) | Int(bytes[inIdx + 1])
                    let gVal = (Int(bytes[inIdx + 2]) << 8) | Int(bytes[inIdx + 3])
                    let bVal = (Int(bytes[inIdx + 4]) << 8) | Int(bytes[inIdx + 5])
                    r = scale(rVal)
                    g = scale(gVal)
                    b = scale(bVal)
                    inIdx += 6
                }
                rgba[outIdx] = r
                rgba[outIdx + 1] = g
                rgba[outIdx + 2] = b
                rgba[outIdx + 3] = 255
                outIdx += 4
            }
        } else if magic == "P3" { // PPM ASCII RGB
            for _ in 0..<totalPixels {
                guard let rStr = readToken(), let rVal = Int(rStr),
                      let gStr = readToken(), let gVal = Int(gStr),
                      let bStr = readToken(), let bVal = Int(bStr) else {
                    return nil
                }
                rgba[outIdx] = scale(rVal)
                rgba[outIdx + 1] = scale(gVal)
                rgba[outIdx + 2] = scale(bVal)
                rgba[outIdx + 3] = 255
                outIdx += 4
            }
        } else if magic == "P5" { // PGM binary Grayscale
            if index < bytes.count {
                let b = bytes[index]
                if b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D {
                    index += 1
                    if b == 0x0D && index < bytes.count && bytes[index] == 0x0A {
                        index += 1
                    }
                }
            }
            let bytesPerSample = maxval > 255 ? 2 : 1
            guard data.count - index >= totalPixels * bytesPerSample else { return nil }
            var inIdx = index
            for _ in 0..<totalPixels {
                let gray: UInt8
                if bytesPerSample == 1 {
                    gray = scale(Int(bytes[inIdx]))
                    inIdx += 1
                } else {
                    let gVal = (Int(bytes[inIdx]) << 8) | Int(bytes[inIdx + 1])
                    gray = scale(gVal)
                    inIdx += 2
                }
                rgba[outIdx] = gray
                rgba[outIdx + 1] = gray
                rgba[outIdx + 2] = gray
                rgba[outIdx + 3] = 255
                outIdx += 4
            }
        } else if magic == "P2" { // PGM ASCII Grayscale
            for _ in 0..<totalPixels {
                guard let valStr = readToken(), let val = Int(valStr) else { return nil }
                let gray = scale(val)
                rgba[outIdx] = gray
                rgba[outIdx + 1] = gray
                rgba[outIdx + 2] = gray
                rgba[outIdx + 3] = 255
                outIdx += 4
            }
        } else if magic == "P4" { // PBM binary Bitmap
            if index < bytes.count {
                let b = bytes[index]
                if b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D {
                    index += 1
                    if b == 0x0D && index < bytes.count && bytes[index] == 0x0A {
                        index += 1
                    }
                }
            }
            let bytesPerRow = (width + 7) / 8
            guard data.count - index >= bytesPerRow * height else { return nil }
            for y in 0..<height {
                let rowStart = index + y * bytesPerRow
                for x in 0..<width {
                    let byteIndex = rowStart + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    let bit = (bytes[byteIndex] >> bitIndex) & 1
                    let c: UInt8 = (bit == 1) ? 0 : 255
                    rgba[outIdx] = c
                    rgba[outIdx + 1] = c
                    rgba[outIdx + 2] = c
                    rgba[outIdx + 3] = 255
                    outIdx += 4
                }
            }
        } else if magic == "P1" { // PBM ASCII Bitmap
            for _ in 0..<totalPixels {
                guard let valStr = readToken(), let val = Int(valStr) else { return nil }
                let c: UInt8 = (val == 1) ? 0 : 255
                rgba[outIdx] = c
                rgba[outIdx + 1] = c
                rgba[outIdx + 2] = c
                rgba[outIdx + 3] = 255
                outIdx += 4
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
    
    // MARK: - Dedicated SGI (.sgi, .rgb, .rgba, .bw, .int, .inta) Decoder
    nonisolated static func decodeSGI(data: Data) -> CGImage? {
        guard data.count >= 512 else { return nil }
        let bytes = [UInt8](data)
        
        let readUInt16: (Int) -> UInt16 = { off in
            (UInt16(bytes[off]) << 8) | UInt16(bytes[off + 1])
        }
        let readUInt32: (Int) -> UInt32 = { off in
            (UInt32(bytes[off]) << 24) | (UInt32(bytes[off + 1]) << 16) | (UInt32(bytes[off + 2]) << 8) | UInt32(bytes[off + 3])
        }
        
        let magic = readUInt16(0)
        guard magic == 0x01DA else { return nil }
        
        let storage = bytes[2] // 0: uncompressed, 1: RLE
        let bpc = Int(bytes[3]) // 1 or 2 bytes per channel
        guard bpc == 1 || bpc == 2 else { return nil }
        
        let width = Int(readUInt16(6))
        let height = Int(readUInt16(8))
        let channels = Int(readUInt16(10))
        
        guard width > 0, height > 0, channels > 0 else { return nil }
        let totalPixels = width * height
        
        var channelPlanes = [[UInt8]](repeating: [UInt8](repeating: 0, count: totalPixels), count: min(channels, 4))
        
        if storage == 0 { // Uncompressed
            let bytesPerSample = bpc
            var offset = 512
            for c in 0..<min(channels, 4) {
                // SGI rows are stored bottom to top: row 0 is bottom row (y = height - 1)
                for y in (0..<height).reversed() {
                    let rowStart = y * width
                    for x in 0..<width {
                        if offset + bytesPerSample <= bytes.count {
                            channelPlanes[c][rowStart + x] = bytes[offset]
                            offset += bytesPerSample
                        }
                    }
                }
                if c == 3 && channels > 4 {
                    offset += (channels - 4) * totalPixels * bytesPerSample
                }
            }
        } else if storage == 1 { // RLE
            let numRows = height * channels
            let tableOffset = 512
            guard data.count >= tableOffset + numRows * 4 * 2 else { return nil }
            
            var rowOffsets = [Int](repeating: 0, count: numRows)
            for i in 0..<numRows {
                rowOffsets[i] = Int(readUInt32(tableOffset + i * 4))
            }
            
            for c in 0..<min(channels, 4) {
                for y in 0..<height {
                    let destY = height - 1 - y
                    let destRowStart = destY * width
                    let rowIndex = y + c * height
                    let rleOffset = rowOffsets[rowIndex]
                    guard rleOffset < bytes.count else { continue }
                    
                    var inIdx = rleOffset
                    var x = 0
                    if bpc == 1 {
                        while inIdx < bytes.count && x < width {
                            let pixel = bytes[inIdx]; inIdx += 1
                            let count = Int(pixel & 0x7F)
                            if count == 0 { break }
                            if (pixel & 0x80) != 0 {
                                for _ in 0..<count {
                                    if inIdx < bytes.count && x < width {
                                        channelPlanes[c][destRowStart + x] = bytes[inIdx]
                                        inIdx += 1
                                        x += 1
                                    }
                                }
                            } else {
                                if inIdx < bytes.count {
                                    let val = bytes[inIdx]; inIdx += 1
                                    for _ in 0..<count {
                                        if x < width {
                                            channelPlanes[c][destRowStart + x] = val
                                            x += 1
                                        }
                                    }
                                }
                            }
                        }
                    } else { // 16-bit
                        while inIdx + 1 < bytes.count && x < width {
                            let pixelHigh = bytes[inIdx]
                            let pixelLow = bytes[inIdx + 1]
                            inIdx += 2
                            let pixel16 = (UInt16(pixelHigh) << 8) | UInt16(pixelLow)
                            let count = Int(pixel16 & 0x7F)
                            if count == 0 { break }
                            if (pixel16 & 0x80) != 0 {
                                for _ in 0..<count {
                                    if inIdx + 1 < bytes.count && x < width {
                                        channelPlanes[c][destRowStart + x] = bytes[inIdx]
                                        inIdx += 2
                                        x += 1
                                    }
                                }
                            } else {
                                if inIdx + 1 < bytes.count {
                                    let val = bytes[inIdx]
                                    inIdx += 2
                                    for _ in 0..<count {
                                        if x < width {
                                            channelPlanes[c][destRowStart + x] = val
                                            x += 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            return nil
        }
        
        var rgba = [UInt8](repeating: 0, count: totalPixels * 4)
        var outIdx = 0
        for i in 0..<totalPixels {
            if channels == 1 {
                let g = channelPlanes[0][i]
                rgba[outIdx] = g
                rgba[outIdx + 1] = g
                rgba[outIdx + 2] = g
                rgba[outIdx + 3] = 255
            } else if channels == 2 {
                let g = channelPlanes[0][i]
                let a = channelPlanes[1][i]
                rgba[outIdx] = g
                rgba[outIdx + 1] = g
                rgba[outIdx + 2] = g
                rgba[outIdx + 3] = a
            } else if channels == 3 {
                rgba[outIdx] = channelPlanes[0][i]     // R
                rgba[outIdx + 1] = channelPlanes[1][i] // G
                rgba[outIdx + 2] = channelPlanes[2][i] // B
                rgba[outIdx + 3] = 255
            } else {
                rgba[outIdx] = channelPlanes[0][i]     // R
                rgba[outIdx + 1] = channelPlanes[1][i] // G
                rgba[outIdx + 2] = channelPlanes[2][i] // B
                rgba[outIdx + 3] = channelPlanes[3][i] // A
            }
            outIdx += 4
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
    
    // MARK: - Dedicated PICT (.pict, .pct, .pic) Decoder
    nonisolated static func decodePICT(data: Data) -> CGImage? {
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            return cgImage
        }
        if let imageRep = NSPICTImageRep(data: data) {
            let nsImage = NSImage(size: imageRep.size)
            nsImage.addRepresentation(imageRep)
            var rect = CGRect(origin: .zero, size: imageRep.size)
            if let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                return cgImage
            }
        }
        if let nsImage = NSImage(data: data) {
            var rect = CGRect(origin: .zero, size: nsImage.size)
            if let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                return cgImage
            }
        }
        return nil
    }
    
    // MARK: - Dedicated ICO / Multi-Frame Icon Decoder
    nonisolated static func decodeICO(data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(imageSource)
        guard count > 0 else { return nil }
        
        var bestIndex = 0
        var maxArea = 0
        
        for i in 0..<count {
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as? [CFString: Any] {
                let w = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
                let h = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
                let area = w * h
                if area > maxArea {
                    maxArea = area
                    bestIndex = i
                }
            }
        }
        
        return CGImageSourceCreateImageAtIndex(imageSource, bestIndex, nil)
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
        
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let count = CGImageSourceGetCount(imageSource)
            var bestW = 0
            var bestH = 0
            
            for i in 0..<count {
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as? [CFString: Any] {
                    var curW = 0
                    var curH = 0
                    if let w = properties[kCGImagePropertyPixelWidth] {
                        curW = (w as? NSNumber)?.intValue ?? ((w as? Int) ?? 0)
                    }
                    if let h = properties[kCGImagePropertyPixelHeight] {
                        curH = (h as? NSNumber)?.intValue ?? ((h as? Int) ?? 0)
                    }
                    let orient = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
                    if orient >= 5 && orient <= 8 {
                        swap(&curW, &curH)
                    }
                    if curW * curH > bestW * bestH {
                        bestW = curW
                        bestH = curH
                    }
                }
            }
            if bestW > 0, bestH > 0 {
                width = bestW
                height = bestH
            }
        }
        
        let customFormatExtensions: Set<String> = [
            "WBMP", "MNG", "PAM", "RAS", "SUN", "SR", "PPM", "PNM", "PGM", "PBM",
            "PICT", "PCT", "PIC", "SGI", "RGB", "RGBA", "BW", "INT", "INTA", "ICO", "CUR"
        ]
        
        if customFormatExtensions.contains(ext) || (width == nil || height == nil) {
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
                } else if let ppmCGImage = decodePPM(data: data) {
                    width = ppmCGImage.width
                    height = ppmCGImage.height
                } else if let sgiCGImage = decodeSGI(data: data) {
                    width = sgiCGImage.width
                    height = sgiCGImage.height
                } else if let pictCGImage = decodePICT(data: data) {
                    width = pictCGImage.width
                    height = pictCGImage.height
                } else if let icoCGImage = decodeICO(data: data) {
                    width = icoCGImage.width
                    height = icoCGImage.height
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
                let validExtensions = [
                    "jpg", "jpeg", "jpe", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif",
                    "pdf", "psd", "dng", "raw", "cr2", "cr3", "raf", "nrw", "nef", "srf", "sr2", "arw", "orf",
                    "jp2", "j2k", "jpx", "jpf", "wbmp", "mng", "pam", "ras", "sun", "sr", "rw4", "rw2", "rwl",
                    "ppm", "pnm", "pgm", "pbm", "pict", "pct", "pic", "sgi", "rgb", "rgba", "bw", "int", "inta",
                    "jps", "ico", "cur"
                ]
                for case let fileURL as URL in enumerator {
                    if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                        imageURLs.append(fileURL)
                    }
                }
                return imageURLs
            } else {
                let validExtensions = [
                    "jpg", "jpeg", "jpe", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif",
                    "pdf", "psd", "dng", "raw", "cr2", "cr3", "raf", "nrw", "nef", "srf", "sr2", "arw", "orf",
                    "jp2", "j2k", "jpx", "jpf", "wbmp", "mng", "pam", "ras", "sun", "sr", "rw4", "rw2", "rwl",
                    "ppm", "pnm", "pgm", "pbm", "pict", "pct", "pic", "sgi", "rgb", "rgba", "bw", "int", "inta",
                    "jps", "ico", "cur"
                ]
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
                if extLower == "ppm" || extLower == "pnm" || extLower == "pgm" || extLower == "pbm" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodePPM(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if extLower == "sgi" || extLower == "rgb" || extLower == "rgba" || extLower == "bw" || extLower == "int" || extLower == "inta" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodeSGI(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if extLower == "pict" || extLower == "pct" || extLower == "pic" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodePICT(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if extLower == "ico" || extLower == "cur" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodeICO(data: data) {
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
                    if let cgImage = PhotoItem.decodePPM(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                    if let cgImage = PhotoItem.decodeSGI(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                    if let cgImage = PhotoItem.decodePICT(data: data) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                    if let cgImage = PhotoItem.decodeICO(data: data) {
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
