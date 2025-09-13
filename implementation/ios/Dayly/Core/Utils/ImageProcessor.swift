import UIKit
import CoreImage

class ImageProcessor {
    
    // MARK: - Image Processing
    
    static func processForUpload(_ image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 2048
        
        // First resize if needed
        guard let resizedImage = resize(image, maxDimension: maxDimension) else {
            return nil
        }
        
        // Convert to data and strip EXIF
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8),
              let strippedData = stripEXIFData(from: imageData),
              let finalImage = UIImage(data: strippedData) else {
            return nil
        }
        
        return finalImage
    }
    
    // MARK: - Resize
    
    static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        
        // Check if resize is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        // Create graphics context
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // Draw resized image
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - EXIF Stripping
    
    static func stripEXIFData(from imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let uti = CGImageSourceGetType(source) else {
            return nil
        }
        
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData as CFMutableData,
            uti,
            1,
            nil
        ) else {
            return nil
        }
        
        // Copy image without metadata
        let removeExifProperties: CFDictionary = [
            kCGImagePropertyExifDictionary: kCFNull,
            kCGImagePropertyGPSDictionary: kCFNull,
            kCGImagePropertyIPTCDictionary: kCFNull,
            kCGImagePropertyJFIFDictionary: kCFNull
        ] as CFDictionary
        
        CGImageDestinationAddImageFromSource(destination, source, 0, removeExifProperties)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return destinationData as Data
    }
    
    // MARK: - Orientation Fix
    
    static func fixOrientation(_ image: UIImage) -> UIImage {
        // If image orientation is already correct, return it
        if image.imageOrientation == .up {
            return image
        }
        
        // We need to calculate the proper transformation to make the image upright
        var transform = CGAffineTransform.identity
        
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: image.size.height)
            transform = transform.rotated(by: .pi)
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: image.size.height)
            transform = transform.rotated(by: -.pi / 2)
            
        default:
            break
        }
        
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: image.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        default:
            break
        }
        
        // Create a new context with the transform
        guard let cgImage = image.cgImage,
              let colorSpace = cgImage.colorSpace else {
            return image
        }
        
        let context = CGContext(
            data: nil,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        )
        
        context?.concatenate(transform)
        
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.height, height: image.size.width))
        default:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        }
        
        guard let newCGImage = context?.makeImage() else {
            return image
        }
        
        return UIImage(cgImage: newCGImage)
    }
    
    // MARK: - Utility Methods
    
    static func imageSizeInMB(data: Data) -> Double {
        return Double(data.count) / (1024.0 * 1024.0)
    }
    
    static func generateThumbnail(from image: UIImage, maxSize: CGFloat = 200) -> UIImage? {
        return resize(image, maxDimension: maxSize)
    }
}
