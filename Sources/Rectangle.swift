//
//  Rectangle.swift
//
//
//  Created by Marcel Opitz on 14.01.24.
//

import Foundation

public struct Rectangle {
    
    let lowerLeft: Coordinate
    let upperRight: Coordinate

    public init(lowerLeft: Coordinate, upperRight: Coordinate) {
        self.lowerLeft = lowerLeft
        self.upperRight = upperRight
    }
    
    public func getTileCount(for level: Int) -> Int {
        let lowerLeftTile = lowerLeft.getTile(level: level)
        let upperRightTile = lowerLeft.getTile(level: level)
        
        return (upperRightTile.row - lowerLeftTile.row + 1) * 
               (upperRightTile.column - lowerLeftTile.column + 1)
    }
    
    public func getTiles(for level: Int) -> [Tile] {
        let lowerLeftTile = lowerLeft.getTile(level: level)
        let upperRightTile = lowerLeft.getTile(level: level)
        
        var tiles = [Tile]()
        for row in lowerLeftTile.row...upperRightTile.row {
            for column in lowerLeftTile.column...upperRightTile.column {
                tiles.append(
                    Tile(
                        rowIndex: row,
                        colIndex: column,
                        level: level
                    )
                )
            }
        }
        return tiles
    }
}
