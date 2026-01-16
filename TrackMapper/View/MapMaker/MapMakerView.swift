//
//  MapMakerView.swift
//  Test Project
//
//  Created by Jack Stanley on 3/8/25.
//

import SwiftUI
import MapKit
import UIKit

// MARK: - Coordinate Extensions

extension Coordinate {
    static func from(_ location: CLLocationCoordinate2D) -> Coordinate {
        return Coordinate(x: location.latitude, y: location.longitude)
    }
}

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MapMakerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionManager
    var mapDownload: MapDownload?  // Provided if editing an existing map
    @State var serverLoaded = false
    @State var mapClick: Coordinate?
    @State var spline: Spline?
    @State var imageClick: Coordinate?
    @State var imagePoints: [Coordinate] = []
    @State var picked: Int = 0
    @State var presetMap: Int = 0
    @State var title: String = ""
    @State var mapCenter = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State var imageData: UIImage?
    @State var error: String?
    var center: CLLocationCoordinate2D
    
    private var draftKey: String {
        if let mapDownload {
            return "mapmaker-edit-\(mapDownload.id)"
        }
        return "mapmaker-new"
    }

    init(mapDownload: MapDownload? = nil) {
        self.mapDownload = mapDownload
        _title = State(initialValue: mapDownload?.title ?? "")
        _mapClick = State(initialValue: Coordinate(x: mapDownload?.latitude ?? 0, y: mapDownload?.longitude ?? 0))
        let spline = Spline(coordinates: [])
        _spline = State(initialValue: spline)
        print("\(spline.mapCoords.count) points initialized")
        _imagePoints = State(initialValue: spline.mapCoords)
        
        var imageData: UIImage? = nil
        let ctr = CLLocationCoordinate2D(latitude: mapDownload?.longitude ?? 0, longitude: mapDownload?.latitude ?? 0)
//        let ctr = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        _imageData = State(initialValue: imageData)
        center = ctr
    }

    var body: some View {
        VStack {
            if mapDownload == nil && imageData == nil {
                VStack {
                    Text("Choose an image of a map to get started")
                    PhotoPicker(selectedImage: $imageData)
                }
            } else {
                Button(action: { saveMap() }) {
                    Text("Save")
                }
                TextField("Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Picker("Select", selection: $picked) {
                    Text("Map").tag(0)
                    Text("Image").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                HStack {
                    Button(action: submitPoints) {
                        Text("Submit").padding()
                    }
                    Button(action: { print(spline?.toJSON() ?? "No spline") }) {
                        Image(systemName: "printer.filled.and.paper")
                    }
                }
                ZStack {
                    MapView(clickedCoordinate: $mapClick, spline: $spline, imageData: $imageData, center: center)
                        .opacity(picked == 0 ? 1 : 0)
                    ZoomableImageView(
                                      spline: $spline,
                                      mapPoint: $mapClick,
                                      clickedPoint: $imageClick,
                                      mapPoints: $imagePoints,
                                      imageData: $imageData,
                                      mapMode: .create,
                                      onDelete: { index in
                        if let s = spline {
                            var points = s.getPairs()
                            points.remove(at: index)
                            spline = Spline(coordinates: points)
                        }
                        
                    })
                        .opacity(picked == 1 ? 1 : 0)
                }
            }
        }
        .onAppear {
            // 1) Restore any in-progress draft (prevents losing points on tab switch)
            restoreDraftIfPresent()
            
            // 2) If we're editing an existing map and we don't have a draft, load from server
            if let mapDown = mapDownload, session.mapMakerDraft(for: draftKey) == nil {
                APIService.shared.getMapData(mapId: mapDown.id, completion: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let (points, image)):
                            print("Found \(points.count) points")
                            self.imageData = image
                            self.spline = Spline(coordinates: points)
                        case .failure(let error):
                            print("Error fetching maps for mapMakerView:", error.localizedDescription)
                            self.error = error.localizedDescription
                        }
                    }
                })
            }
        }
        .onChange(of: spline) {
            if let s = spline {
                imagePoints = s.mapCoords
                persistDraft()
            }
        }
        .onChange(of: title) { persistDraft() }
        .onChange(of: picked) { persistDraft() }
        .onChange(of: imageData) { persistDraft() }
    }

    func submitPoints() {
        if let map = mapClick, let image = imageClick {
            spline = spline?.withAddedPoint(newRealCoord: map, newMapCoord: image)
            mapClick = nil
            imageClick = nil
        }
    }

    func loadMap(meta: MapMetadata) {
        print("Loading \(meta.name)")
        // Additional logic for loading an existing map into the editing interface can be added here.
        // For example, you might want to decode a Base64 image stored in the metadata if available.
    }
    
    func saveLocal(imageData: UIImage, spline: Spline) {
        _ = saveMaps(image: imageData, name: title, description: "Map called \(title)", spline: spline)
    }

    /// Save the current map by sending a POST request with a Base64‑encoded image.
    func saveMap() {
        if let imgData = imageData, let s = spline {
            let center = s.getCenter()
            let upload = MapUpload(
                title: title,
                description: "A map called \(title)",
                latitude: center.lat,
                longitude: center.lon,
                uploadedAt: Date.now,
                numPoints: s.m,
                points: s.getPairs()
            )
            APIService.shared.uploadMap(upload, image: imgData, completion: { result in
                switch result {
                case .success(let download):
                    let success = saveMapLocal(map: download, image: imgData)
                    if success {
                        DispatchQueue.main.async {
                            session.clearMapMakerDraft(for: draftKey)
                            dismiss()
                        }
                    } else {
                        print("Error saving locally")
                        self.error = "Error saving locally"
                    }
                case .failure(let error):
                    print("Error saving to server: \(error)")
                    self.error = error.localizedDescription
                }
            })
        }
    }
    
    private func restoreDraftIfPresent() {
        guard let draft = session.mapMakerDraft(for: draftKey) else { return }
        
        if !draft.title.isEmpty {
            title = draft.title
        }
        picked = draft.picked
        
        if let data = draft.imageData, imageData == nil {
            imageData = UIImage(data: data)
        }
        
        if !draft.pairs.isEmpty {
            spline = Spline(coordinates: draft.pairs)
            imagePoints = spline?.mapCoords ?? []
        }
    }
    
    private func persistDraft() {
        var draft = session.mapMakerDraft(for: draftKey) ?? MapMakerDraftState()
        draft.title = title
        draft.picked = picked
        draft.pairs = spline?.getPairs() ?? []
        draft.imageData = imageData?.jpegData(compressionQuality: 0.9)
        session.saveMapMakerDraft(draft, for: draftKey)
    }
}
