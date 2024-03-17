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
        qtPath = String(chars)
    }
    
    private func rowColToLatLong(rowCol: Double) -> Double {
        return rowCol * 360.0 / Double(1 << level) - 180
    }
}

extension Tile: CustomStringConvertible {
    public var description: String {
        return "\(level):, \(column), \(row)"
    }
}
