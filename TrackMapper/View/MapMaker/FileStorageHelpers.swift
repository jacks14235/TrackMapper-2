//
//  FileStorage.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/4/25.
//

import SwiftUI
import CryptoKit

struct MapObject: Identifiable {
    let metadata: MapMetadata
    let hash: String
    var id: String { hash }
}

struct MapMetadata: Codable, Hashable {
    let name: String
    let description: String
    let center: Coordinate
    let N: Int
    let pairs: [CoordPair]
}

extension MapObject {
    init(from mapPost: MapPost) {
        // For MVP, we use default values for properties not provided by MapPost.
        let defaultCenter = Coordinate(x: 0, y: 0)
        let defaultPairs: [CoordPair] = []  // You can decide how to handle map interpolation pairs
        let metadata = MapMetadata(name: mapPost.title, description: mapPost.description, center: defaultCenter, N: 0, pairs: defaultPairs)
        self.init(metadata: metadata, hash: mapPost.id)
    }
}

func stableHashHex(data: Data) -> String? {
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

func setUpFolders() -> Bool {
    let fileManager = FileManager.default
    let folderNames = ["Metadata", "Image"]
    
    for folder in folderNames {
        let folderURL = getDocumentsDirectory().appendingPathComponent(folder)
        if !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                print("Created folder: \(folder)")
            } catch {
                print("Failed to create folder \(folder): \(error)")
                return false
            }
        }
    }
    return true
}

func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

func saveMaps(image: UIImage, name: String, description: String, spline: Spline) -> Bool {
    let meta = MapMetadata(name: name,
                           description: description,
                           center: spline.getCenter(),
                           N: spline.m,
                           pairs: CoordPair.fromRealArrays(reals: spline.realCoords, maps: spline.mapCoords)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    var jsonData: Data
    do {
        jsonData = try encoder.encode(meta)
    } catch {
        print("Error encoding JSON: \(error)")
        return false
    }
    guard let hash = stableHashHex(data: jsonData) else {
        print("Error hashing")
        return false
    }
    let folderURL = getDocumentsDirectory().appendingPathComponent("map_\(hash)")
    let imageUrl = folderURL.appendingPathComponent("image.png")
    let dataUrl = folderURL.appendingPathComponent("data.json")

    do {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        guard let imageData = image.pngData() else {
            print("Failed to convert UIImage to PNG")
            return false
        }
        try imageData.write(to: imageUrl)
        try jsonData.write(to: dataUrl)
    } catch {
        print("Failed to write files: \(error)")
        return false
    }
    
    return true
}

func saveMapLocal(map: MapDownload, image: UIImage) -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    var jsonData: Data
    do {
        jsonData = try encoder.encode(map)
    } catch {
        print("Error encoding JSON: \(error)")
        return false
    }
    let folderURL = getDocumentsDirectory().appendingPathComponent("map_\(map.id)")
    let imageUrl = folderURL.appendingPathComponent("image.png")
    let dataUrl = folderURL.appendingPathComponent("data.json")

    do {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("Failed to convert UIImage to JPEG")
            return false
        }
        try imageData.write(to: imageUrl)
        try jsonData.write(to: dataUrl)
    } catch {
        print("Failed to write files: \(error)")
        return false
    }
    return true
}


// TODO: Update this to work with MapDownload instead of MapObject
func loadSavedMaps() -> [MapObject] {
    let fileManager = FileManager.default
    let documentsURL = getDocumentsDirectory()
    
    guard let folderURLs = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) else {
        return []
    }
    
    var results: [MapObject] = []
    
    for folderURL in folderURLs where folderURL.lastPathComponent.starts(with: "map_") {
        let dataURL = folderURL.appendingPathComponent("data.json")
        do {
            let data = try Data(contentsOf: dataURL)
            let decoder = JSONDecoder()
            let meta = try decoder.decode(MapMetadata.self, from: data)
            let id = folderURL.lastPathComponent.replacingOccurrences(of: "map_", with: "")
            results.append(MapObject(metadata: meta, hash: id))
        } catch {
            print("Failed to load map at \(folderURL): \(error)")
        }
    }
    
    return results
}

func loadMapObject(fromHash hash: String) -> MapMetadata? {
    let folderName = "map_\(hash)"
    let folderURL = getDocumentsDirectory().appendingPathComponent(folderName)
    let dataURL = folderURL.appendingPathComponent("data.json")
    
    do {
        let data = try Data(contentsOf: dataURL)
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(MapMetadata.self, from: data)
        return metadata
    } catch {
        print("Failed to load MapObject with hash \(hash): \(error)")
        return nil
    }
}


func loadMapImage(fromHash hash: String) -> UIImage? {
    let folderName = "map_\(hash)"
    print("Loading from \(folderName)")
    let imageURL = getDocumentsDirectory()
        .appendingPathComponent(folderName)
        .appendingPathComponent("image.png")
    
    return UIImage(contentsOfFile: imageURL.path)
}

func loadAllFromHash(fromHash hash: String) -> (String, String, Coordinate, Spline, UIImage)? {
    let metadata = loadMapObject(fromHash: hash)
    let imageData = loadMapImage(fromHash: hash)
    
    if let meta = metadata, let imgData = imageData {
        let spline = Spline(coordinates: meta.pairs)
        return (meta.name, meta.description, meta.center, spline, imgData)
    } else {
        return nil
    }
}

func deleteLocalMap(id: String) -> Bool {
    let folderName = "map_\(id)"
    let folderURL = getDocumentsDirectory().appendingPathComponent(folderName)
    
    do {
        try FileManager.default.removeItem(at: folderURL)
        print("Deleted map at \(folderURL)")
        return true
    } catch {
        print("Failed to delete map: \(error)")
        return false
    }
}

func loadActivities() -> [Date: String] {
    let fileManager = FileManager.default
    let documentsURL = getDocumentsDirectory()

    guard let fileURLs = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) else {
        return [:]
    }
    var result: [Date: String] = [:]
    for fileURL in fileURLs where fileURL.lastPathComponent.starts(with: "track_") && fileURL.pathExtension == "gpx" {
        let parser = GPXParser()
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("skipping \(fileURL)")
            continue
        }
        if let data = try? Data(contentsOf: fileURL) {
            let date = parser.extractTrackDate(from: data)
            if let d = date {
                result[d] = content
            } else {
                print("No date for \(fileURL)")
                print(content)
//                return result
            }
        }
    }
    return result
}
