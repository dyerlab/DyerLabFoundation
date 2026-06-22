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
//  ScatterPlot.swift
//
//
//  Created by Rodney Dyer on 2/10/24.
//

import Charts
import SwiftUI

public struct ScatterPlot: View {
    public var data: [DataPoint]
    public var xLabel: String
    public var yLabel: String
    public var showLabel: Bool
    public var showGroups: Bool
    
    public init(data: [DataPoint], xLabel: String, yLabel: String, showLabel: Bool = false , showGroups: Bool = false ) {
        self.data = data
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.showLabel = showLabel
        self.showGroups = showGroups
    }
    
    public var body: some View {
        Chart {
            ForEach( data, id: \.self) { item in
                if showLabel {
                    if showGroups {
                        PointMark(
                            x: .value("X Value", item.xValue  ),
                            y: .value("Y Value", item.yValue ) )
                        .foregroundStyle(by: .value( "Group",
                                                     item.grouping ) )
                        .annotation {
                            Text("\(item.label )")
                                .font( .footnote )
                               // .rotationEffect( Angle(degrees: -30), anchor: .bottomLeading)
                        }
                    } else {
                        PointMark(
                            x: .value("X Value", item.xValue  ),
                            y: .value("Y Value", item.yValue ) )
                        .annotation {
                            Text("\(item.label )")
                                .font( .footnote )
                        }
                    }
                } else {
                    if showGroups {
                        PointMark(
                            x: .value("X Value", item.xValue  ),
                            y: .value("Y Value", item.yValue ) )
                        .foregroundStyle(by: .value("Group", showGroups ? item.grouping : "" ) )
                    } else {
                        PointMark(
                            x: .value("X Value", item.xValue  ),
                            y: .value("Y Value", item.yValue ) )
                    }
                }
            }
        }
        .chartXAxisLabel(position: .bottom,
                         alignment: .center,
                         content: {
            Text(xLabel)
                .font(.title3)
        } )
        .chartYAxisLabel(position: .trailing,
                         alignment: .center,
                         content: {
            Text(yLabel)
                .font(.title3)
        } )
        .chartLegend(position: .top)
    }
}
#if !SPM_BUILD

#Preview {
    ScrollView {
        
        
        VStack(spacing: 25) {
            ScatterPlot( data: DataPoint.defaultDataPoints,
                         xLabel: "Default X-Axis Label",
                         yLabel: "Default Y-Axis Label" )
            
            ScatterPlot( data: DataPoint.defaultDataPoints,
                         xLabel: "Default X-Axis Label",
                         yLabel: "Default Y-Axis Label",
                         showLabel: true )
            
            ScatterPlot( data: DataPoint.defaultDataPoints,
                         xLabel: "Default X-Axis Label",
                         yLabel: "Default Y-Axis Label",
                         showGroups: true )
            
            ScatterPlot( data: DataPoint.defaultDataPoints,
                         xLabel: "Default X-Axis Label",
                         yLabel: "Default Y-Axis Label",
                         showLabel: true,
                         showGroups: true  )
        }
        .frame( minHeight: 800 )
    }
    .padding()
}
#endif
