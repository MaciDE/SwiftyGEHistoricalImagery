//
//  Tile.swift
//
//
//  Created by Marcel Opitz on 14.01.24.
//

import Foundation

public struct Tile {
    
    let level: Int
    let row: Int
    let column: Int
    let qtPath: String
  
    let lowerLeft: Coordinate
    let lowerRight: Coordinate
    let upperLeft: Coordinate
    let upperRight: Coordinate
    let center: Coordinate
  
    public init(
        rowIndex: Int,
        colIndex: Int,
        level: Int
    ) {
        self.row = rowIndex
        self.column = colIndex
        self.level = level
        
        var chars = [Character](repeating: " ", count: level+1)
        
        var rowIndex = rowIndex
        var colIndex = colIndex
        
        for i in stride(from: level, to: -1, by: -1) {
            let row = rowIndex & 1
            let col = colIndex & 1
            
            rowIndex >>= 1
            colIndex >>= 1
            chars[i] = Character(UnicodeScalar(row << 1 | (row ^ col) | 0x30)!)
        }
        self.qtPath = String(chars)
      
        self.lowerLeft = .init(
            latitude: Tile.rowColToLatLong(rowCol: Double(row), level: level),
            longitude: Tile.rowColToLatLong(rowCol: Double(column), level: level))
        self.lowerRight = .init(
            latitude: Tile.rowColToLatLong(rowCol: Double(row), level: level),
            longitude: Tile.rowColToLatLong(rowCol: Double(column + 1), level: level))
        self.upperLeft = .init(
            latitude: Tile.rowColToLatLong(rowCol: Double(row + 1), level: level),
            longitude: Tile.rowColToLatLong(rowCol: Double(column), level: level))
        self.upperRight = .init(
            latitude: Tile.rowColToLatLong(rowCol: Double(row + 1), level: level),
            longitude: Tile.rowColToLatLong(rowCol: Double(column + 1), level: level))
        self.center = .init(
            latitude: Tile.rowColToLatLong(rowCol: Double(row) + 0.5, level: level),
            longitude: Tile.rowColToLatLong(rowCol: Double(column) + 0.5, level: level))
    }
    
    private static func rowColToLatLong(rowCol: Double, level: Int) -> Double {
        return rowCol * 360.0 / Double(1 << level) - 180
    }
}

extension Tile: CustomStringConvertible {
    public var description: String {
        return "\(level):, \(column), \(row)"
    }
}
