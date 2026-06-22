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
//  Media.swift
//  Objectives
//
//  Created by Rodney Dyer on 3/2/25.
//

import Foundation
import SwiftData

/// The media object for storing images
@Model
public class Media: Codable {
    
    /// The default id
    public var id: UUID = UUID()
    
    /// Image data from pngData
    @Attribute(.externalStorage) public var imageData: Data? = nil
    
    /// The date of the media
    public var date: Date = Date.now
    
    /// Default Initializer
    /// - Parameters:
    ///   - date: The date for the media object.  This must be the same that the ``Event`` date.
    ///   - imageData: Raw data from image as pngData.
    public init(date: Date = .now, imageData: Data? = nil) {
        self.imageData = imageData
        self.date = date
    }
    
    /// Coding Keys
    enum CodingKeys: CodingKey {
        case id
        case imageData
        case date
    }
    
    /// Required initializer for Codable
    /// - Parameter decoder: The passed decoder
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        date = try container.decode(Date.self, forKey: .date)
    }
    
    /// Required encoder
    /// - Parameter encoder: The encoder
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(date, forKey: .date)
    }
}





