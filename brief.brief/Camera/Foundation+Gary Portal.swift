//
//  Foundation+Gary Portal.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 20/09/2023.
//

import Foundation
import UIKit
import SwiftDate
import ImageIO


extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let aVal, rVal, gVal, bVal: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (aVal, rVal, gVal, bVal) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (aVal, rVal, gVal, bVal) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (aVal, rVal, gVal, bVal) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (aVal, rVal, gVal, bVal) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(rVal) / 255, green: CGFloat(gVal) / 255, blue: CGFloat(bVal) / 255, alpha: CGFloat(aVal) / 255)
    }
}

extension UIImage {
    func imageByCombiningImage(withImage secondImage: UIImage) -> UIImage {
        let newImageWidth  = self.size.width
        let newImageHeight = self.size.height
        let newSize = CGSize(width : newImageWidth, height: newImageHeight)
        
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        
        self.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        secondImage.draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        
        return image!
    }
    
    func getDocumentDirectoryPath() -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory as NSString
    }
    
    func saveImageToDocumentsDirectory(withName: String) -> String? {
        let image = self
        if let data = image.jpegData(compressionQuality: 0.7) {
            let dirPath = getDocumentDirectoryPath()
            let imageFileUrl = URL(fileURLWithPath: dirPath.appendingPathComponent(withName) as String)
            do {
                try data.write(to: imageFileUrl)
                return imageFileUrl.absoluteString
            } catch {
                print("Error saving image: \(error)")
            }
        }
        return nil
    }
    
    class func loadImageFromDocumentsDirectory(imageName: String) -> UIImage? {
        let tempDirPath = UIImage().getDocumentDirectoryPath()
        let imageFilePath = tempDirPath.appendingPathComponent(imageName)
        return UIImage(contentsOfFile:imageFilePath)
    }
    
    public class func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("image doesn't exist")
            return nil
        }
        
        return UIImage.animatedImageWithSource(source)
       
    }
    
    public class func gifImageWithURL(_ gifUrl:String) -> UIImage? {
        guard let bundleURL:URL = URL(string: gifUrl) else {
            print("image named \"\(gifUrl)\" doesn't exist")
            return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("image named \"\(gifUrl)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    public class func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif") else {
            print("SwiftGif: This image named \"\(name)\" does not exist")
            return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    private class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        let defaultDelay = 0.032 // 30 fps
        var delay = defaultDelay
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties: CFDictionary = unsafeBitCast(
            CFDictionaryGetValue(cfProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
            to: CFDictionary.self)
        
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        guard let castedDelay = delayObject as? Double else { return delay }
        
        delay = castedDelay < defaultDelay ? defaultDelay : castedDelay
        
        return delay
    }
    
    private class func gcdForArray(_ array: [Int]) -> Int {
        if array.isEmpty {
            return 1
        }
        
        return array.sorted(by: <).first ?? 1
    }
    
    private class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        let images = (0..<count)
            .compactMap({ CGImageSourceCreateImageAtIndex(source, $0, nil) })
        let delays = images
            .enumerated()
            .map({ Int(UIImage.delayForImageAtIndex($0.offset,source: source) * 1000) })
        
        let duration = delays.reduce(0, +)
        
        let gcd = gcdForArray(delays)
        let frames: [UIImage] = images
            .map({ UIImage(cgImage: $0) })
            .enumerated()
            .map({
                Array(repeating: $0.element, count: Int(delays[$0.offset] / gcd) )
            })
            .flatMap({ $0 })
        
        let animation = UIImage.animatedImage(with: frames, duration: Double(duration) / 1000)
        
        return animation
    }
}

extension Date {
    func minutesBetweenDates(_ newDate: Date) -> CGFloat {
        
        let oldDate = self
        //get both times sinces refrenced date and divide by 60 to get minutes
        let newDateMinutes = newDate.timeIntervalSinceReferenceDate/60
        let oldDateMinutes = oldDate.timeIntervalSinceReferenceDate/60
        
        //then return the difference
        return CGFloat(newDateMinutes - oldDateMinutes)
    }
    
    func niceDateAndTime() -> String {
        let dateFormatterPrint = DateFormatter()
        dateFormatterPrint.doesRelativeDateFormatting = true
        
        if isToday && self.hour == Date().hour && (CGFloat(Date().minute - self.minute) <= 1.5) {
            return "Now"
        } else if isToday {
            dateFormatterPrint.timeStyle = .short
            dateFormatterPrint.dateStyle = .none
            return "Today at \(dateFormatterPrint.string(from: self))"
        } else if isYesterday {
            dateFormatterPrint.timeStyle = .short
            dateFormatterPrint.dateStyle = .none
            return "Yesterday at \(dateFormatterPrint.string(from: self))"
        } else if self.compareCloseTo(Date(), precision: 6.days.timeInterval) {
            return dateFormatterPrint.weekdaySymbols[weekday - 1]
        } else {
            dateFormatterPrint.timeStyle = .none
            dateFormatterPrint.dateStyle = .short
        }
        return dateFormatterPrint.string(from: self)
    }
}

extension UIApplication {
    func addTapGestureRecognizer() {
        guard let window = windows.first else { return }
        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)
    }
    
    class func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .map({$0 as? UIWindowScene})
                .compactMap({$0})
                .first?.windows
                .filter({$0.isKeyWindow}).first
        
        let base = base ?? keyWindow?.rootViewController

        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

extension UIApplication: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false // set to `false` if you don't want to detect tap during other gestures
    }
}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirectory = try contentsOfDirectory(atPath: NSTemporaryDirectory())
            try tmpDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
}
