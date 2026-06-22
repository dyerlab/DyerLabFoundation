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
//  Numberline.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 11/1/24.
//

import SwiftUI
import Charts


public struct NumberLine: View {
    var data: [DataPoint]
    var minX: Double
    var maxX: Double
    
    public init(data: [DataPoint], minX: Double = -1.0, maxX: Double = 1.0) {
        self.data = data
        self.minX = (minX * 1.1)
        self.maxX = (maxX * 1.1)
    }
    
    public var body: some View {
            Chart( data ) { item in
                PointMark(
                    x: .value("Amount", item.yValue),
                    y: .value("Period", 0.0)
                )
                .foregroundStyle(by: .value("Category", item.category))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 25)
            .fixedSize(horizontal: false, vertical: true)
            .chartXScale(domain: minX...maxX )
            .chartLegend(.hidden)
    }
}
#if !SPM_BUILD

#Preview {
    let data = [
        DataPoint(category: "First",
                  value: Double.random(in: -1.0...1.0)),
        DataPoint(category: "Second",
                  value: Double.random(in: -1.0...1.0)),
        DataPoint(category: "Third",
                  value: Double.random(in: -1.0...1.0)),
        DataPoint(category: "Fourth",
                  value: Double.random(in: -1.0...1.0)),
        DataPoint(category: "Fifth",
                  value: Double.random(in: -1.0...1.0)),
        DataPoint(category: "Sixth",
                  value: Double.random(in: -1.0...1.0)),
        DataPoint(category: "Seventh",
                  value: Double.random(in: -1.0...1.0)),
        
    ]
    NumberLine(data: data )
}
#endif
