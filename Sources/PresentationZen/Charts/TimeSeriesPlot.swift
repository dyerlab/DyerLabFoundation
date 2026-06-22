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
//  TimeSeriesPlot.swift
//  
//
//  Created by Rodney Dyer on 2024-04-03.
//

import Charts
import SwiftUI

public struct TimeSeriesPlot: View {
    public var data: [DataPoint]
    public var yLabel: String
    public var ordinal: Bool
    public var xLabel: String
    public var legendVisibility: Visibility {
        return categories.count < 2 ? .hidden : .automatic
    }
    
    public var soloColor: Color
    public var lineColor: Color
    
    private var categories: Set<String> {
        return Set<String>( data.compactMap({ $0.category } ) )
    }
    
    public init(data: [DataPoint], yLabel: String, xLabel: String = "", ordinal: Bool = false, ptColor: Color = .orange, lineColor: Color = .gray ) {
        self.data = data
        self.yLabel = yLabel
        self.ordinal = ordinal
        self.soloColor = ptColor
        self.lineColor = lineColor
        
        if xLabel.isEmpty {
            self.xLabel = self.ordinal == true ? "Ordinal" : "Date"
        } else {
            self.xLabel = xLabel
        }
            
    }
    
    public var body: some View {
        Chart {
            ForEach( data ) { item in
            
                if ordinal {
                    LineMark(
                        x: .value("X Value", item.xValue ),
                        y: .value(yLabel, item.yValue)
                    )
                    .foregroundStyle( lineColor )
                    .lineStyle( .init(dash: [5.0, 5.0 ]))
                    
                    if categories.count < 2 {
                        PointMark(
                            x: .value("X Value", item.xValue),
                            y: .value(yLabel, item.yValue)
                        )
                        .foregroundStyle( self.soloColor )
                    } else {
                        PointMark(
                            x: .value("X Value", item.xValue),
                            y: .value(yLabel, item.yValue)
                        )
                        .foregroundStyle(by: .value("Category", item.category) )
                    }
                    
                } else {
                    
                    if item.date != nil {
                        LineMark(
                            x: .value("X Value", item.date! ),
                            y: .value(yLabel, item.yValue)
                        )
                        .foregroundStyle( lineColor )
                        .lineStyle( .init(dash: [5.0, 5.0 ]))
                        
                        if categories.count < 2 {
                            PointMark(
                                x: .value("X Value", item.date!),
                                y: .value(yLabel, item.yValue)
                            )
                            .foregroundStyle( self.soloColor )
                        } else {
                            PointMark(
                                x: .value("X Value", item.date!),
                                y: .value(yLabel, item.yValue)
                            )
                            .foregroundStyle(by: .value("Category", item.category) )
                        }
                    }
                }
            }
        }
        .chartLegend( self.legendVisibility )
        .chartXAxisLabel(position: .bottom,
                         alignment: .center,
                         content: {
            Text("\(xLabel)")
                .font(.headline)
        } )
        .chartYAxisLabel(position: .trailing,
                         alignment: .center,
                         content: {
            Text(yLabel)
                .font(.title3)
        } )
        .frame( minHeight: 300)
        
    }
}
#if !SPM_BUILD

#Preview("Date") {
    TimeSeriesPlot(data: DataPoint.defaultDataPoints.sorted(),
                       yLabel: "Y-Axis Data" )
        .padding()
}

#Preview("Ordinal"){
    TimeSeriesPlot(data: DataPoint.defaultDataPoints.sorted(),
                   yLabel: "Y-Axis Data",
                   ordinal: true )
    .padding()
}


#Preview("No Categories") {
    TimeSeriesPlot(data: DataPoint.defaultDataPointsNoMetaData.sorted(),
                   yLabel: "Y-Axis Data",
                   ordinal: true )
    .padding()
}
#endif
