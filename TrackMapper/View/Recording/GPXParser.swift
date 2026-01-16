//
//  GPXParser.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/11/25.
//

import Foundation
import CoreLocation

class GPXParser: NSObject, XMLParserDelegate {
    private var coordinates: [Coordinate] = []
    private var currentElement = ""
    private var currentTimeString: String?
    private var foundFirstTime = false
    
    func parseGPX(data: Data) -> [Coordinate] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return coordinates
    }
    
    func extractTrackDate(from data: Data) -> Date? {
        currentTimeString = nil
        foundFirstTime = false
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        guard let timeStr = currentTimeString else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        return isoFormatter.date(from: timeStr)
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "trkpt",
           let latStr = attributeDict["lat"],
           let lonStr = attributeDict["lon"],
           let lat = Double(latStr),
           let lon = Double(lonStr) {
            let coord = Coordinate(x: lat, y: lon)
            coordinates.append(coord)
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "time", !foundFirstTime {
            currentTimeString = (currentTimeString ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "time" {
            foundFirstTime = true
        }
    }
}
