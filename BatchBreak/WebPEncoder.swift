//
//  WebPEncoder.swift
//  BatchBreak
//
//  Created for BatchBreak WebP export with full alpha channel transparency support.
//

import Foundation
import CoreGraphics
import ImageIO

#if canImport(libwebp)
import libwebp
#endif

public enum WebPEncoder {
    
    /// Encodes a CGImage to WebP Data.
    /// - If `libwebp` is linked, uses Google's official encoder for ultra-efficient lossy/lossless compression
    ///   (typically 200KB - 500KB with full alpha channel preservation and quality slider support).
    /// - If `libwebp` is not yet linked, falls back to the pure-Swift VP8L bitstream writer.
    public static func encode(cgImage: CGImage, quality: Double = 0.8, preserveTransparency: Bool = true) -> Data? {
        #if canImport(libwebp)
        return encodeWithLibWebP(cgImage: cgImage, quality: quality, preserveTransparency: preserveTransparency)
        #else
        return encodePureSwift(cgImage: cgImage, preserveTransparency: preserveTransparency)
        #endif
    }
    
    #if canImport(libwebp)
    private static func encodeWithLibWebP(cgImage: CGImage, quality: Double, preserveTransparency: Bool) -> Data? {
        let width = Int32(cgImage.width)
        let height = Int32(cgImage.height)
        guard width > 0, height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = Int(width) * 4
        var rawData = [UInt8](repeating: 0, count: Int(width * height) * 4)
        
        guard let context = CGContext(
            data: &rawData,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
        
        let pixelCount = Int(width * height)
        var hasAlpha = false
        
        if preserveTransparency {
            for i in 0..<pixelCount {
                if rawData[i * 4 + 3] < 255 {
                    hasAlpha = true
                    break
                }
            }
        }
        
        // Unpremultiply alpha for true color accuracy
        if hasAlpha {
            for i in 0..<pixelCount {
                let offset = i * 4
                let a = UInt32(rawData[offset + 3])
                if a == 0 {
                    rawData[offset + 0] = 0
                    rawData[offset + 1] = 0
                    rawData[offset + 2] = 0
                } else if a < 255 {
                    let rPremul = UInt32(rawData[offset + 0])
                    let gPremul = UInt32(rawData[offset + 1])
                    let bPremul = UInt32(rawData[offset + 2])
                    rawData[offset + 0] = UInt8(min(255, (rPremul * 255 + a / 2) / a))
                    rawData[offset + 1] = UInt8(min(255, (gPremul * 255 + a / 2) / a))
                    rawData[offset + 2] = UInt8(min(255, (bPremul * 255 + a / 2) / a))
                }
            }
        } else {
            // Flatten transparent pixels to white if transparency is not preserved
            for i in 0..<pixelCount {
                let offset = i * 4
                let a = UInt32(rawData[offset + 3])
                if a < 255 {
                    let rPremul = UInt32(rawData[offset + 0])
                    let gPremul = UInt32(rawData[offset + 1])
                    let bPremul = UInt32(rawData[offset + 2])
                    let invA = 255 - a
                    rawData[offset + 0] = UInt8(min(255, rPremul + invA))
                    rawData[offset + 1] = UInt8(min(255, gPremul + invA))
                    rawData[offset + 2] = UInt8(min(255, bPremul + invA))
                    rawData[offset + 3] = 255
                }
            }
        }
        
        var outputBuffer: UnsafeMutablePointer<UInt8>?
        let outputSize: size_t
        
        if quality >= 1.0 {
            // Lossless WebP
            outputSize = WebPEncodeLosslessRGBA(
                rawData,
                width,
                height,
                width * 4,
                &outputBuffer
            )
        } else {
            // Lossy WebP with alpha preservation (scaled from 0.0...1.0 to 0...100)
            let qFactor = Float(max(0.0, min(1.0, quality)) * 100.0)
            outputSize = WebPEncodeRGBA(
                rawData,
                width,
                height,
                width * 4,
                qFactor,
                &outputBuffer
            )
        }
        
        guard outputSize > 0, let buffer = outputBuffer else { return nil }
        let data = Data(bytes: buffer, count: outputSize)
        WebPFree(buffer)
        return data
    }
    #endif
    
    // MARK: - Pure-Swift Fallback Encoder
    
    private final class BitWriter {
        var data = Data()
        private var bitBuffer: UInt64 = 0
        private var bitCount: Int = 0
        
        init(capacity: Int = 0) {
            if capacity > 0 {
                data.reserveCapacity(capacity)
            }
        }
        
        @inline(__always)
        func writeBits(_ value: UInt64, count: Int) {
            bitBuffer |= (value & ((1 &<< count) - 1)) &<< bitCount
            bitCount += count
            while bitCount >= 8 {
                data.append(UInt8(bitBuffer & 0xFF))
                bitBuffer &>>= 8
                bitCount -= 8
            }
        }
        
        func flush() {
            if bitCount > 0 {
                data.append(UInt8(bitBuffer & 0xFF))
                bitBuffer = 0
                bitCount = 0
            }
        }
    }
    
    private static let reverseTable: [UInt8] = (0...255).map { b in
        var x = UInt8(b)
        x = ((x & 0xAA) >> 1) | ((x & 0x55) << 1)
        x = ((x & 0xCC) >> 2) | ((x & 0x33) << 2)
        return (x >> 4) | (x << 4)
    }
    
    private static func encodePureSwift(cgImage: CGImage, preserveTransparency: Bool) -> Data? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let pixelCount = width * height
        var hasAlpha = false
        
        if preserveTransparency {
            for i in 0..<pixelCount {
                if rawData[i * 4 + 3] < 255 {
                    hasAlpha = true
                    break
                }
            }
        }
        
        if hasAlpha {
            for i in 0..<pixelCount {
                let offset = i * 4
                let a = UInt32(rawData[offset + 3])
                if a == 0 {
                    rawData[offset + 0] = 0
                    rawData[offset + 1] = 0
                    rawData[offset + 2] = 0
                } else if a < 255 {
                    let rPremul = UInt32(rawData[offset + 0])
                    let gPremul = UInt32(rawData[offset + 1])
                    let bPremul = UInt32(rawData[offset + 2])
                    rawData[offset + 0] = UInt8(min(255, (rPremul * 255 + a / 2) / a))
                    rawData[offset + 1] = UInt8(min(255, (gPremul * 255 + a / 2) / a))
                    rawData[offset + 2] = UInt8(min(255, (bPremul * 255 + a / 2) / a))
                }
            }
        }
        
        let estimatedSize = 256 + pixelCount * (hasAlpha ? 4 : 3)
        let bw = BitWriter(capacity: estimatedSize)
        
        bw.writeBits(0x2F, count: 8)
        bw.writeBits(UInt64(width - 1), count: 14)
        bw.writeBits(UInt64(height - 1), count: 14)
        bw.writeBits(hasAlpha ? 1 : 0, count: 1)
        bw.writeBits(0, count: 3)
        bw.writeBits(0, count: 1)
        bw.writeBits(0, count: 1)
        bw.writeBits(0, count: 1)
        
        let emitFlatTree = { (alphabetSize: Int) in
            bw.writeBits(0, count: 1)
            bw.writeBits(8, count: 4)
            let order: [Int] = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8]
            for s in order {
                bw.writeBits(s == 0 || s == 8 ? 1 : 0, count: 3)
            }
            bw.writeBits(0, count: 1)
            for i in 0..<alphabetSize {
                bw.writeBits(i < 256 ? 1 : 0, count: 1)
            }
        }
        
