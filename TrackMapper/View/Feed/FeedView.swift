import SwiftUI

// MARK: - FeedView

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var activities: [ActivityDownload] = []
    @EnvironmentObject private var auth: AuthStore
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(activities) { activity in
                        NavigationLink(destination: CustomMapView(initialSelection: MapSelection.fromID(activity.mapId), activity: activity)) {
                            ActivityListItem(activity: activity, onClick: { id in
                                print("Clicked activity \(id)")
                            })
                        }
                    }
                }
            }
            .navigationTitle("Feed")
            .onAppear {
                viewModel.fetchMaps()
            }
            .onAppear {
                refreshActivities()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {refreshActivities()}) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
    
    func refreshActivities() {
        print(auth.currentUser)
        if let userId = auth.currentUser?.id {
            APIService.shared.friendActivities(userId: userId) { result in
                switch result {
                case .success(let activities):
                    self.activities = activities
                    print("Found \(activities.count) activities")
                case .failure(let error):
                    print("Error getting friends' activities: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FeedView()
}
