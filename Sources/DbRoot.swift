//
//  DbRoot.swift
//
//
//  Created by Marcel Opitz on 07.01.24.
//

import Compression
import Foundation
import SwiftProtobuf

enum InvalidDataError: Error {
    case failedToDeterminePacketSize
}

public class DbRoot {
    
    private static let qp2URL = "https://khmdb.google.com/flatfile?db=tm&qp-%@-q.%@"
    private static let rootURL = "https://khmdb.google.com/dbRoot.v5?db=tm&hl=en&gl=us&output=proto"
    
    let urlSession: URLSession
    private let packetCacheURL: URL
    private let encryptionCipher: Data
   
    private var buffer: Keyhole_Dbroot_DbRootProto?
    private var root: QtPacket?
    
    let packetCache = Cache<String, QtPacket>()
    
    init(
        urlSession: URLSession,
        encryptedDbRoot: Keyhole_Dbroot_EncryptedDbRootProto,
        packetCacheURL: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    ) throws {
        self.urlSession = urlSession
        self.encryptionCipher = encryptedDbRoot.encryptionData
        self.packetCacheURL = packetCacheURL ?? FileManager.default.temporaryDirectory
        
        let decryptedDbRootData = decrypt(
            encryptedDbRoot.dbrootData, using: encryptedDbRoot.encryptionData)
        self.buffer = try decodeBufferInternal(packet: decryptedDbRootData)
    }

    static func create(
        urlSession: URLSession,
        cacheDir: String = "./cache"
    ) async throws -> DbRoot {
        let uri = URL(string: rootURL)!
        let cacheDirURL = URL(fileURLWithPath: cacheDir)
        if !FileManager.default.fileExists(atPath: cacheDir, isDirectory: nil) {
            try FileManager.default.createDirectory(
                at: cacheDirURL,
                withIntermediateDirectories: true,
                attributes: nil)
        }

        var request = URLRequest(url: uri)
        request.httpMethod = "GET"

        let dbRootFileURL = cacheDirURL.appendingPathComponent(uri.lastPathComponent)
        if let lastWriteTime = try? dbRootFileURL.resourceValues(
            forKeys: [.contentModificationDateKey]).contentModificationDate
        {
            request.addValue(
                DateFormatter.rfc1123.string(from: lastWriteTime),
                forHTTPHeaderField: "If-Modified-Since")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let response = response as? HTTPURLResponse else {
                throw InvalidDataError.failedToDeterminePacketSize
            }
            
            var dbRootBts: Data
            if FileManager.default.fileExists(atPath: dbRootFileURL.path),
               response.statusCode == 304
            {
                NSLog("Load file from cache at \(dbRootFileURL.absoluteString)")
                dbRootBts = try Data(contentsOf: dbRootFileURL)
            } else {
                dbRootBts = data

                do {
                    try dbRootBts.write(to: dbRootFileURL)

                    if let lastModified = response.allHeaderFields["Last-Modified"] as? String,
                       let lastModifiedDate = DateFormatter.rfc1123.date(from: lastModified) 
                    {
                        try FileManager
                                .default
                                .setAttributes(
                                    [.modificationDate: lastModifiedDate],
                                    ofItemAtPath: dbRootFileURL.path
                                )
                    }
                } catch {
                    print("Failed to cache \(dbRootFileURL.path).")
                    print(error.localizedDescription)
                }
            }
            let encryptedDbRoot = try Keyhole_Dbroot_EncryptedDbRootProto(serializedData: dbRootBts)
            return try DbRoot(urlSession: urlSession, encryptedDbRoot: encryptedDbRoot)
        } catch {
            print("Error: \(error)")
            throw error
        }
    }
    
    func getRootPacket() async -> QtPacket {
        guard root == nil else { return root! }
        guard let buffer else { return root! }
        let packet = await getPacket(
            path: "0",
            epoch: Int(buffer.databaseVersion.quadtreeVersion))
        return QtRoot(dbRoot: self, packet: packet)
    }

    func getNode(path: String) async -> Keyhole_QuadtreeNode? {
        let root = await getRootPacket()
        return await root.getNode(path: path)
    }
    
