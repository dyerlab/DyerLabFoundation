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
//  CopyToClipboard.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 11/19/25.
//

import Foundation
import SwiftUI

@MainActor public func copyToClipboard(cgImage: CGImage) {
    #if os(macOS)
    let image = NSImage(cgImage: cgImage, size: .init(width: 1280, height: 720))
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.writeObjects([image])
    #else
    let image = UIImage(cgImage: cgImage)
    UIPasteboard.general.image = image
    #endif
}
