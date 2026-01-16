//
//  TrackMapperApp.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 3/26/25.
//

import SwiftUI

@main
struct TrackMapperApp: App {
    @StateObject var locationStore = LocationManagerStore()
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var authStore = AuthStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationStore)
                .environmentObject(sessionManager)
                .environmentObject(authStore)
        }
    }
}

