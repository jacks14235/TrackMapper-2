//
//  CustomMapView.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/11/25.
//

import SwiftUI
import MapKit

enum MapSelection: Equatable, Hashable {
    case appleMap
    case customMap(Int)
    var id: Int? {
        switch self {
        case .appleMap: return nil
        case .customMap(let id): return id
        }
    }
    
    static func fromID(_ id: Int?) -> MapSelection {
        if let i = id, i >= 0 {
            return .customMap(i)
        } else {
            return .appleMap
        }
    }
}

struct CustomMapView: View {
    @EnvironmentObject var locationStore: LocationManagerStore
    @State private var customMaps: [MapDownload] = []
    @State private var imageData: UIImage?
    @State private var mapPoint: Coordinate?
    @State private var spline: Spline?
    @State private var gpxPoints: [Coordinate] = []
    @State var mapID: MapSelection
    var activity: ActivityDownload?
    
    init(initialSelection: MapSelection, activity: ActivityDownload?) {
        _mapID = State(initialValue: initialSelection)
        self.activity = activity
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if mapID == .appleMap {
                AppleMapView(gpxCoords: $gpxPoints)
            } else {
                ZoomableImageView(spline: $spline,
                                  mapPoint: $mapPoint,
                                  clickedPoint: .constant(nil),
                                  mapPoints: $gpxPoints,
                                  imageData: $imageData,
                                  mapMode: .view,
                                  onDelete: { _ in})
            }
            Picker("Map Type", selection: $mapID) {
                Text("Apple Map").tag(MapSelection.appleMap)
                ForEach(customMaps) { map in
                    Text(map.title).tag(MapSelection.customMap(map.id))
                }
            }
            .backgroundStyle(.white)
        }
        .onAppear {
            APIService.shared.nearestMaps(latitude: 37.33019141, longitude: -122.02569022) { result in
                switch result {
                case .success(let downloads):
                    customMaps = downloads
                case .failure(let error):
                    print("Error getting nearest maps: \(error)")
                }
            }
            if let act = activity {
                APIService.shared.getGpx(activityId: act.id) { result in
                    switch result {
                    case .success(let gpx):
                        loadCoordinates(gpxString: gpx)
                    case .failure(let error):
                        print("Error fetching GPX: \(error)")
                    }
                }
            }
        }
        .onChange(of: mapID, initial: true) {
            print("Map ID changed to \(mapID)")
            if case let .customMap(id) = mapID {
                APIService.shared.getMapData(mapId: id) { result in
                    switch result {
                    case .success(let (coords, imgData)):
                        print("Got map with id \(id)")
                        self.imageData = imgData
                        self.spline = Spline(coordinates: coords)
                    case .failure(let error):
                        print("Error getting map with id \(id): \(error)")
                    }
                }
            }
        }
        .onChange(of: locationStore.currentCoordinate) {
            if let coord = locationStore.currentCoordinate {
                mapPoint = Coordinate(x: coord.latitude, y: coord.longitude)
            }
        }
    }
    
    func loadCoordinates(gpxString: String) {
        if let data = gpxString.data(using: .utf8) {
            let parser = GPXParser()
            let worldCoords = parser.parseGPX(data: data)
            print("Loaded \(worldCoords.count) gpx points")
            gpxPoints = worldCoords
        }
    }
    
}

struct AppleMapView: View {
    enum MapType {
        case standard, satellite
    }
    enum MapCameraPosition {
        case automatic
        case userLocation
    }
    
    @Binding var gpxCoords: [Coordinate]
    @State private var mapType: MapType = .standard
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack {
            MapViewRepresentable(
                mapType: mapType,
                cameraPosition: cameraPosition,
                gpxCoords: $gpxCoords
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        cameraPosition = .userLocation
                    }) {
                        Image(systemName: "location.fill")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding()

                    Button(action: {
                        mapType = (mapType == .standard) ? .satellite : .standard
                    }) {
                        Image(systemName: "map")
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
            }
        }
    }
}


struct MapViewRepresentable: UIViewRepresentable {
    let mapType: AppleMapView.MapType
    let cameraPosition: AppleMapView.MapCameraPosition
    @Binding var gpxCoords: [Coordinate]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        switch mapType {
        case .standard:
            mapView.mapType = .standard
        case .satellite:
            mapView.mapType = .satellite
        }
        
        if cameraPosition == .userLocation,
           let userLocation = mapView.userLocation.location {
            let region = MKCoordinateRegion(center: userLocation.coordinate,
                                            latitudinalMeters: 1000,
                                            longitudinalMeters: 1000)
            mapView.setRegion(region, animated: true)
        }
        
        mapView.removeOverlays(mapView.overlays)
        
        let polyline = MKPolyline(coordinates: gpxCoords.map({CLLocationCoordinate2D(
            latitude: $0.x,
            longitude: $0.y
        )}), count: gpxCoords.count)
        print("Drawing \(gpxCoords.count) points")
        mapView.addOverlay(polyline)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
        
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.red
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}


