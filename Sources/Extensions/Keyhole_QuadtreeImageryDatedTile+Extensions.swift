//
//  Keyhole_QuadtreeImageryDatedTile+Extensions.swift
//
//
//  Created by Marcel Opitz on 07.01.24.
//

import Foundation

extension Keyhole_QuadtreeImageryDatedTile {
    func getDate() -> Date? {
        let components = DateComponents(
            year: Int(date >> 9),
            month: Int((date >> 5) & 0xf),
            day: Int(date & 0x1f))
        return Calendar.current.date(from: components)
    }
}

extension Keyhole_QuadtreeNode {
    func getAllDates() -> [Date] {
        layer
            .first(where: { layer in layer.type == .imageryHistory })?
            .datesLayer
            .datedTile
            .filter { tile in tile.provider != 0 && tile.date > 545 }
            .compactMap { tile in tile.getDate() } ?? []
    }
}
