//
//  MapPost.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//

import Foundation

struct MapPost: Codable, Identifiable {
    let id: UUID
    let imageData: String
    let title: String
    let description: String
    let createdAt: Date
    let user: UserProfile  // Assuming you want to use the client-side UserProfile model here.
}