    func getPacket(path: String, epoch: Int) async -> Keyhole_QuadtreePacket {
        do {
            let packetData = try await downloadBytes(
                url: String(format: DbRoot.qp2URL, path, String(epoch)))
            return try decodeBufferInternal(packet: packetData)
        } catch {
            print(error)
            fatalError()
        }
    }
    
    func downloadBytes(url: String) async throws -> Data {
        let uri = URL(string: url)!
        let fileName = packetCacheURL
            .appendingPathComponent("\(uri.lastPathComponent)-\(uri.query!)")
            .path
        if FileManager.default.fileExists(atPath: fileName) {
            return try! Data(contentsOf: URL(fileURLWithPath: fileName))
        } else {
            let data = try! await urlSession.data(from: uri)
            let decryptedData = decrypt(data.0, using: encryptionCipher)
            do {
                try decryptedData.write(to: URL(fileURLWithPath: fileName))
            } catch {
                NSLog("Failed to Cache \(uri.path).")
                print(error.localizedDescription)
            }

            return decryptedData
        }
    }

    private func decodeBufferInternal<T: SwiftProtobuf.Message & SwiftProtobuf._MessageImplementationBase>(
        packet: Data
    ) throws -> T {
        guard let bufferSize = tryGetDecompressBufferSize(buff: packet) else {
            throw InvalidDataError.failedToDeterminePacketSize
        }
        
        let decompressedData = try decompress(packet, size: bufferSize)
        return try T(serializedData: decompressedData)
    }
    
    func decompress(_ data: Data, size: Int) throws -> Data {
        let data = data.dropFirst(8+2) as Data
        return (try (data as NSData).decompressed(using: .zlib)) as Data
    }
    
    func tryGetDecompressBufferSize(buff: Data) -> Int? {
        let kPacketCompressHdrSize: Int = 8
        let kPktMagic: UInt32 = 0x7468dead
        let kPktMagicSwap: UInt32 = 0xadde6874
        
        guard buff.count >= kPacketCompressHdrSize else {
            return 0
        }
        
        let intBuf = buff.withUnsafeBytes { ptr in
            ptr.bindMemory(to: UInt32.self)
        }
        
        if intBuf[0] == kPktMagic {
            return Int(intBuf[1])
        } else if intBuf[0] == kPktMagicSwap {
            let len = intBuf[1]
            let v = ((len >> 24) & 0x00000ff) |
                    ((len >> 8) & 0x0000ff00) |
                    ((len >> 8) & 0x00ff0000) |
                    ((len >> 24) & 0xff000000)
            return Int(v)
        }
        return nil
    }
    
    private func decrypt(_ cipher: Data, using key: Data) -> Data {
        return encode(cipher, using: key)
    }
    
    private func encode(_ cipher: Data, using key: Data) -> Data {
        var off = 16
        var encrypted = cipher
        
        for j in 0..<encrypted.count {
            encrypted[j] ^= key[off]
            off += 1
            
            if (off & 7) == 0 {
                off += 16
            }
            if off >= key.count {
                off = (off + 8) % 24
            }
        }
        return encrypted
    }

    class QtRoot: QtPacket {
        init(dbRoot: DbRoot, packet: Keyhole_QuadtreePacket) {
            super.init(dbRoot: dbRoot, path: "0", packet: packet)
        }
        
        override func getChild(path: String) async -> QtPacket? {
            guard isQuadTreePathValid(path) else {
                return nil
            }
            
            guard path.count >= 1, path.first == "0" else {
                fatalError("Paths must begin with '0'.")
            }

            guard path.count > 4 else { return self }

            let startIndex = path.index(path.startIndex, offsetBy: 1)
            let endIndex = path.index(path.startIndex, offsetBy: 4)
            let sub = String(path[startIndex..<endIndex])

            if let child = await getInternalChild(subPath: sub) {
                return await child.getChild(path: path)
            } else {
                return nil
            }
        }
        
        override func getIndexOfNode(path: String) -> Int? {
            guard isQuadTreePathValid(path),
                  path.count <= 3
            else { return nil }
            
            guard !path.isEmpty else { return 0 }
            
            var subIndex = 0
            for char in path {
                subIndex *= 4
                subIndex += Int(char.asciiValue!) - 0x30 + 1
            }
            return subIndex
        }
    }
}
