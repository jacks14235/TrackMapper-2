//
//  LocationManager.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/10/25.
//
import SwiftUI
import MapKit

func distance(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> CLLocationDistance {
    let loc1 = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
    let loc2 = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
    return loc1.distance(from: loc2)
}

class LocationManagerStore: ObservableObject {
    private let tracker = LocationTracker()
    @Published var isTracking = false
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var totalDistance: CLLocationDistance = 0
    @Published private var startTime: Date? = nil
    @Published var tick = Date()  // triggers UI update

    private var timer: Timer?
    private var timeBeforePause: TimeInterval = 0

    var elapsedTime: TimeInterval {
        guard let start = startTime else { return timeBeforePause }
        return timeBeforePause + tick.timeIntervalSince(start)
    }
    
    init() {
        tracker.onLocationUpdate = { [weak self] coord in
//            print("New location: \(coord)")
            var distanceChange: CLLocationDistance = 0
            if let s = self, let c = self?.currentCoordinate {
                if s.isRecording && !s.isPaused {
                    distanceChange = distance(c, coord)
                }
            }
            DispatchQueue.main.async {
                self?.currentCoordinate = coord
                self?.totalDistance += distanceChange
            }
        }
        tracker.onTrackingUpdate = { [weak self] tracking in
            print("Tracking4: \(tracking)")
            DispatchQueue.main.async {
                self?.isTracking = tracking
            }
        }
        tracker.onRecordingUpdate = { [weak self] recording in
            print("Recording: \(recording)")
            let was_recording = self?.isRecording ?? false
            let started = !was_recording && recording
            if started {
                self?.onStart()
            }
            if recording == false {
                self?.onStop()
            }
        }
    }
    
    func startTracking() {
        self.tracker.startTracking()
    }
    func stopTracking() {
        self.tracker.stopTracking()
    }
    func startRecording() {
        self.tracker.startRecording()
    }
    func stopRecording() -> String {
        return self.tracker.stopRecording()
    }
    
    func pauseRecording() {
        if let startT = self.startTime {
            self.timeBeforePause += Date.now.timeIntervalSince(startT)
        }
        self.startTime = nil
        self.tracker.pauseRecording()
        self.isPaused = true
    }
    
    func unpauseRecording() {
        self.startTime = Date.now
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.tick = Date()
        }
        self.tracker.unpauseRecording()
        self.isPaused = false
    }
    
    private func onStart() {
        DispatchQueue.main.async {
            self.startTime = Date.now
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.tick = Date()
            }
            self.totalDistance = 0
            self.isRecording = true
        }
    }
    
    func onStop() {
        self.isRecording = false
        timer?.invalidate()
        timer = nil
        self.isPaused = false
    }
    
    func resetDistance() {
        self.totalDistance = 0
        timer?.invalidate()
        timer = nil
        self.startTime = nil
        self.timeBeforePause = 0
    }
    
}

