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
//  Array+DataPoint.swift
//
//
//  Created by Rodney Dyer on 2024-02-16.
//

import Foundation


public extension Array where Element == DataPoint {

    /// Minimum values
    ///
    /// - Returns: minimum ``DataPoint`` values or Double.infinity
    var minimum: DataPoint {
        var ret = DataPoint(x: Double.infinity,
                            y: Double.infinity )
        for item in self {
            if item.xValue < ret.xValue {
                ret.xValue = item.xValue
            }
            if item.yValue < ret.yValue {
                ret.yValue = item.yValue
            }
        }
        return ret
    }
    
    /// Maximum values
    ///
    /// - Returns: ``DataPoint`` with maximum values in array or Double.infinity
    var maximum: DataPoint {
        var ret = DataPoint(x: -Double.infinity,
                            y: -Double.infinity )
        for item in self {
            if item.xValue > ret.xValue {
                ret.xValue = item.xValue
            }
            if item.yValue > ret.yValue {
                ret.yValue = item.yValue
            }
        }
        return ret
    }
    
    
    
    /// Gets trendline end points for specificed line.
    ///
    /// This takes the data in the array of ``DataPoint`` objects and returns the endpoints for a
    ///  trendline defined by the slope and intercept passed to the function.
    ///
    /// - Parameters:
    ///     - intercept: A ``Double`` indicating where the line intercepts the y-axis at x=0.0
    ///     - slope: A ``Double`` indicates the slope of the trendline.
    /// - Returns: The pair of points for line from minimum X to maximum X.
    func trendlinePoints(intercept: Double, slope: Double) -> [DataPoint] {
        let mn = self.minimum
        let mx = self.maximum
        
        let pt1 = DataPoint(x: mn.xValue,
                            y: mn.xValue * slope + intercept,
                            group: "Trendline" )
        
        let pt2 = DataPoint(x: mx.xValue,
                            y: mx.xValue * slope + intercept,
                            group: "Trendline" )
        
        return [pt1, pt2]
    }
    
    
    /// Convert raw data to vector for histogram
    ///
    /// This takes a raw set of data and returns a new set where the y-value is the c
    ///   count of observations in the binned values of the x-axis data.
    ///
    ///  - Parameters:
    ///     - numBins: The number of bins to create.  An additional one will be
    ///  - Returns: A new set of data with counts as each bin.
    func histogram( numBins: Int = 10 ) -> [DataPoint] {
        var ret = [DataPoint]()
        
        if self.count == 0 {
            return ret
        }
        
        let values = self.compactMap({ $0.yValue } ).sorted()
        
        if let dataMin = values.min(),
           let dataMax = values.max() {
            let span = dataMax - dataMin

            guard span > 0 else {
                // All values identical — single bin with full count
                ret.append( DataPoint(x: dataMin - 1, y: 0) )
                ret.append( DataPoint(x: dataMin, y: Double(values.count)) )
                ret.append( DataPoint(x: dataMin + 1, y: 0) )
                return ret
            }

            var current = dataMin
            let binSize = span / Double( numBins )

            ret.append( DataPoint(x: (current - binSize), y: 0) )

            while current <= dataMax {
                let ct = values.filter( { ($0 >= current) && ($0 < current + binSize ) } ).count
                ret.append( DataPoint( x: current, y: Double( ct ) ) )
                current += binSize
            }
            ret.append( DataPoint(x: (dataMax + binSize), y: 0) )

        }
        
        return ret
    }
    
    /// Average of `yValue` across all points.
    ///
    /// Returns `.nan` if the array is empty.
    var yMean: Double {
        guard !self.isEmpty else { return .nan }
        return self.map(\.yValue).reduce(0, +) / Double(self.count)
    }

    /// Creates a frequency distribution for integer-bucketed `yValue` data.
    ///
    /// Rounds each `yValue` to the nearest integer, counts occurrences within the
    /// given range, and returns one ``DataPoint`` per bucket with `category` as
    /// the bucket label and `yValue` as the count.
    ///
    /// - Parameter range: The closed integer range of buckets (e.g. `1...5` for Likert).
    /// - Returns: An array of ``DataPoint`` with one entry per integer in the range.
    func frequencyDistribution(range: ClosedRange<Int>) -> [DataPoint] {
        var counts = [Int: Int]()
        for i in range {
            counts[i] = 0
        }
        for item in self {
            let bucket = Int(item.yValue.rounded())
            if range.contains(bucket) {
                counts[bucket, default: 0] += 1
            }
        }
        return range.map { bucket in
            DataPoint(category: "\(bucket)", value: Double(counts[bucket] ?? 0))
        }
    }

    var collapseByYear: [DataPoint] {
        
        var pts = Set<DataPoint>()
        
        for item in self {
            
            if let date = item.date {
               let year = date.get( .year )
                let newPt: DataPoint
                
                if let pt = pts.first( where: { $0.xValue == Double( year ) } ) {
                    newPt = DataPoint(x: Double(year), y: pt.yValue + item.yValue)
                    pts.remove( pt )
                } else {
                    newPt = DataPoint(x: Double(year), y: item.yValue )
                }
                pts.insert( newPt )
            }
            
            
        }
        return Array( pts ).sorted()
    }
    
}

