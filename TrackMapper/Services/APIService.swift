//
//  APIService.swift
//  TrackMapper
//
//  Created by Jack Stanley with help from ChatGPT.
//

import Foundation
import SwiftUI

final class APIService {
    static let shared = APIService() // singleton
    
    private let baseURL = Config.baseURL
    
    func nearestMaps(latitude: Double, longitude: Double, completion: @escaping (Result<[MapDownload], Error>) -> Void) {
        var comps = URLComponents(string: "\(baseURL)/maps/nearest")
        comps?.queryItems = [
          URLQueryItem(name: "lat", value: String(latitude)),
          URLQueryItem(name: "lon", value: String(longitude))
        ]
        guard let url = comps?.url else {
          return completion(.failure(APIError.invalidURL))
        }
        let req = makeRequest(url: url)
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            do {
                let decoder = self.setupDecoder()
                let maps = try decoder.decode([MapDownload].self, from: data)
                completion(.success(maps))
            }
            catch DecodingError.keyNotFound(let key, let context) {
                print("🔑 Key '\(key.stringValue)' not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.keyNotFound(key, context)))
            }
            catch DecodingError.valueNotFound(let type, let context) {
                print("❌ Value of type \(type) not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.valueNotFound(type, context)))
            }
            catch DecodingError.typeMismatch(let type, let context) {
                print("⚠️ Type mismatch for \(type) –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.typeMismatch(type, context)))
            }
            catch DecodingError.dataCorrupted(let context) {
                print("💥 Data corrupted –", context.debugDescription)
                completion(.failure(DecodingError.dataCorrupted(context)))
            }
            catch {
                print("🛑 Other error:", error)
                completion(.failure(error))
            }
        }.resume()
    }
    
    func setupDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()

        // Formatter #1: no fractional seconds
        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [
          .withInternetDateTime        // yyyy-MM-dd'T'HH:mm:ssZ
        ]

        // Formatter #2: with fractional seconds
        let isoWithFrac = ISO8601DateFormatter()
        isoWithFrac.formatOptions = [
          .withInternetDateTime,
          .withFractionalSeconds       // yyyy-MM-dd'T'HH:mm:ss.SSSZ
        ]

        decoder.dateDecodingStrategy = .custom { decoder -> Date in
          let container = try decoder.singleValueContainer()
          let raw = try container.decode(String.self)

          // ensure we have a Z or +00:00 at the end
          let str = raw.contains("Z") || raw.range(of: #"[\+\-]\d{2}:\d{2}$"#, options: .regularExpression) != nil
                  ? raw
                  : raw + "Z"

          // 1) try no-fraction
          if let d = isoNoFrac.date(from: str) {
            return d
          }
          // 2) try with-fraction
          if let d2 = isoWithFrac.date(from: str) {
            return d2
          }
          // 3) give up
          throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid date: \(raw)"
          )
        }

        return decoder
    }

    // Build a URLRequest that includes Authorization header if a token exists in UserDefaults
    private func makeRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token = KeychainHelper.read(key: "auth_token") ?? UserDefaults.standard.string(forKey: "auth_token") {
            // send as Bearer token; server accepts token-<id> as well
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func attachAuthHeader(_ req: inout URLRequest) {
        if let token = KeychainHelper.read(key: "auth_token") ?? UserDefaults.standard.string(forKey: "auth_token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    
    func userMaps(userId: String, completion: @escaping (Result<[MapDownload], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/maps") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        let req = makeRequest(url: url)
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            do {
                let decoder = self.setupDecoder()
                let maps = try decoder.decode([MapDownload].self, from: data)
                completion(.success(maps))
            }
            catch DecodingError.keyNotFound(let key, let context) {
                print("🔑 Key '\(key.stringValue)' not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.keyNotFound(key, context)))
            }
            catch DecodingError.valueNotFound(let type, let context) {
                print("❌ Value of type \(type) not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.valueNotFound(type, context)))
            }
            catch DecodingError.typeMismatch(let type, let context) {
                print("⚠️ Type mismatch for \(type) –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.typeMismatch(type, context)))
            }
            catch DecodingError.dataCorrupted(let context) {
                print("💥 Data corrupted –", context.debugDescription)
                completion(.failure(DecodingError.dataCorrupted(context)))
            }
            catch {
                print("🛑 Other error:", error)
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Gets the points and image for a given map Id
    func getMapData(
        mapId: String,
        completion: @escaping (Result<([CoordPair], UIImage), Error>) -> Void
    ) {
        // 1) build your two endpoints
        guard
          let pointsURL = URL(string: "\(baseURL)/download/points_\(mapId).json"),
          let imageURL  = URL(string: "\(baseURL)/download/image_\(mapId).jpg")
        else {
          return completion(.failure(APIError.invalidURL))
        }

        // 2) fetch the points JSON first
        let reqPoints = makeRequest(url: pointsURL)
        URLSession.shared.dataTask(with: reqPoints) { data, resp, err in
          if let err = err {
            return DispatchQueue.main.async {
              completion(.failure(err))
            }
          }
          guard let data = data else {
            return DispatchQueue.main.async {
              completion(.failure(APIError.noData))
            }
          }

          // decode your CoordPair array
          let decoder = JSONDecoder()
          do {
            let pairs = try decoder.decode([CoordPair].self, from: data)

            // 3) now fetch the image
            let reqImage = self.makeRequest(url: imageURL)
            URLSession.shared.dataTask(with: reqImage) { data, resp, err in
              if let err = err {
                return DispatchQueue.main.async {
                  completion(.failure(err))
                }
              }
              guard
                let data = data,
                let image = UIImage(data: data)
              else {
                return DispatchQueue.main.async {
                  completion(.failure(APIError.imageConversionFailed))
                }
              }

              // 4) success! send both back
              DispatchQueue.main.async {
                completion(.success((pairs, image)))
              }
            }
            .resume()

          } catch {
            DispatchQueue.main.async {
              completion(.failure(APIError.jsonSerializationFailed))
            }
          }
        }
        .resume()
    }

    
    /// POSTs your map object as JSON and returns the created map from the server.
    func uploadMap(
        _ map: MapUpload,
        image: UIImage,
        completion: @escaping (Result<MapDownload, Error>) -> Void
    ) {
        // 1. Build the URL + request
        guard let url = URL(string: "\(baseURL)/maps/upload") else {
            return completion(.failure(APIError.invalidURL))
        }
        var req = makeRequest(url: url, method: "POST")
        req.httpMethod = "POST"
        
        // 2. Prepare a boundary string and set the Content‐Type
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 3. Fill out the body
        var body = Data()
        
        // Helper to append a text field
        func appendFormField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // a) your map fields
        appendFormField(name: "title",      value: map.title)
        appendFormField(name: "description",value: map.description)
        appendFormField(name: "latitude",   value: "\(map.latitude)")
        appendFormField(name: "longitude",  value: "\(map.longitude)")
        appendFormField(name: "num_points", value: "\(map.numPoints)")
        
        // b) the “points” JSON (assuming map.points is Encodable)
        if let ptsData = try? JSONEncoder().encode(map.points),
           let ptsString = String(data: ptsData, encoding: .utf8) {
            appendFormField(name: "points", value: ptsString)
        }
        
        // c) the image file
        if let jpeg = image.jpegData(compressionQuality: 0.8) {
            let filename = "map_image.jpg"
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n"
                    .data(using: .utf8)!
            )
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(jpeg)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // d) end boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        // 4. Fire the request
        // ensure auth header present
        attachAuthHeader(&req)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                return completion(.failure(err))
            }
            guard let http = resp as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data = data else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                let e = NSError(
                    domain: "UploadMap", code: code,
                    userInfo: [NSLocalizedDescriptionKey: "Server returned \(code)"]
                )
                return completion(.failure(e))
            }
            do {
                let decoder = self.setupDecoder()
                let created = try decoder.decode(MapDownload.self, from: data)
                completion(.success(created))
            } catch {
                completion(.failure(error))
            }
        }
        .resume()
    }
    
    func uploadActivity(
        title: String,
        description: String,
        gpxData: String,
        createdAt: Date,
        userId: String,
        mapId: String?,
        distance: Double,
        elapsedTime: Double,
        completion: @escaping (Result<ActivityDownload, Error>) -> Void
    ) {
        // 1. Build the URL + request
        guard let url = URL(string: "\(baseURL)/activities/upload") else {
            return completion(.failure(APIError.invalidURL))
        }
        var req = makeRequest(url: url, method: "POST")
        req.httpMethod = "POST"
        
        // 2. Prepare a boundary string and set the Content‐Type
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 3. Fill out the body
        var body = Data()
        
        // Helper to append a text field
        func appendFormField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // a) your activity fields
        appendFormField(name: "title",      value: title)
        appendFormField(name: "description",value: description)
        appendFormField(name: "date", value: createdAt.ISO8601Format())
        appendFormField(name: "user_id", value: "\(userId)")
        
        if let mid = mapId, !mid.isEmpty {
            appendFormField(name: "map_id", value: mid)
        }
        
        appendFormField(name: "distance", value: "\(distance)")
        appendFormField(name: "elapsed_time", value: "\(elapsedTime)")
        do {
            try GPXUtils.appendGPXField(to: &body, boundary: boundary, gpxString: gpxData)
        } catch {
            return completion(.failure(APIError.jsonSerializationFailed))
        }
        
        // end boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        // 4. Fire the request
        attachAuthHeader(&req)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                return completion(.failure(err))
            }
            guard let http = resp as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data = data else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                let e = NSError(
                    domain: "UploadMap", code: code,
                    userInfo: [NSLocalizedDescriptionKey: "Server returned \(code)"]
                )
                return completion(.failure(e))
            }
            do {
                let decoder = self.setupDecoder()
                let created = try decoder.decode(ActivityDownload.self, from: data)
                completion(.success(created))
            } catch {
                completion(.failure(error))
            }
        }
        .resume()
    }
    
    func userActivities(userId: String, completion: @escaping (Result<[ActivityDownload], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/activities") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        let req = makeRequest(url: url)
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            do {
                let decoder = self.setupDecoder()
                let maps = try decoder.decode([ActivityDownload].self, from: data)
                completion(.success(maps))
            }
            catch DecodingError.keyNotFound(let key, let context) {
                print("🔑 Key '\(key.stringValue)' not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.keyNotFound(key, context)))
            }
            catch DecodingError.valueNotFound(let type, let context) {
                print("❌ Value of type \(type) not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.valueNotFound(type, context)))
            }
            catch DecodingError.typeMismatch(let type, let context) {
                print("⚠️ Type mismatch for \(type) –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.typeMismatch(type, context)))
            }
            catch DecodingError.dataCorrupted(let context) {
                print("💥 Data corrupted –", context.debugDescription)
                completion(.failure(DecodingError.dataCorrupted(context)))
            }
            catch {
                print("🛑 Other error:", error)
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Profile
    struct ServerUser: Codable {
        let id: String
        let firstname: String
        let lastname: String
        let username: String
        let email: String
        let friends: [String]?
    }

    func fetchUserProfile(userID: String, completion: @escaping (Result<ServerUser, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userID)/profile") else {
            completion(.failure(APIError.invalidURL)); return
        }
        let req = makeRequest(url: url)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(APIError.noData)); return
            }
            do {
                let decoder = self.setupDecoder()
                let user = try decoder.decode(ServerUser.self, from: data)
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func updateUserProfile(userID: String, updatedData: [String: String], completion: @escaping (Result<ServerUser, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userID)/profile") else {
            completion(.failure(APIError.invalidURL)); return
        }
        var req = makeRequest(url: url, method: "PUT")
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: updatedData)

        attachAuthHeader(&req)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                completion(.failure(APIError.noData)); return
            }
            do {
                let decoder = self.setupDecoder()
                let user = try decoder.decode(ServerUser.self, from: data)
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func friendActivities(userId: String, completion: @escaping (Result<[ActivityDownload], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/friends/activities") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        let req = makeRequest(url: url)
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            do {
                let decoder = self.setupDecoder()
                let maps = try decoder.decode([ActivityDownload].self, from: data)
                completion(.success(maps))
            }
            catch DecodingError.keyNotFound(let key, let context) {
                print("🔑 Key '\(key.stringValue)' not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.keyNotFound(key, context)))
            }
            catch DecodingError.valueNotFound(let type, let context) {
                print("❌ Value of type \(type) not found –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.valueNotFound(type, context)))
            }
            catch DecodingError.typeMismatch(let type, let context) {
                print("⚠️ Type mismatch for \(type) –", context.debugDescription)
                print("   codingPath:", context.codingPath.map { $0.stringValue }.joined(separator: "."))

                completion(.failure(DecodingError.typeMismatch(type, context)))
            }
            catch DecodingError.dataCorrupted(let context) {
                print("💥 Data corrupted –", context.debugDescription)
                completion(.failure(DecodingError.dataCorrupted(context)))
            }
            catch {
                print("🛑 Other error:", error)
                completion(.failure(error))
            }
        }.resume()
    }
    
    func getGpx(activityId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/download/gpx_\(activityId).gpx") else {
          return completion(.failure(APIError.invalidURL))
        }

        let req = makeRequest(url: url)
        // 2) fetch the gpx data
        URLSession.shared.dataTask(with: req) { data, resp, err in
          if let err = err {
            return DispatchQueue.main.async {
              completion(.failure(err))
            }
          }
          guard let data = data else {
            return DispatchQueue.main.async {
              completion(.failure(APIError.noData))
            }
          }
            let gpxString: String
            do {
                gpxString = try GPXUtils.gpxString(from: data)
            } catch {
                return DispatchQueue.main.async {
                    completion(.failure(APIError.textDecodeFailed))
                }
            }

            // success
            DispatchQueue.main.async {
              completion(.success(gpxString))
            }
          }
          .resume()
    }
    
    func deleteMap(
        mapId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 1. Build URL
        guard let url = URL(string: "\(baseURL)/maps/\(mapId)") else {
            return completion(.failure(APIError.invalidURL))
        }
        // 2. Create DELETE request
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        // attach auth header
        attachAuthHeader(&req)
        
        // 3. Fire it off
        URLSession.shared.dataTask(with: req) { _, response, error in
            // Network or transport error
            if let error = error {
                return DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            // Validate response
            guard let http = response as? HTTPURLResponse else {
                return DispatchQueue.main.async {
                    completion(.failure(APIError.noData))
                }
            }
            // Success (204 or any 2xx)
            if (200...299).contains(http.statusCode) {
                return DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                // Server‐side error
                return DispatchQueue.main.async {
                    completion(.failure(APIError.serverError))
                }
            }
        }
        .resume()
    }
    
    func deleteActivity(
        activityId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 1. Build URL
        guard let url = URL(string: "\(baseURL)/activities/\(activityId)") else {
            return completion(.failure(APIError.invalidURL))
        }
        // 2. Create DELETE request
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        attachAuthHeader(&req)
        
        // 3. Fire it off
        URLSession.shared.dataTask(with: req) { _, response, error in
            if let error = error {
                return DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            guard let http = response as? HTTPURLResponse else {
                return DispatchQueue.main.async {
                    completion(.failure(APIError.noData))
                }
            }
            if (200...299).contains(http.statusCode) {
                return DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                return DispatchQueue.main.async {
                    completion(.failure(APIError.serverError))
                }
            }
        }
        .resume()
    }
    
}



enum APIError: String, Error, LocalizedError {
    case invalidURL               = "The URL provided was invalid."
    case noData                   = "No data was returned by the server."
    case imageConversionFailed    = "Failed to convert data into an image."
    case textDecodeFailed         = "Failed to decode gpx response into text"
    case notLoggedIn              = "You must be logged in to perform this action."
    case jsonSerializationFailed  = "Failed to serialize JSON."
    case userNotFound             = "The requested user was not found."
    case serverError              = "The server failed to complete the request."
    var errorDescription: String? {
        return rawValue
    }
}


struct MapDownload: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let imagePath: String
    let userId: String
    let latitude: Double
    let longitude: Double
    let numPoints: Int
    let uploadedAt: Date
    let username: String
    let distance: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case imagePath  = "image_path"
        case userId     = "user_id"
        case latitude
        case longitude
        case numPoints  = "num_points"
        case uploadedAt = "uploaded_at"
        case username
        case distance
    }
}

struct MapUpload: Codable {
    let title: String
    let description: String
    let latitude: Double
    let longitude: Double
    let uploadedAt: Date
    let numPoints: Int
    let points: [CoordPair]
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case latitude
        case longitude
        case uploadedAt = "uploaded_at"
        case numPoints  = "num_points"
        case points
    }
}

struct ActivityDownload: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let createdAt: Date
    let userId: String
    let mapId: String?
    let username: String
    let distance: Double?
    let elapsedTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case createdAt      = "created_at"
        case userId         = "user_id"
        case mapId          = "map_id"
        case username
        case distance
        case elapsedTime    = "elapsed_time"
    }
}
