//
//  FeedMapPostCard.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//

import SwiftUI

/// A card view that displays individual map post details.
struct FeedMapPostCard: View {
    let map: MapPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display the resort map image.
            if let image = decodeImage(from: map.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 250)
                    .clipped()
                    .cornerRadius(10)
            } else {
                // Fallback view in case image decoding fails.
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 250)
                    .cornerRadius(10)
                    .overlay(Text("No Image").foregroundColor(.white))
            }
            
            // Display the map title and creation date.
            HStack {
                Text(map.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(formatDate(map.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Display user information.
            Text("By \(map.user.name) (@\(map.user.username))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Show the map description if one exists.
            if !map.description.isEmpty {
                Text(map.description)
                    .font(.body)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Functions
    
    /// Decodes a Base64 encoded string into a UIImage.
    private func decodeImage(from base64String: String) -> UIImage? {
        guard let imageData = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: imageData)
    }
    
    /// Formats a Date object into a friendly string.
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
