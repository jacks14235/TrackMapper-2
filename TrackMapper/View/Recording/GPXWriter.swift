//
//  GPXRecorder.swift
//  TrackMapper
//
//  Created by Jack Stanley and ChatGPT on 4/10/25.
//

import Foundation
import CoreLocation

class GPXWriter {
    private var gpxContent: String = ""
    private var isFinished = false

    init() {
        gpxContent += """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TrackMapper" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>GPX Track</name>
            <trkseg>
        """
    }

    func addLocation(_ location: CLLocation) {
        let timestamp = ISO8601DateFormatter().string(from: location.timestamp)
        gpxContent += """
              <trkpt lat="\(location.coordinate.latitude)" lon="\(location.coordinate.longitude)">
                <ele>\(location.altitude)</ele>
                <time>\(timestamp)</time>
              </trkpt>

        """
    }

    func finish() -> String {
        if isFinished {
            return gpxContent
        }
        gpxContent += """
            </trkseg>
          </trk>
        </gpx>
        """
        isFinished = true
        return gpxContent
    }

    func saveToFile() -> URL? {
        let finalContent = finish()
        let fileName = "track_\(Date().timeIntervalSince1970).gpx"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)

        do {
            try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write GPX file:", error)
            return nil
        }
    }
}
