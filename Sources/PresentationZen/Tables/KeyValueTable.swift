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
//  KeyValueTable.swift
//
//
//  Created by Rodney Dyer on 2/10/24.
//
import SwiftUI

public struct KeyValueTable: View {
    public var data: [DataPoint]
    public var columnTypes: [DataColumnType]
    public var columnHeaders: [String] = [ "Category Label",
                                           "Grouping Label",
                                           "Label",
                                           "X Value",
                                           "Y Value",
                                           "Date" ]
    public var formatString: String
    public var minColWidth: Double
    
    private var inScrollView: Bool
    
    public init( data: [DataPoint],
                 columnTypes: [DataColumnType],
                 columnHeaders: [String],
                 formatString: String = "%.4f",
                 minColWidth: Double = 150,
                 inScrollView: Bool = true ) {
        self.data = data
        self.columnTypes = columnTypes
        self.columnHeaders = columnHeaders
        self.formatString = formatString
        self.minColWidth = minColWidth
        self.inScrollView = inScrollView
    }
    
    var columns: [GridItem] {
        var ret = [GridItem]()
        for _ in 0 ..< columnTypes.count {    
                ret.append( GridItem(.flexible(minimum: minColWidth, maximum: .infinity) ) )
        }
        return ret
    }
    
    
    var tableContent: some View {
        LazyVGrid( columns: self.columns, content: {
            ForEach( 0..<columnTypes.count, id: \.self ) { idx in
                    Text("\(columnHeaders[idx])")
                        .frame(alignment: .leading)
                        .font(.headline)
            }
            ForEach( data ) { item in
                ForEach( columnTypes, id: \.self  ) { type in
                    
                    switch( type ) {
                    case .grouping:
                        Text("\(item.grouping)")
                            .frame(alignment: .leading)
                            .lineLimit(1)
                    case .label:
                        Text("\(item.label)")
                            .frame(alignment: .leading)
                            .lineLimit(1)
                    case .category:
                        Text("\(item.category)")
                            .frame(alignment: .leading)
                            .lineLimit(1)
                    case .xValue:
                        Text("\(item.xValue, specifier: formatString)")
                            .frame(alignment: .leading)
                            .lineLimit(1)
                    case .yValue:
                        Text("\(item.yValue, specifier: formatString)")
                            .frame(alignment: .leading)
                            .lineLimit(1)
                    case .date:
                        Text(item.date ?? .now, style: .date )
                            .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        
                    }
                }
            }
        })
    }
    
    
    public var body: some View {
            if inScrollView {
                ScrollView( [.horizontal, .vertical]) {
                    tableContent
                }
            } else {
                tableContent
                    .padding()
            }
    }
}
#if !SPM_BUILD

#Preview("Full") {
    KeyValueTable( data: DataPoint.defaultDataPoints,
                   columnTypes: [.grouping, .label, .category, .xValue, .yValue],
                   columnHeaders: ["Grouping Label","Label","Category Label","X Value","Y Value"] )
}

#Preview("Second") {
    KeyValueTable( data: DataPoint.defaultDataPoints,
                   columnTypes: [ .label, .xValue, .grouping,  .yValue],
                   columnHeaders: ["Label","X","Grouping","Y Value"] )
}


#Preview("Third") {
    KeyValueTable( data: DataPoint.defaultDataPoints,
                   columnTypes: [.date, .xValue],
                   columnHeaders: ["Date", "X Value"],
                   formatString: "%0.0f",
                   minColWidth: 200 )
}


#Preview("No Scrollview") {
    KeyValueTable( data: DataPoint.defaultDataPoints,
                   columnTypes: [.date, .xValue],
                   columnHeaders: ["Date", "X Value"],
                   formatString: "%0.0f",
                   minColWidth: 200,
                   inScrollView: false )
}

#Preview("No Scrollview & Small Width") {
    KeyValueTable( data: DataPoint.defaultDataPoints,
                   columnTypes: [.grouping, .label, .category, .xValue, .yValue],
                   columnHeaders: ["Grouping Label","Label","Category Label","X Value","Y Value"],
                   formatString: "%0.0f",
                   minColWidth: 100,
                   inScrollView: false)
}
#endif
