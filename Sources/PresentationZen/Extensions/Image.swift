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
//  Image.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 10/19/24.
//

import Foundation
import SwiftUI

public extension Image {

    /// Resizes and clips this image to fill its container while preserving aspect ratio.
    ///
    /// - Returns: A view that fills the space `GeometryReader` gives it, cropping any
    ///   overflow around the center.
    func centerCropped() -> some View {
        GeometryReader { geo in
            self
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .contentShape(Rectangle())
        }
    }

    /// Creates a SwiftUI `Image` from a platform-neutral `DLImage`
    /// (`UIImage` on iOS, `NSImage` on macOS).
    ///
    /// - Parameter dlImage: The platform image to wrap.
    init(dlImage: DLImage) {
        #if os(iOS)
        self.init(uiImage: dlImage)
        #elseif os(macOS)
        self.init(nsImage: dlImage)
        #endif
    }

}
