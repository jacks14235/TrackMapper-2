//
//  UserProfile.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//

import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    var firstname: String
    var lastname: String
    var username: String
    var password: String
}
