//
//  Coordinate.swift
//
//
//  Created by Marcel Opitz on 14.01.24.
//

import Foundation

public struct Coordinate {
    
    let latitude: Double
    let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public func getTile(level: Int) -> Tile {
        return Tile(
            rowIndex: latLongToRowCol(latLong: latitude, level: level),
            colIndex: latLongToRowCol(latLong: longitude, level: level),
            level: level)
    }
            
    private func latLongToRowCol(latLong: Double, level: Int) -> Int {
        return Int(floor((latLong + 180) / 360 * Double(1 << level)))
    }
}

extension Coordinate: CustomStringConvertible {
    public var description: String {
        return "\(latitude):F7,\(longitude):F7"
    }
}
