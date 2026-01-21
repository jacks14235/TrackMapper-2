//
//  AuthService.swift
//  TrackMapper
//
//  Created by ChatGPT on 8/16/25.
//

import Foundation

struct AuthPayload: Codable {
    let token: String
    let user: AuthUser
}

struct AuthUser: Codable {
    let id: String
    let firstname: String
    let lastname: String
    let username: String
    let email: String
}

final class AuthService {
    static let shared = AuthService()
    private init() {}
    
    private let baseURL: String = Config.baseURL
    
    func register(email: String, password: String, completion: @escaping (Result<AuthPayload, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            completion(.failure(APIError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["email": email, "password": password]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                return completion(.failure(NSError(domain: "Auth", code: code)))
            }
            do {
                let decoded = try JSONDecoder().decode(AuthPayload.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func login(email: String, password: String, completion: @escaping (Result<AuthPayload, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            completion(.failure(APIError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["email": email, "password": password]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                return completion(.failure(NSError(domain: "Auth", code: code)))
            }
            do {
                let decoded = try JSONDecoder().decode(AuthPayload.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func googleLogin(
        email: String,
        googleId: String,
        firstname: String,
        lastname: String,
        username: String,
        completion: @escaping (Result<AuthPayload, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/auth/google") else {
            completion(.failure(APIError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "email": email,
            "google_id": googleId,
            "firstname": firstname,
            "lastname": lastname,
            "username": username
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                return completion(.failure(NSError(domain: "Auth", code: code)))
            }
            do {
                let decoded = try JSONDecoder().decode(AuthPayload.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}


