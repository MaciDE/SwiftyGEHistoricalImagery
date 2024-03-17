//
//  QtPacket.swift
//
//
//  Created by Marcel Opitz on 14.01.24.
//

import Foundation

protocol QuadtreePacket {
    func getChild(path: String) async -> QtPacket?
    func getIndexOfNode(path: String) -> Int?
}

class QtPacket: QuadtreePacket {
    
    let fullPath: String
    let packet: Keyhole_QuadtreePacket
    let dbRoot: DbRoot
    
    private(set) var parent: QtPacket?
    
    init(
        dbRoot: DbRoot,
        parent: QtPacket? = nil,
        path: String,
        packet: Keyhole_QuadtreePacket
    ) {
        self.dbRoot = dbRoot
        self.parent = parent
        self.fullPath = parent?.fullPath.appending(path) ?? path
        self.packet = packet
    }
    
    func getNode(path: String) async -> Keyhole_QuadtreeNode? {
        guard let child = await getChild(path: path) else {
            return nil
        }
        
        let remainderLength = path.count - child.fullPath.count
        guard remainderLength <= 4 && remainderLength >= 0 else {
            return nil
        }
        
        let remainder = String(path.suffix(remainderLength))
        guard let subIndex = child.getIndexOfNode(path: remainder) else {
            return nil
        }
        
        return (child.packet.sparseQuadtreeNode.filter { $0.index == subIndex }).first?.node
    }
    
    func getIndexOfNode(path: String) -> Int? {
        guard isQuadTreePathValid(path),
              path.count <= 4,
              !path.isEmpty
        else { return nil }
        
        var subIndex = 0
        for i in 1..<path.count {
            subIndex *= 4
            subIndex += Int(path[path.index(path.startIndex, offsetBy: i)].asciiValue!) - 0x30 + 1
        }
        subIndex += (Int(path[path.startIndex].asciiValue!) - 0x30) * 85 + 1
        return subIndex
    }
    
    func getChild(path: String) async -> QtPacket? {
        guard isQuadTreePathValid(path) else {
            return nil
        }
        
        guard path.starts(with: fullPath) else {
            return await parent?.getChild(path: path)
        }
        
        guard path.count - fullPath.count > 4 else {
            return self
        }
        
        let subRange = fullPath.endIndex..<path.index(fullPath.endIndex, offsetBy: 4)
        let sub = String(path[subRange])
        
        if let child = await getInternalChild(subPath: sub) {
            return await child.getChild(path: path)
        } else {
            return nil
        }
    }
    
    func getInternalChild(subPath: String) async -> QtPacket? {
        func loadChildPacket(
            path: String,
            subPath: String,
            packet: Keyhole_QuadtreePacket
        ) async -> QtPacket? {
            guard let subIndex = getIndexOfNode(path: subPath) else {
                return nil
            }
            
            if let childNode: Keyhole_QuadtreeNode = packet.sparseQuadtreeNode.first(
                where: {
                    $0.node.cacheNodeEpoch != 0 && $0.index == subIndex }
                )?.node
            {
                let childPacket = await dbRoot.getPacket(
                    path: path,
                    epoch: Int(childNode.cacheNodeEpoch)
                )
                return QtPacket(
                    dbRoot: dbRoot,
                    parent: self,
                    path: subPath,
                    packet: childPacket
                )
            }
            return nil
        }
        
        guard let cachedValue = dbRoot.packetCache.value(forKey: fullPath + subPath) else {
            guard let packet = await loadChildPacket(
                path: fullPath + subPath,
                subPath: subPath,
                packet: packet
            ) else { return nil }
            dbRoot.packetCache.insert(packet, forKey: fullPath + subPath)
            return packet
        }
        return cachedValue
    }
    
    func isQuadTreePathValid(_ path: String) -> Bool {
        for char in path {
            guard char == "0" || char == "1" || char == "2" || char == "3" else {
                return false
            }
        }
        return true
    }
}
