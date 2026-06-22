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
//  BoxPlot.swift
//  
//
//  Created by Rodney Dyer on 4/4/24.
//

import Charts
import SwiftUI


public struct BoxPlot: View {
    
    var boxes: [BoxPlotPoint]
    var xLabel: String
    var yLabel: String
    var medianHeight: Double
    
    public init( data: [DataPoint], xLabel: String, yLabel: String, medianHeight: Double = 0.5 ) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        
        let cats = Array<String>( Set<String>(data.compactMap({$0.category})) )
        var theBoxes = [BoxPlotPoint]()
        for cat in cats {
            theBoxes.append(  BoxPlotPoint(points: data.filter({ $0.category == cat})) )
        }
        
        self.boxes = theBoxes.sorted(by: { $0.category < $1.category })
        self.medianHeight = medianHeight
    }
    
    
    public var body: some View {
        Chart {
            ForEach( boxes ) { item in
                
                // The Line
                BarMark(
                    x: .value("Category", item.category),
                    yStart: .value("BoxBottom", (item.median - 2.0*item.sd) ),
                    yEnd: .value("BoxBottom", (item.median + 2.0*item.sd) ),
                    width: .fixed( 3.0 )
                )
                .foregroundStyle( Color.secondary.opacity(0.75) )
                
                // The Box
                BarMark(
                    x: .value("Category", item.category),
                    yStart: .value("BoxBottom", (item.median - item.sd) ),
                    yEnd: .value("BoxBottom", (item.median + item.sd) )
                )

                
                // The Median
                BarMark(
                    x: .value("Category", item.category),
                    yStart: .value("BoxBottom", (item.median - medianHeight) ),
                    yEnd: .value("BoxBottom", (item.median + medianHeight) )
                )
                .foregroundStyle( Color.secondary.opacity(0.75) )

            }
        } 
        .chartXAxisLabel( position: .bottom,
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
    }
}
#if !SPM_BUILD

#Preview {
    BoxPlot( data: DataPoint.defaultDataPoints,
             xLabel: "Categories",
             yLabel: "Values"
    )
}
#endif