        emitFlatTree(280)
        emitFlatTree(256)
        emitFlatTree(256)
        
        if hasAlpha {
            emitFlatTree(256)
        } else {
            bw.writeBits(1, count: 1)
            bw.writeBits(0, count: 1)
            bw.writeBits(1, count: 1)
            bw.writeBits(255, count: 8)
        }
        
        bw.writeBits(1, count: 1)
        bw.writeBits(0, count: 1)
        bw.writeBits(0, count: 1)
        bw.writeBits(0, count: 1)
        
        let rev = reverseTable
        if hasAlpha {
            for i in 0..<pixelCount {
                let offset = i * 4
                let r = UInt64(rev[Int(rawData[offset + 0])])
                let g = UInt64(rev[Int(rawData[offset + 1])])
                let b = UInt64(rev[Int(rawData[offset + 2])])
                let a = UInt64(rev[Int(rawData[offset + 3])])
                let pixelWord = g | (r &<< 8) | (b &<< 16) | (a &<< 24)
                bw.writeBits(pixelWord, count: 32)
            }
        } else {
            for i in 0..<pixelCount {
                let offset = i * 4
                let r = UInt64(rev[Int(rawData[offset + 0])])
                let g = UInt64(rev[Int(rawData[offset + 1])])
                let b = UInt64(rev[Int(rawData[offset + 2])])
                let pixelWord = g | (r &<< 8) | (b &<< 16)
                bw.writeBits(pixelWord, count: 24)
            }
        }
        
        bw.flush()
        
        let payload = bw.data
        var riff = Data()
        riff.reserveCapacity(payload.count + 32)
        riff.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        let fileSize = UInt32(4 + 8 + payload.count + (payload.count & 1))
        var fsLE = fileSize.littleEndian
        riff.append(Data(bytes: &fsLE, count: 4))
        riff.append(contentsOf: [0x57, 0x45, 0x42, 0x50])
        
        riff.append(contentsOf: [0x56, 0x50, 0x38, 0x4C])
        var plSizeLE = UInt32(payload.count).littleEndian
        riff.append(Data(bytes: &plSizeLE, count: 4))
        riff.append(payload)
        
        if (payload.count & 1) != 0 {
            riff.append(0)
        }
        
        return riff
    }
}
