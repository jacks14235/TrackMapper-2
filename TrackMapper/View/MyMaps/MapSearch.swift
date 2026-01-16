//
//  MyMapsView.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 3/27/25.
//

import SwiftUI

struct MapSearch: View {
    @State var maps: [MapDownload] = []
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var locationStore: LocationManagerStore
    @State private var error: String?
    @State private var oneTimeFetcher: OneTimeLocationFetcher?
    
    var body: some View {
        NavigationStack {
            VStack {
                if let err = error {
                    Text("Error: \(err)")
                }
                VStack {
                    List {
                        ForEach(maps) { map in
                            NavigationLink {
                                MapMakerView(mapDownload: map)
                            } label: {
                                HStack(alignment: .bottom) {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(map.title).font(.headline)
                                            Spacer()
                                            if let dist = map.distance {
                                                Text(String(format: "%.1f mi", dist / 1.609)).font(.subheadline).foregroundStyle(.blue)
                                            }
                                        }
                                        Text(map.description).font(.subheadline).foregroundColor(.secondary)
                                        Text(map.username).font(.footnote).foregroundColor(.secondary).fontWeight(.bold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {refreshNearest()}) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Online Maps")
            .onAppear() {
                refreshNearest()
            }
        }
    }
    
    func refreshNearest() {
        print("Starting fetch")
        oneTimeFetcher = OneTimeLocationFetcher { result in
            switch result {
            case .success(let location):
                error = nil
                print("Fetching with location \(location)")
                APIService.shared.nearestMaps(latitude: location.latitude, longitude: location.longitude) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let maps):
                            print("Fetched \(maps.count) maps:")
                            for map in maps {
                                print(" • \(map.title) @ \(map.latitude),\(map.longitude)")
                            }
                            self.maps = maps
                        case .failure(let error):
                            print("Error fetching maps:", error.localizedDescription)
                            self.error = error.localizedDescription
                        }
                    }
                }
            case .failure(let err):
                print("Location error:", err)
                self.error = err.localizedDescription
            }
            oneTimeFetcher = nil
        }
    }
    
    /// Decode a Base64‑encoded image string into a UIImage.
    func decodeImage(from base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }
}


import CoreLocation

/// Fires exactly one location update, then tears itself down.
final class OneTimeLocationFetcher: NSObject {
    private let manager = CLLocationManager()
    private let completion: (Result<CLLocationCoordinate2D, Error>) -> Void

    init(completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        self.completion = completion
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // Make sure you have NSLocationWhenInUseUsageDescription in your Info.plist
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()             // ← one-shot
    }
}

extension OneTimeLocationFetcher: CLLocationManagerDelegate {
    func locationManager(
      _ manager: CLLocationManager,
      didUpdateLocations locations: [CLLocation]
    ) {
        guard let loc = locations.first else {
            completion(.failure(NSError(
              domain: "OneTimeLocationFetcher",
              code: 0,
              userInfo: [NSLocalizedDescriptionKey: "No location"]
            )))
            return
        }
        completion(.success(loc.coordinate))
        manager.delegate = nil               // clean up
    }

    func locationManager(
      _ manager: CLLocationManager,
      didFailWithError error: Error
    ) {
        completion(.failure(error))
        manager.delegate = nil               // clean up
    }
}
