//
//  LocationTracker.swift
//  TrackMapper
//
//  Created by Jack Stanley and ChatGPT on 4/10/25.
//

import Foundation
import CoreLocation

class LocationTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let gpxWriter = GPXWriter()
    private var isTracking = false
    private var isRecording = false
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    var onTrackingUpdate: ((Bool) -> Void)?
    var onRecordingUpdate: ((Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func startTracking() {
        isTracking = true
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        onTrackingUpdate?(true)
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        onTrackingUpdate?(false)
    }
    
    func startRecording() {
        isRecording = true
        onRecordingUpdate?(true)
    }
    
    func pauseRecording() {
        isRecording = false
    }

    func unpauseRecording() {
        isRecording = true
    }
    
    func stopRecording() -> String {
        isRecording = false
        onRecordingUpdate?(false)
        return gpxWriter.finish()
//        if let fileURL = gpxWriter.saveToFile() {
//            print("Saved GPX to: \(fileURL)")
//        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        for location in locations {
            if isRecording {
                gpxWriter.addLocation(location)
            }
            onLocationUpdate?(location.coordinate)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways {
            // startTracking()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
