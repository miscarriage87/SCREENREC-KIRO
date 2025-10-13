import Foundation
import CoreGraphics
import AppKit

/// Shared test utilities and error types
public enum VisionTestError: Error {
    case imageCreationFailed
}

/// Utility functions for creating test images
public struct TestImageFactory {
    
    public static func createTextImage(text: String, fontSize: CGFloat = 18, size: CGSize = CGSize(width: 400, height: 100)) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                     bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw VisionTestError.imageCreationFailed
        }
        
        // White background
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw text
        context.setFillColor(CGColor.black)
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        context.textPosition = CGPoint(x: 20, y: size.height - 40)
        CTLineDraw(line, context)
        
        guard let image = context.makeImage() else {
            throw VisionTestError.imageCreationFailed
        }
        
        return image
    }
    
    public static func createEmptyImage(size: CGSize = CGSize(width: 200, height: 100)) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                     bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw VisionTestError.imageCreationFailed
        }
        
        // White background only
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: .zero, size: size))
        
        guard let image = context.makeImage() else {
            throw VisionTestError.imageCreationFailed
        }
        
        return image
    }
    
    public static func createMinimalImage() throws -> CGImage {
        return try createEmptyImage(size: CGSize(width: 10, height: 10))
    }
}