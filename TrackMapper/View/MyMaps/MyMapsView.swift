//
//  MyMapsView.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/10/25.
//

import SwiftUI

struct MyMapsView: View {
    @EnvironmentObject var auth: AuthStore
    @State var maps: [MapDownload] = []
    @State var error: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(maps) { map in
                        NavigationLink {
                            MapMakerView(mapDownload: map)
//                            CustomMapView(mapHash: map.hash)
                        } label: {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading) {
                                    Text(map.title).font(.headline)
                                    Text(map.description).font(.subheadline).foregroundColor(.secondary)
                                    Text(map.username).font(.footnote).foregroundColor(.secondary).fontWeight(.bold)
                                }
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("My Maps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MapMakerView()) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MapSearch()) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {getUserMaps()}) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.blue)
                    }
                }
            }
            .onAppear() {
                getUserMaps()
            }
        }
    }
    
    func getUserMaps() {
        guard let userId = auth.currentUser?.id else { return }
        APIService.shared.userMaps(userId: userId, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let maps):
                    print("Fetched \(maps.count) maps:")
                    for map in maps {
                        print(" • \(map.title) @ \(map.latitude),\(map.longitude)")
                    }
                    self.maps = maps
                case .failure(let error):
                    print("Error fetching maps:", error.localizedDescription)
                    self.error = error.localizedDescription
                }
            }
        })
    }
    
    func delete(at offsets: IndexSet) {
        for index in offsets {
            let map = maps[index]
            APIService.shared.deleteMap(mapId: map.id) { result in
                DispatchQueue.main.async {
                    if deleteLocalMap(id: map.id) {
                        print("Deleted")
                    } else {
                        print("Failed to delete")
                    }
                    maps.remove(at: index)
                }
            }
        }
    }
}
