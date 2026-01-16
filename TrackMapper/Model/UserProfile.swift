//
//  UserProfile.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//

import Foundation

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var username: String
    var password: String
}
