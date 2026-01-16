//
//  RecordView.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/10/25.
//
import SwiftUI
import MapKit

struct RecordView: View {
    @EnvironmentObject var locationStore: LocationManagerStore
    @EnvironmentObject var auth: AuthStore
    @State var location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var showModal = false
    @State private var mapID: MapSelection = .appleMap
    
    var body: some View {
        NavigationStack {
            VStack {
                CustomMapView(initialSelection: .appleMap, activity: nil)
                HStack {
                    if locationStore.isRecording {
                        Button(action: { showModal = true }) {
                            Image(systemName: "stop.circle")
                                .font(.system(size: 36))
                        }
                        if locationStore.isPaused {
                            Button(action: { locationStore.unpauseRecording() }) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 36))
                            }
                        } else {
                            Button(action: { locationStore.pauseRecording() }) {
                                Image(systemName: "pause.circle")
                                    .font(.system(size: 36))
                            }
                        }
                    } else {
                        Button(action: { locationStore.startRecording() }) {
                            Image(systemName: "play.circle")
                                .font(.system(size: 36))
                        }
                    }
                    Text(String(format: "%.2f mi", locationStore.totalDistance / 1609))
                    Text(Duration.seconds(locationStore.elapsedTime).formatted(.time(pattern: .hourMinuteSecond)))
                }
            }
            .sheet(isPresented: $showModal) {
                SaveModalView (
                    onSave: { title, description in
                        saveGpxData(title: title, description: description)
                        locationStore.resetDistance()
                    },
                    onDelete: {
                        _ = locationStore.stopRecording()
                        locationStore.resetDistance()
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ActivityList()) {
                        Image(systemName: "list.triangle")
                            .foregroundStyle(.blue)
                    }
                }
            }.onAppear {
                locationStore.startTracking()
            }.onDisappear() {
                if !locationStore.isRecording {
                    locationStore.stopTracking()
                }
            }
        }
    }
    
    func saveGpxData(title: String, description: String) {
        let data = locationStore.stopRecording()
        let distance = locationStore.totalDistance
        let elapsedTime = locationStore.elapsedTime
        if let userId = auth.currentUser?.id {
            APIService.shared.uploadActivity(title: title, description: description, gpxData: data, createdAt: Date.now, userId: userId, mapId: mapID.id ?? -1, distance: distance, elapsedTime: elapsedTime) { result in
                switch result {
                case .success(let activity):
                    print("Successfully uploaded activity with ID \(activity.id)")
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }
    }
    
}


struct SaveModalView: View {
    @EnvironmentObject var locationStore: LocationManagerStore
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    
    var onSave: (_ title: String, _ description: String) -> Void
    var onDelete: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Enter title", text: $title)
                        .autocapitalization(.sentences)
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        onDelete()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if title != "" {
                            onSave(title, description)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

