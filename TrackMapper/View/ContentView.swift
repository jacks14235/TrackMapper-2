//
//  ContentView.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 3/26/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var auth: AuthStore
    
    var body: some View {
        Group {
            if auth.token != nil && auth.currentUser != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
}
