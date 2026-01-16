import Foundation
import CoreLocation

enum GPXUtilsError: Error {
    case stringToDataFailed
    case dataToStringFailed
    case parseFailed
}

struct GPXStats: Equatable {
    let distanceMeters: Double
    /// Elapsed time in seconds. 0 if the GPX has no (parsable) timestamps.
    let elapsedTime: TimeInterval
    /// Total ascent in meters computed from consecutive `<trkpt><ele>` deltas.
    let elevationGainMeters: Double
    /// Total descent in meters computed from consecutive `<trkpt><ele>` deltas.
    let elevationLossMeters: Double
    /// Start date/time of the activity (earliest `<trkpt><time>`), nil if missing/unparseable.
    let startDate: Date?
}

enum GPXUtils {
    static func gpxData(from gpxString: String) throws -> Data {
        guard let data = gpxString.data(using: .utf8) else {
            throw GPXUtilsError.stringToDataFailed
        }
        return data
    }
    
    static func gpxString(from data: Data) throws -> String {
        guard let str = String(data: data, encoding: .utf8) else {
            throw GPXUtilsError.dataToStringFailed
        }
        return str
    }
    
    /// Parses the GPX once and returns distance + elapsed time stats.
    /// - distanceMeters: sum of consecutive `<trkpt lat=".." lon="..">` point distances in meters.
    /// - elapsedTime: seconds between the earliest and latest parsed `<trkpt><time>` values (0 if missing/unparseable).
    static func stats(from gpxString: String) throws -> GPXStats {
        let data = try gpxData(from: gpxString)
        
        let parserDelegate = GPXStatsParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        
        let ok = parser.parse()
        guard ok else {
            throw GPXUtilsError.parseFailed
        }
        
        return GPXStats(
            distanceMeters: parserDelegate.totalDistanceMeters,
            elapsedTime: parserDelegate.elapsedTimeSeconds,
            elevationGainMeters: parserDelegate.elevationGainMeters,
            elevationLossMeters: parserDelegate.elevationLossMeters,
            startDate: parserDelegate.startDate
        )
    }
    
    /// Convenience wrapper for callers that only need distance.
    static func totalDistanceMeters(from gpxString: String) throws -> Double {
        try stats(from: gpxString).distanceMeters
    }
    
    /// Appends a GPX file field to a multipart/form-data body.
    static func appendGPXField(
        to body: inout Data,
        boundary: String,
        gpxString: String,
        fieldName: String = "gpx",
        filename: String = "track.gpx"
    ) throws {
        let gpxData = try gpxData(from: gpxString)
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: application/gpx+xml\r\n\r\n")
        body.append(gpxData)
        body.appendString("\r\n")
    }
}

private final class GPXStatsParser: NSObject, XMLParserDelegate {
    fileprivate(set) var totalDistanceMeters: Double = 0
    fileprivate(set) var elapsedTimeSeconds: TimeInterval = 0
    fileprivate(set) var elevationGainMeters: Double = 0
    fileprivate(set) var elevationLossMeters: Double = 0
    var startDate: Date? { minTime }
    
    private var prevLocation: CLLocation?
    private var lastElevationMeters: Double?
    
    private var inTrkpt = false
    private var inTime = false
    private var timeBuffer = ""
    private var inEle = false
    private var eleBuffer = ""
    
    private var minTime: Date?
    private var maxTime: Date?
    
    private lazy var isoNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private lazy var isoWithFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if elementName == "trkpt" {
            inTrkpt = true
            guard
                let latStr = attributeDict["lat"],
                let lonStr = attributeDict["lon"],
                let lat = Double(latStr),
                let lon = Double(lonStr)
            else { return }
            
            let cur = CLLocation(latitude: lat, longitude: lon)
            if let prev = prevLocation {
                totalDistanceMeters += cur.distance(from: prev)
            }
            prevLocation = cur
            return
        }
        
        // Only consider <time> values inside <trkpt> to avoid metadata/other timestamps.
        if elementName == "time", inTrkpt {
            inTime = true
            timeBuffer = ""
        }
        
        // Only consider <ele> values inside <trkpt>.
        if elementName == "ele", inTrkpt {
            inEle = true
            eleBuffer = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTime {
            timeBuffer += string
        } else if inEle {
            eleBuffer += string
        }
    }
    
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "trkpt" {
            inTrkpt = false
            return
        }
        
        if elementName == "ele" {
            inEle = false
            let raw = eleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let curEle = Double(raw) else { return }
            
            if let prevEle = lastElevationMeters {
                let delta = curEle - prevEle
                if delta > 0 {
                    elevationGainMeters += delta
                } else if delta < 0 {
                    elevationLossMeters += (-delta)
                }
            }
            lastElevationMeters = curEle
            return
        }
        
        guard elementName == "time" else { return }
        inTime = false
        
        let raw = timeBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        
        // tolerate missing Z
        let str = raw.contains("Z") || raw.range(of: #"[\+\-]\d{2}:\d{2}$"#, options: .regularExpression) != nil
        ? raw
        : raw + "Z"
        
        let parsed = isoNoFrac.date(from: str) ?? isoWithFrac.date(from: str)
        guard let date = parsed else { return }
        
        if let minTime {
            if date < minTime { self.minTime = date }
        } else {
            minTime = date
        }
        
        if let maxTime {
            if date > maxTime { self.maxTime = date }
        } else {
            maxTime = date
        }
        
        if let minTime, let maxTime {
            elapsedTimeSeconds = max(0, maxTime.timeIntervalSince(minTime))
        }
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

