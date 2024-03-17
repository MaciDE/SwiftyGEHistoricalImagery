//
//  SwiftyGEHistoricalImageryClient.swift
//
//
//  Created by Marcel Opitz on 14.01.24.
//

import Foundation

public struct TileInformation {
    let provider: Int32
    let date: Date
    let version: Int32
}

extension TileInformation: CustomDebugStringConvertible {
    public var debugDescription: String {
        "provider = \(provider), date = \(date), version = \(version)"
    }
}

public class SwiftyGEHistoricalImageryClient {
    
    public let urlSession: URLSession
    public let cacheDirPath: String
    
    public init(urlSession: URLSession = .shared, cacheDirPath: String) {
        self.urlSession = urlSession
        self.cacheDirPath = cacheDirPath
    }
    
    /// Get imagery info at a specific location
    public func getInfo(
        for coordinate: Coordinate,
        zoomLevel: Int
    ) async throws -> [TileInformation]? {
        let root = try await DbRoot.create(urlSession: urlSession, cacheDir: cacheDirPath)
        
        let startLevel = zoomLevel
        let endLevel = zoomLevel
        
        guard startLevel <= endLevel else {
            return nil
        }
        
        var tileInfos: [TileInformation] = []
        
        for level in startLevel...endLevel {
            let tile = coordinate.getTile(level: level)
            let node = await root.getNode(path: tile.qtPath)
            
            guard let hLayer = (node?.layer.first(where: { layer in layer.type == .imageryHistory }) as? Keyhole_QuadtreeLayer) else {
                NSLog("No available imagery at zoomLevel: \(zoomLevel)")
                break
            }
            
            for datedTile in hLayer.datesLayer.datedTile {
                guard let date = datedTile.getDate() else {
                    continue
                }
                let year = Calendar.current.component(.year, from: date)
                guard year != 1 else {
                    continue
                }
                
                tileInfos.append(
                    .init(
                        provider: datedTile.provider,
                        date: date,
                        version: datedTile.datedTileEpoch))
            }
        }
        
        return tileInfos
    }
    
    /// Get imagery date availability in a specific region
    public func getAvailability(
        lowerLeft: Coordinate,
        upperRight: Coordinate, 
        zoomLevel: Int
    ) async throws -> [Date]? {
        func getAllDates(root: DbRoot, aoi: Rectangle, zoomLevel: Int) async -> [Date] {
            let tiles = aoi.getTiles(for: zoomLevel)
            
            var entries = [(tile: Tile, qtNode: Keyhole_QuadtreeNode?)]()
            await withTaskGroup(of: (Tile, Keyhole_QuadtreeNode?).self) { group in
                for tile in tiles {
                    group.addTask {
                        let qtNode = await root.getNode(path: tile.qtPath)
                        return (tile, qtNode)
                    }
                }
                for await pair in group {
                    entries.append(pair)
                }
            }
            return entries.compactMap { $0.qtNode?.getAllDates() }.flatMap { $0 }
        }
        
        let aoi = Rectangle(lowerLeft: lowerLeft, upperRight: upperRight)
        let root = try await DbRoot.create(urlSession: urlSession, cacheDir: cacheDirPath)
        return await getAllDates(root: root, aoi: aoi, zoomLevel: zoomLevel)
    }
}
