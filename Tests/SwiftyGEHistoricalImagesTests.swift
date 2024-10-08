import XCTest
@testable import SwiftyGEHistoricalImagery
import Foundation

final class SwiftyGEHistoricalImageryTests: XCTestCase {
    
    private let client = SwiftyGEHistoricalImageryClient(cacheDirPath: "./cache")
    
    func testInfo() async {
        let coordinate = Coordinate(latitude: 37.33490113725751, longitude: -122.00898691413386)
        let zoomLevel: Int? = 21
        
        var info: [TileInformation]?
        
        do {
            info = try await client.getInfo(for: coordinate, zoomLevel: zoomLevel)
        } catch {
            print(error)
            XCTFail()
        }
      
        XCTAssertNotNil(info)

        let expected = "[provider = 255, date = 2016-02-28 23:00:00 +0000, version = 279, zoomLevel = 21, provider = 255, date = 2017-04-29 22:00:00 +0000, version = 279, zoomLevel = 21, provider = 255, date = 2018-03-29 22:00:00 +0000, version = 279, zoomLevel = 21, provider = 255, date = 2020-09-29 22:00:00 +0000, version = 291, zoomLevel = 21, provider = 255, date = 2022-03-29 22:00:00 +0000, version = 346, zoomLevel = 21, provider = 400, date = 2023-05-29 22:00:00 +0000, version = 346, zoomLevel = 21, provider = 0, date = 2023-08-30 22:00:00 +0000, version = 348, zoomLevel = 21]"
        
        XCTAssertTrue(info!.description == expected)
    }
    
    func testAvailability() async {
        let lowerLeft: Coordinate  = Coordinate(latitude: -54.068089422258225, longitude: -37.16485689231956)
        let upperRight: Coordinate = Coordinate(latitude: -54.065470231859884, longitude: -37.15962122032249)
        let zoomLevel = 15
        
        var availability: [Date]?
        
        do {
            availability = try await client.getAvailability(lowerLeft: lowerLeft, upperRight: upperRight, zoomLevel: zoomLevel)
        } catch {
            print(error)
            XCTFail()
        }
        
        XCTAssertNotNil(availability)
        
        guard !availability!.isEmpty else {
            print("No dated imagery at zoom level: \(zoomLevel)")
            return
        }
        
        let expected = "[2003-02-01 23:00:00 +0000, 2006-03-14 23:00:00 +0000, 2009-10-21 22:00:00 +0000, 2011-02-27 23:00:00 +0000]"

        XCTAssertTrue(availability!.description == expected)
    }
}
