//
//  TrackMapperApp.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 3/26/25.
//

import SwiftUI
import GoogleSignIn

@main
struct TrackMapperApp: App {
    @StateObject var locationStore = LocationManagerStore()
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var authStore = AuthStore()
    
    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: Config.googleOAuthClientID
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationStore)
                .environmentObject(sessionManager)
                .environmentObject(authStore)
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

