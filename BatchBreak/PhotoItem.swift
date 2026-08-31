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
                "PIC", "SGI", "RGB", "RGBA", "BW", "INT", "INTA", "ICO", "CUR", "SVG", "EPS", "EPSF", "PS"
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
    
    // MARK: - Dedicated EPS Decoder (Encapsulated PostScript)
    nonisolated static func decodeEPS(data: Data, targetSize: CGSize? = nil) -> CGImage? {
        guard data.count >= 4 else { return nil }
        var postScriptData = data
        
        // 1. Binary DOS EPS header check (0xC5D0D3C6)
        let headerBytes = [UInt8](data.prefix(32))
        if headerBytes.count >= 30 &&
           headerBytes[0] == 0xC5 && headerBytes[1] == 0xD0 && headerBytes[2] == 0xD3 && headerBytes[3] == 0xC6 {
            let readUInt32LE: (Int) -> UInt32 = { off in
                UInt32(headerBytes[off]) | (UInt32(headerBytes[off+1]) << 8) | (UInt32(headerBytes[off+2]) << 16) | (UInt32(headerBytes[off+3]) << 24)
            }
            let psOffset = Int(readUInt32LE(4))
            let psLength = Int(readUInt32LE(8))
            let tiffOffset = Int(readUInt32LE(20))
            let tiffLength = Int(readUInt32LE(24))
            
            if tiffOffset > 0 && tiffLength > 0 && tiffOffset + tiffLength <= data.count {
                let tiffSlice = data.subdata(in: tiffOffset..<tiffOffset + tiffLength)
                if let source = CGImageSourceCreateWithData(tiffSlice as CFData, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    return cgImage
                }
            }
            
            if psOffset > 0 && psLength > 0 && psOffset + psLength <= data.count {
                postScriptData = data.subdata(in: psOffset..<psOffset + psLength)
            }
        }
        
        // 2. Check for embedded JPEG stream (/DCTDecode / JPEG SOI-EOI markers)
        let rawBytes = [UInt8](postScriptData)
        if rawBytes.count > 100 {
            for i in 0..<(rawBytes.count - 4) {
                if rawBytes[i] == 0xFF && rawBytes[i+1] == 0xD8 && rawBytes[i+2] == 0xFF {
                    for j in (i + 100)..<(rawBytes.count - 1) {
                        if rawBytes[j] == 0xFF && rawBytes[j+1] == 0xD9 {
                            let jpegSlice = postScriptData.subdata(in: i..<j + 2)
                            if let source = CGImageSourceCreateWithData(jpegSlice as CFData, nil),
                               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                                return cgImage
                            }
                            break
                        }
                    }
                }
            }
        }
        
        // 3. PostScript ASCII / Vector / Raster parsing
        guard let text = String(data: postScriptData, encoding: .ascii)
            ?? String(data: postScriptData, encoding: .isoLatin1)
            ?? String(data: postScriptData, encoding: .utf8) else {
            return nil
        }
        
        // Parse BoundingBox
        var parsedBBox: (llx: Double, lly: Double, urx: Double, ury: Double)? = nil
        let lines = text.components(separatedBy: .newlines)
        for line in lines.prefix(300) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("%%BoundingBox:") {
                let parts = trimmed.dropFirst("%%BoundingBox:".count)
                    .trimmingCharacters(in: .whitespaces)
                    .split(whereSeparator: { $0.isWhitespace })
                    .compactMap { Double($0) }
                if parts.count >= 4 {
                    parsedBBox = (llx: parts[0], lly: parts[1], urx: parts[2], ury: parts[3])
                }
            } else if trimmed.hasPrefix("%%HiResBoundingBox:") || trimmed.hasPrefix("%%ExactBoundingBox:") || trimmed.hasPrefix("%%CropBox:") {
                let prefixLen = trimmed.hasPrefix("%%HiResBoundingBox:") ? "%%HiResBoundingBox:".count : (trimmed.hasPrefix("%%ExactBoundingBox:") ? "%%ExactBoundingBox:".count : "%%CropBox:".count)
                let parts = trimmed.dropFirst(prefixLen)
                    .trimmingCharacters(in: .whitespaces)
                    .split(whereSeparator: { $0.isWhitespace })
                    .compactMap { Double($0) }
                if parts.count >= 4 {
                    parsedBBox = (llx: parts[0], lly: parts[1], urx: parts[2], ury: parts[3])
                    break
                }
            }
        }
        
        let bbox = parsedBBox ?? (llx: 0.0, lly: 0.0, urx: 612.0, ury: 792.0)
        let origWidth = max(1.0, bbox.urx - bbox.llx)
        let origHeight = max(1.0, bbox.ury - bbox.lly)
        
        let scale: CGFloat
        let renderWidth: Int
        let renderHeight: Int
        
        if let target = targetSize, target.width > 0, target.height > 0 {
            let scaleX = target.width / origWidth
            let scaleY = target.height / origHeight
            scale = min(scaleX, scaleY)
            renderWidth = max(1, Int(round(origWidth * scale)))
            renderHeight = max(1, Int(round(origHeight * scale)))
        } else {
            let supersample: CGFloat = (origWidth < 300 || origHeight < 300) ? 3.0 : 2.0
            scale = supersample
            renderWidth = max(1, Int(round(origWidth * scale)))
            renderHeight = max(1, Int(round(origHeight * scale)))
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: renderWidth,
            height: renderHeight,
            bitsPerComponent: 8,
            bytesPerRow: renderWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight))
        
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: CGFloat(-bbox.llx), y: CGFloat(-bbox.lly))
        
        var currentPath = CGMutablePath()
        var definedProcs: [String: [String]] = [
            "m": ["moveto"],
            "l": ["lineto"],
            "c": ["curveto"],
            "v": ["curveto"],
            "y": ["curveto"],
            "h": ["closepath"],
            "cp": ["closepath"],
            "f": ["fill"],
            "F": ["fill"],
            "s": ["stroke"],
            "S": ["stroke"],
            "b": ["closepath", "fill", "stroke"],
            "B": ["fill", "stroke"],
            "g": ["setgray"],
            "G": ["setgray"],
            "rg": ["setrgbcolor"],
            "RG": ["setrgbcolor"],
            "k": ["setcmykcolor"],
            "K": ["setcmykcolor"],
            "w": ["setlinewidth"],
            "W": ["clip"],
            "j": ["setlinejoin"],
            "J": ["setlinecap"],
            "d": ["setdash"]
        ]
        
        var tokens: [String] = []
        var curIdx = text.startIndex
        let endIdx = text.endIndex
        
        while curIdx < endIdx {
            let ch = text[curIdx]
            if ch.isWhitespace {
                curIdx = text.index(after: curIdx)
            } else if ch == "%" {
                while curIdx < endIdx && text[curIdx] != "\n" && text[curIdx] != "\r" {
                    curIdx = text.index(after: curIdx)
                }
            } else if ch == "(" {
                var str = "("
                curIdx = text.index(after: curIdx)
                var depth = 1
                while curIdx < endIdx && depth > 0 {
                    let sc = text[curIdx]
                    if sc == "\\" {
                        str.append(sc)
                        curIdx = text.index(after: curIdx)
                        if curIdx < endIdx { str.append(text[curIdx]); curIdx = text.index(after: curIdx) }
                    } else if sc == "(" {
                        depth += 1
                        str.append(sc)
                        curIdx = text.index(after: curIdx)
                    } else if sc == ")" {
                        depth -= 1
                        str.append(sc)
                        curIdx = text.index(after: curIdx)
                    } else {
                        str.append(sc)
                        curIdx = text.index(after: curIdx)
                    }
                }
                tokens.append(str)
            } else if ch == "{" || ch == "}" || ch == "[" || ch == "]" {
                tokens.append(String(ch))
                curIdx = text.index(after: curIdx)
            } else {
                let start = curIdx
                while curIdx < endIdx && !text[curIdx].isWhitespace && text[curIdx] != "%" && text[curIdx] != "{" && text[curIdx] != "}" && text[curIdx] != "[" && text[curIdx] != "]" && text[curIdx] != "(" {
                    curIdx = text.index(after: curIdx)
                }
                tokens.append(String(text[start..<curIdx]))
            }
        }
        
        var stack: [Any] = []
        var tokenIdx = 0
        
        func executeToken(_ token: String) {
            if let macro = definedProcs[token] {
                for t in macro {
                    executeToken(t)
                }
                return
            }
            
            if let num = Double(token) {
                stack.append(num)
                return
            }
            
            switch token {
            case "moveto":
                if stack.count >= 2, let y = stack.popLast() as? Double, let x = stack.popLast() as? Double {
                    currentPath.move(to: CGPoint(x: x, y: y))
                }
            case "rmoveto":
                if stack.count >= 2, let dy = stack.popLast() as? Double, let dx = stack.popLast() as? Double {
                    let cur = currentPath.currentPoint
                    currentPath.move(to: CGPoint(x: cur.x + CGFloat(dx), y: cur.y + CGFloat(dy)))
                }
            case "lineto":
                if stack.count >= 2, let y = stack.popLast() as? Double, let x = stack.popLast() as? Double {
                    if currentPath.isEmpty {
                        currentPath.move(to: CGPoint(x: x, y: y))
                    } else {
                        currentPath.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            case "rlineto":
                if stack.count >= 2, let dy = stack.popLast() as? Double, let dx = stack.popLast() as? Double {
                    let cur = currentPath.currentPoint
                    currentPath.addLine(to: CGPoint(x: cur.x + CGFloat(dx), y: cur.y + CGFloat(dy)))
                }
            case "curveto":
                if stack.count >= 6,
                   let y3 = stack.popLast() as? Double, let x3 = stack.popLast() as? Double,
                   let y2 = stack.popLast() as? Double, let x2 = stack.popLast() as? Double,
                   let y1 = stack.popLast() as? Double, let x1 = stack.popLast() as? Double {
                    if currentPath.isEmpty {
                        currentPath.move(to: CGPoint(x: x1, y: y1))
                    }
                    currentPath.addCurve(to: CGPoint(x: x3, y: y3), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
                }
            case "closepath":
                currentPath.closeSubpath()
            case "newpath":
                currentPath = CGMutablePath()
            case "stroke":
                context.addPath(currentPath)
                context.strokePath()
                currentPath = CGMutablePath()
            case "fill":
                context.addPath(currentPath)
                context.fillPath()
                currentPath = CGMutablePath()
            case "eofill":
                context.addPath(currentPath)
                context.drawPath(using: .eoFill)
                currentPath = CGMutablePath()
            case "clip":
                context.addPath(currentPath)
                context.clip()
            case "eoclip":
                context.addPath(currentPath)
                context.clip(using: .evenOdd)
            case "rectfill":
                if stack.count >= 4,
                   let h = stack.popLast() as? Double, let w = stack.popLast() as? Double,
                   let y = stack.popLast() as? Double, let x = stack.popLast() as? Double {
                    context.fill(CGRect(x: x, y: y, width: w, height: h))
                }
            case "rectstroke":
                if stack.count >= 4,
                   let h = stack.popLast() as? Double, let w = stack.popLast() as? Double,
                   let y = stack.popLast() as? Double, let x = stack.popLast() as? Double {
                    context.stroke(CGRect(x: x, y: y, width: w, height: h))
                }
            case "rectclip":
                if stack.count >= 4,
                   let h = stack.popLast() as? Double, let w = stack.popLast() as? Double,
                   let y = stack.popLast() as? Double, let x = stack.popLast() as? Double {
                    context.clip(to: CGRect(x: x, y: y, width: w, height: h))
                }
            case "arc":
                if stack.count >= 5,
                   let a2 = stack.popLast() as? Double, let a1 = stack.popLast() as? Double,
                   let r = stack.popLast() as? Double, let y = stack.popLast() as? Double,
                   let x = stack.popLast() as? Double {
                    let rad1 = a1 * .pi / 180.0
                    let rad2 = a2 * .pi / 180.0
                    currentPath.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(r), startAngle: CGFloat(rad1), endAngle: CGFloat(rad2), clockwise: false)
                }
            case "arcn":
                if stack.count >= 5,
                   let a2 = stack.popLast() as? Double, let a1 = stack.popLast() as? Double,
                   let r = stack.popLast() as? Double, let y = stack.popLast() as? Double,
                   let x = stack.popLast() as? Double {
                    let rad1 = a1 * .pi / 180.0
                    let rad2 = a2 * .pi / 180.0
                    currentPath.addArc(center: CGPoint(x: x, y: y), radius: CGFloat(r), startAngle: CGFloat(rad1), endAngle: CGFloat(rad2), clockwise: true)
                }
            case "setgray":
                if let g = stack.popLast() as? Double {
                    context.setFillColor(CGColor(gray: CGFloat(g), alpha: 1.0))
                    context.setStrokeColor(CGColor(gray: CGFloat(g), alpha: 1.0))
                }
            case "setrgbcolor":
                if stack.count >= 3,
                   let b = stack.popLast() as? Double, let g = stack.popLast() as? Double, let r = stack.popLast() as? Double {
                    context.setFillColor(CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0))
                    context.setStrokeColor(CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0))
                }
            case "setcmykcolor":
                if stack.count >= 4,
                   let k = stack.popLast() as? Double, let y = stack.popLast() as? Double,
                   let m = stack.popLast() as? Double, let c = stack.popLast() as? Double {
                    let r = (1.0 - c) * (1.0 - k)
                    let g = (1.0 - m) * (1.0 - k)
                    let b = (1.0 - y) * (1.0 - k)
                    context.setFillColor(CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0))
                    context.setStrokeColor(CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0))
                }
            case "setlinewidth":
                if let w = stack.popLast() as? Double {
                    context.setLineWidth(CGFloat(w))
                }
            case "setlinejoin":
                if let j = stack.popLast() as? Double {
                    let join: CGLineJoin = j == 1 ? .round : (j == 2 ? .bevel : .miter)
                    context.setLineJoin(join)
                }
            case "setlinecap":
                if let cap = stack.popLast() as? Double {
                    let lineCap: CGLineCap = cap == 1 ? .round : (cap == 2 ? .square : .butt)
                    context.setLineCap(lineCap)
                }
            case "setmiterlimit":
                if let limit = stack.popLast() as? Double {
                    context.setMiterLimit(CGFloat(limit))
                }
            case "gsave":
                context.saveGState()
            case "grestore":
                context.restoreGState()
            case "translate":
                if stack.count >= 2, let ty = stack.popLast() as? Double, let tx = stack.popLast() as? Double {
                    context.translateBy(x: CGFloat(tx), y: CGFloat(ty))
                }
            case "scale":
                if stack.count >= 2, let sy = stack.popLast() as? Double, let sx = stack.popLast() as? Double {
                    context.scaleBy(x: CGFloat(sx), y: CGFloat(sy))
                }
            case "rotate":
                if let angle = stack.popLast() as? Double {
                    let radians = angle * .pi / 180.0
                    context.rotate(by: CGFloat(radians))
                }
            case "pop":
                _ = stack.popLast()
            case "dup":
                if let top = stack.last {
                    stack.append(top)
                }
            case "exch":
                if stack.count >= 2 {
                    let a = stack.removeLast()
                    let b = stack.removeLast()
                    stack.append(a)
                    stack.append(b)
                }
            case "def", "bind":
                break
            default:
                if token.hasPrefix("/") {
                    stack.append(token)
                }
            }
        }
        
        while tokenIdx < tokens.count {
            let t = tokens[tokenIdx]
            if t.hasPrefix("/") && tokenIdx + 2 < tokens.count && tokens[tokenIdx + 1] == "{" {
                let name = String(t.dropFirst())
                tokenIdx += 2
                var bodyTokens: [String] = []
                var depth = 1
                while tokenIdx < tokens.count && depth > 0 {
                    let bt = tokens[tokenIdx]
                    if bt == "{" { depth += 1 }
                    else if bt == "}" {
                        depth -= 1
                        if depth == 0 { tokenIdx += 1; break }
                    }
                    bodyTokens.append(bt)
                    tokenIdx += 1
                }
                while tokenIdx < tokens.count && (tokens[tokenIdx] == "bind" || tokens[tokenIdx] == "def") {
                    tokenIdx += 1
                }
                definedProcs[name] = bodyTokens
                continue
            }
            executeToken(t)
            tokenIdx += 1
        }
        
        context.restoreGState()
        return context.makeImage()
    }
    
    // MARK: - Dedicated SVG Decoder
    nonisolated static func decodeSVG(data: Data, targetSize: CGSize? = nil) -> CGImage? {
        guard let nsImage = NSImage(data: data) else { return nil }
        var imageSize = nsImage.size
        if imageSize.width <= 0 || imageSize.height <= 0 {
            imageSize = CGSize(width: 1024, height: 1024)
        }
        
        let destSize: CGSize
        if let target = targetSize, target.width > 0, target.height > 0 {
            let widthRatio = target.width / imageSize.width
            let heightRatio = target.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            destSize = CGSize(width: max(1, imageSize.width * scale), height: max(1, imageSize.height * scale))
        } else {
            let renderScale: CGFloat = 2.0
            destSize = CGSize(width: max(1, imageSize.width * renderScale), height: max(1, imageSize.height * renderScale))
        }
        
        let width = Int(destSize.width)
        let height = Int(destSize.height)
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
        ) else {
            var rect = CGRect(origin: .zero, size: destSize)
            return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        let currentContext = NSGraphicsContext.current
        NSGraphicsContext.current = graphicsContext
        nsImage.draw(in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)),
                     from: .zero,
                     operation: .sourceOver,
                     fraction: 1.0)
        NSGraphicsContext.current = currentContext
        
        return context.makeImage()
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
            "PICT", "PCT", "PIC", "SGI", "RGB", "RGBA", "BW", "INT", "INTA", "ICO", "CUR", "SVG",
            "EPS", "EPSF", "PS"
        ]
        
        if customFormatExtensions.contains(ext) || (width == nil || height == nil) {
            if let data = try? Data(contentsOf: url) {
                if ext == "SVG", let svgCGImage = decodeSVG(data: data) {
                    width = svgCGImage.width
                    height = svgCGImage.height
                } else if (ext == "EPS" || ext == "EPSF" || ext == "PS"), let epsCGImage = decodeEPS(data: data) {
                    width = epsCGImage.width
                    height = epsCGImage.height
                } else if let wbmpCGImage = decodeWBMP(data: data) {
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
                } else if let epsCGImage = decodeEPS(data: data) {
                    width = epsCGImage.width
                    height = epsCGImage.height
                } else if let nsImage = NSImage(data: data) {
                    let sz = nsImage.size
                    if sz.width > 0 && sz.height > 0 {
                        width = Int(sz.width)
                        height = Int(sz.height)
                    }
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
    
    nonisolated static func scanForImagesDetailed(in url: URL) -> (validURLs: [URL], unsupportedNames: [String]) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let validExtensions: Set<String> = [
            "jpg", "jpeg", "jpe", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif",
            "pdf", "psd", "dng", "raw", "cr2", "cr3", "raf", "nrw", "nef", "srf", "sr2", "arw", "orf",
            "jp2", "j2k", "jpx", "jpf", "wbmp", "mng", "pam", "ras", "sun", "sr", "rw4", "rw2", "rwl",
            "ppm", "pnm", "pgm", "pbm", "pict", "pct", "pic", "sgi", "rgb", "rgba", "bw", "int", "inta",
            "jps", "ico", "cur", "svg", "eps", "epsf", "ps"
        ]
        
        let ignoredFiles: Set<String> = [
            ".ds_store", "thumbs.db", "desktop.ini", ".localized"
        ]
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    return ([], [url.lastPathComponent])
                }
                var imageURLs: [URL] = []
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    if validExtensions.contains(ext) {
                        imageURLs.append(fileURL)
                    }
                }
                if imageURLs.isEmpty {
                    return ([], [url.lastPathComponent])
                }
                return (imageURLs, [])
            } else {
                let filename = url.lastPathComponent
                if ignoredFiles.contains(filename.lowercased()) || filename.hasPrefix(".") {
                    return ([], [])
                }
                let ext = url.pathExtension.lowercased()
                if validExtensions.contains(ext) {
                    return ([url], [])
                } else {
                    return ([], [filename])
                }
            }
        }
        return ([], [url.lastPathComponent])
    }
    
    nonisolated static func scanForImages(in url: URL) -> [URL] {
        return scanForImagesDetailed(in: url).validURLs
    }
    
    nonisolated func loadThumbnailAsync(targetSize: CGSize = CGSize(width: 320, height: 320), completion: @escaping @Sendable (NSImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = self.withSecurityScopedAccess { () -> NSImage? in
                let extLower = self.fileExtension.lowercased()
                if extLower == "svg" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodeSVG(data: data, targetSize: targetSize) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
                if extLower == "eps" || extLower == "epsf" || extLower == "ps" {
                    if let data = try? Data(contentsOf: self.url),
                       let cgImage = PhotoItem.decodeEPS(data: data, targetSize: targetSize) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                }
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
                    if let cgImage = PhotoItem.decodeSVG(data: data, targetSize: targetSize) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
                    if let cgImage = PhotoItem.decodeEPS(data: data, targetSize: targetSize) {
                        return NSImage(cgImage: cgImage, size: targetSize)
                    }
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
