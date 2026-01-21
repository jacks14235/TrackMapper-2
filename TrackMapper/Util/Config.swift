import Foundation

/// A central place for global constants used across the app.
enum Config {
    /// The base URL for the Flask API.
    // static let baseURL = "http://172.20.10.3:7860"
    static let baseURL = "http://localhost:7860"
    // static let fileURL = "http://localhost:7860/download"
    static let fileURL = "https://trackmapper.s3.us-east-1.amazonaws.com"
    static let googleOAuthClientID = "916945367088-mv0vk0lgkt36bjfjfgnjljajnj11f41c.apps.googleusercontent.com"
}
