//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  DLImage.swift
//  BackflowStudio
//
//  Created by Rodney Dyer on 10/18/24.
//

import CoreGraphics
import Foundation
import SwiftUI


#if os(iOS)
import UIKit
public typealias DLImage = UIImage

public extension DLImage {
    
    
    var coreImage: CIImage? {
        guard let cgImage = self.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
    
     var data: Data? {
        guard let dat = self.pngData() else { return nil }
        return dat
    }
    
     func resize(to size: CGSize ) -> DLImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let result = renderer.image { (context) in
            self.draw(in: CGRect(origin: CGPoint.zero, size: size))
        }
        return result
    }
    
     func resizeKeepingAspect(maxWidth: CGFloat = 1280) -> DLImage {
        let scale = maxWidth / self.size.width
        let newHeight = self.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: maxWidth, height: newHeight))
        self.draw(in: CGRect(x: 0, y: 0, width: maxWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
    
}

/*
extension BDImage: @unchecked Sendable {
    
    public enum Error: Swift.Error {
        case invalidImage
    }
}
*/




#elseif os(macOS)
import AppKit
public typealias DLImage = NSImage

public extension DLImage {
    
     var coreImage: CIImage? {
        guard let tiffData = tiffRepresentation,
              let ciImage = CIImage(data: tiffData)  else { return nil }
        return ciImage
    }
    
     var data: Data? {
        guard let data = self.tiffRepresentation else { return nil }
        return data
    }
    
     func resize(to size: CGSize) -> DLImage? {
        let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let representation = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
            return nil
        }
        let image = NSImage(size: size, flipped: false, drawingHandler: { (_) -> Bool in
            return representation.draw(in: frame)
        })
        
        return image
    }
    
     func resizeKeepingAspect(maxWidth: CGFloat = 1280) -> DLImage {
        let scale = maxWidth / self.size.width
        let newHeight = self.size.height * scale
        
        let newSize = NSSize(width: maxWidth, height: newHeight)
        let image = DLImage(size: newSize)
        image.lockFocus()
        let context = NSGraphicsContext.current
        context!.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize), from: NSZeroRect, operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }
    
    
}

#endif





public extension DLImage {
    
     func mainColors(groups k: Int) -> [Color] {
        var ret = [Color]()
        
        if let img = self.resize(to: CGSize(width: 100, height: 100) ) {
            let pts = img.toPoint3D
            let clusters = kMeansClustering(points: pts, k: k)
            for cluster in clusters {
                let col = Color(red: cluster.center.x,
                                green: cluster.center.y,
                                blue: cluster.center.z)
                ret.append( col )
            }
        }
        return ret
    }
    
     var toPoint3D: [Point3D] {
        #if os(iOS)
        guard let cgImage = self.cgImage else { return [] }
        assert(cgImage.bitsPerPixel == 32, "Only support 32bit images")
        assert(cgImage.bitsPerComponent == 8,  "only support 8 bit per channel")
        #elseif os(macOS)
        var imageRect = CGRect(x:0,y:0,width: self.size.width, height: self.size.height)
        guard let cgImage = self.cgImage(forProposedRect: &imageRect, context: nil, hints: nil ) else { return [] }
        #endif
        guard let imageData = cgImage.dataProvider?.data as Data? else {
            return []
        }
        let size = cgImage.width * cgImage.height
        let buffer = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: size)
        _ = imageData.copyBytes(to: buffer)
        
        
        var ret = [Point3D]()
        ret.reserveCapacity(size)
        
        for pixel in buffer {
            var r : UInt32 = 0
            var g : UInt32 = 0
            var b : UInt32 = 0
            if cgImage.byteOrderInfo == .orderDefault || cgImage.byteOrderInfo == .order32Big {
                r = pixel & 255
                g = (pixel >> 8) & 255
                b = (pixel >> 16) & 255
            } else if cgImage.byteOrderInfo == .order32Little {
                r = (pixel >> 16) & 255
                g = (pixel >> 8) & 255
                b = pixel & 255
            }
            
            ret.append( Point3D( CGFloat(r)/255.0,
                                 CGFloat(g)/255.0,
                                 CGFloat(b)/255.0) )
        }
        return ret
    }
    
}


