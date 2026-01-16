//
//  MainTabView.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 3/27/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                FeedView()
            }
            .tabItem {
                Label("Feed", systemImage: "list.dash")
            }
            
            NavigationView {
                MyMapsView()
            }
            .tabItem {
                Label("My Maps", systemImage: "map")
            }
            
            NavigationView {
                RecordView()
            }
            .tabItem {
                Label("Record", systemImage: "record.circle")
            }
            
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
    }
}

#Preview {
    MainTabView()
}
