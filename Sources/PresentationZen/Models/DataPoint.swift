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
//  DataPoint.swift
//
//
//  Created by Rodney Dyer on 2024-02-16.
//

import Foundation

public struct DataPoint: Identifiable, Hashable {
    public let id = UUID()
    public let label: String
    public var category: String
    public var grouping: String
    public var xValue: Double
    public var yValue: Double
    public var date: Date?
    
    /// Default x,y point initializer
    public init(x: Double, y: Double, label: String = "", group: String = "", category: String = "") {
        self.xValue = x
        self.yValue = y
        self.label = label
        self.grouping = group
        self.category = category
    }
    
    /// Default category,y initializer
    public init( category: String, value: Double, label: String = "", group: String = "", date: Date? = nil ) {
        self.category = category
        self.yValue = value
        self.label = label
        self.grouping = group
        self.xValue = value
        self.date = date
    }
    
    /// Default temporal initializer
    /// You can set the xValue to numeric for ordinal display.
    public init( time: Date, value: Double, xValue: Double = Double.nan, category: String = "", group: String = "", label: String = "") {
        self.category = category
        self.yValue = value
        self.label = label
        self.grouping = group
        self.xValue = xValue
        self.date = time
    }
    
    public init( likertScore: Int, label: String ) {
        self.init(x: Double(likertScore), y: Double.nan, label: label)
    }
    
    public init( label: String, count: Int ) {
        self.init(x: Double(count), y: Double.nan, label: label )
    }
    
}


extension DataPoint: Comparable {
    
    public static func < (lhs: DataPoint, rhs: DataPoint) -> Bool {
        
        if let ldate = lhs.date, let rdate = rhs.date {
            return ldate < rdate
        } else {
            return lhs.xValue < rhs.xValue
        }
        
        
    }
}


extension DataPoint {
    
    public static var defaultDataPoints: [DataPoint] {
        var ret = [DataPoint]()
        for i in 0 ..< 10 {
            var pt = DataPoint( x: Double(i),
                                y: Double.random(in: 0.0...100.0),
                                label: String("Label \(i+1)"),
                                group: String("Group \( (i % 3) + 1)"),
                                category: String("Category \( (i % 2)+1)") )
            let time = Double(i) * Double.random(in: -86400.0 ... 0.0)
            pt.date = Date.now.addingTimeInterval( time )
            ret.append( pt )
            
        }
        return ret
    }

    
    public static var defaultDataPointsNoMetaData: [DataPoint] {
        var ret = [DataPoint]()
        for i in 0 ..< 10 {
            var pt = DataPoint( x: Double(i),
                                y: Double.random(in: 0.0...100.0),
                                label: String("Label \(i+1)"),
                                group: "",
                                category: "" )
            let time = Double(i) * Double.random(in: -86400.0 ... 0.0)
            pt.date = Date.now.addingTimeInterval( time )
            ret.append( pt )

        }
        return ret
    }
    
    
    public static var DefaultHistogramDataPoints: [DataPoint] {
        var ret = [DataPoint]()
        ret.append( DataPoint(x: 0, y: 0) )
        ret.append( DataPoint(x: 1, y: 2) )
        ret.append( DataPoint(x: 2, y: 3) )
        ret.append( DataPoint(x: 3, y: 8) )
        ret.append( DataPoint(x: 4, y: 18) )
        ret.append( DataPoint(x: 5, y: 20) )
        ret.append( DataPoint(x: 6, y: 22) )
        ret.append( DataPoint(x: 7, y: 17) )
        ret.append( DataPoint(x: 8, y: 6) )
        ret.append( DataPoint(x: 9, y: 4) )
        ret.append( DataPoint(x: 10, y: 2) )
        ret.append( DataPoint(x: 11, y: 0) )
        return ret
    }
    
}
