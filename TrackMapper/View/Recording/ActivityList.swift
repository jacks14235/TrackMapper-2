//
//  ActivityList.swift
//  TrackMapper
//
//  Created by Jack Stanley on 4/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ActivityList: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) var dismiss
    @State private var gpxData: String?
    @State private var activities: [ActivityDownload] = []
    @State private var fileImporter = false
    @State private var showModal = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Button(action: {fileImporter = true}) {
                    Text("Upload gpx")
                }
                List {
                    ForEach(activities.sorted(by: { $0.createdAt > $1.createdAt }), id: \.self) { activity in
                        NavigationLink(destination: CustomMapView(initialSelection: MapSelection.fromID(activity.mapId), activity: activity)) {
                            ActivityListItem(activity: activity, onClick: { id in
                                print("Clicked activity \(id)")
                            })
                        }
                    }
                    .onDelete(perform: deleteActivities)
                }
                .onAppear {
                    refreshActivities()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {refreshActivities()}) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.blue)
                }
            }
        }
        .fileImporter(
            isPresented: $fileImporter,
            // Use UTType to filter for files with a ".gpx" extension.
            allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .data],
            allowsMultipleSelection: false, // Only allow a single file to be picked.
            onCompletion: handleFileImport
        )
        .sheet(isPresented: $showModal) {
            SaveModalView (
                onSave: { title, description in
                    guard let userId = auth.currentUser?.id else { return }
                    if let data = gpxData, let stats = try? GPXUtils.stats(from: data) {
                        print("distance", stats.distanceMeters)
                        print("time", stats.elapsedTime)
                        // Note: mapId is now a String, using a placeholder for now
                        APIService.shared.uploadActivity(title: title, description: description, gpxData: data, createdAt: Date.now, userId: userId, mapId: "", distance: stats.distanceMeters, elapsedTime: stats.elapsedTime) { result in
                            switch result {
                            case .success(let activity):
                                activities.insert(activity, at: 0)
                            case .failure(let error):
                                print("Error uploading uploaded activity: \(error)")
                            }
                        }
                    }
                },
                onDelete: { }
            )
        }
        .padding()
    }
    
    private func refreshActivities() {
        guard let userId = auth.currentUser?.id else { return }
        APIService.shared.userActivities(userId: userId) { result in
            switch result {
            case .success(let resp):
                activities = resp
            case .failure(let error):
                print("Error downloading activities: \(error)")
            }
        }
    }
    
    private func deleteActivities(at offsets: IndexSet) {
        let toDelete = offsets.compactMap { idx in
            activities.indices.contains(idx) ? activities[idx] : nil
        }
        
        for activity in toDelete {
            APIService.shared.deleteActivity(activityId: activity.id) { result in
                switch result {
                case .success:
                    activities.removeAll { $0.id == activity.id }
                case .failure(let error):
                    print("Error deleting activity \(activity.id): \(error)")
                }
            }
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let sourceURL = urls.first {
                // Save the file (this works similar to your saveToFile() pattern)
                let _ = readImportedGPX(from: sourceURL)
                if let destinationURL = saveImportedFile(from: sourceURL) {
                    print("GPX file saved to \(destinationURL)")
//                    activities = loadActivities()
                }
            }
        case .failure(let error):
            print("File importer failed: \(error.localizedDescription)")
        }
    }
    
    private func readImportedGPX(from sourceURL: URL) -> String? {
        // 1. Start security-scope
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security-scoped resource")
            return nil
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        // 2. Read the file into a String
        do {
            let gpxString = try String(contentsOf: sourceURL, encoding: .utf8)
            self.gpxData = gpxString
            showModal = true
        } catch {
            print("❌ Error reading GPX file: \(error.localizedDescription)")
            return nil
        }
        return nil
    }
    
    private func saveImportedFile(from sourceURL: URL) -> URL? {
        // Start accessing security-scoped resource
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return nil
        }

        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }

        let fileName = "track_\(Date().timeIntervalSince1970).gpx"
        let destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to copy GPX file: \(error.localizedDescription)")
            return nil
        }
    }

}


struct ActivityListItem: View {
    var activity: ActivityDownload
    var onClick: (_ id: String) -> Void
    
    var body: some View {
        Button(action: { onClick(activity.id) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(.headline)
                    
                    Text(dateFormatter.string(from: activity.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(activity.username)
                        .font(.caption.smallCaps())
                        .foregroundColor(.gray)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let distance = activity.distance {
                        Text(String(format: "%.2f mi", distance / 1609.0))
                            .font(.subheadline)
                    }
                    if let time = activity.elapsedTime {
                        Text(humanReadable(time: time))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
}
