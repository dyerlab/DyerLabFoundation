//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationLink+macOS.swift
//  Documentation
//
//  The help button on the Mac: the system’s round (?) button.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if os(macOS)
import SwiftUI

extension DocumentationLink: View {
    /// The button, or nothing when the help has no such topic.
    public var body: some View {
        if let entry {
            HelpLink(action: open)
                .help("Help: \(entry.title)")
        }
    }
}
#endif
