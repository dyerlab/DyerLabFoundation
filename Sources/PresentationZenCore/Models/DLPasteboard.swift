//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DLPasteboard.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

#if os(iOS) || os(visionOS)
import UIKit
/// The platform clipboard type: `UIPasteboard` on iOS and visionOS.
public typealias DLPasteboard = UIPasteboard

public extension DLPasteboard {

    /// The clipboard shared across apps.
    static var system: DLPasteboard { .general }

    /// The text on the clipboard, if any.
    var copiedText: String? { string }

    /// Replaces the clipboard's contents with text.
    ///
    /// - Parameter text: The text to copy.
    func copy(text: String) {
        string = text
    }
}

#elseif os(macOS)
import AppKit
/// The platform clipboard type: `NSPasteboard` on macOS.
public typealias DLPasteboard = NSPasteboard

public extension DLPasteboard {

    /// The clipboard shared across apps.
    static var system: DLPasteboard { .general }

    /// The text on the clipboard, if any.
    var copiedText: String? { string(forType: .string) }

    /// Replaces the clipboard's contents with text.
    ///
    /// - Parameter text: The text to copy.
    func copy(text: String) {
        clearContents()
        setString(text, forType: .string)
    }
}

#endif
