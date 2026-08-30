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
            let isInputLossless = ["PNG", "TIFF", "TIF", "BMP", "PSD", "PDF"].contains(uppercasedExt)
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
            if let w = properties[kCGImagePropertyPixelWidth] {
                width = (w as? NSNumber)?.intValue ?? (w as? Int)
            }
            if let h = properties[kCGImagePropertyPixelHeight] {
                height = (h as? NSNumber)?.intValue ?? (h as? Int)
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
                let validExtensions = ["jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "bmp", "gif", "pdf", "psd"]
                for case let fileURL as URL in enumerator {
                    if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                        imageURLs.append(fileURL)
                    }
                }
                return imageURLs
            } else {
                let validExtensions = ["jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "bmp", "gif", "pdf", "psd"]
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
                if self.fileExtension.lowercased() == "pdf" {
                    if let pdfDoc = PDFDocument(url: self.url), let page = pdfDoc.page(at: 0) {
                        return page.thumbnail(of: targetSize, for: .mediaBox)
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
