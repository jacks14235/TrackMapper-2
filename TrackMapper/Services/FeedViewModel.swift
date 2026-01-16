//
//  FeedViewModel.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//
import SwiftUI

final class FeedViewModel: ObservableObject {
    @Published var maps: [MapPost] = []
    
    /// Fetches map posts from the server using the centralized APIService.
    func fetchMaps() {
//        APIService.shared.fetchMaps { [weak self] result in
//            DispatchQueue.main.async {
//                switch result {
//                case .success(let fetchedMaps):
//                    self?.maps = fetchedMaps
//                case .failure(let error):
//                    // Log the error. You might want to add user-friendly error handling here.
//                    print("Error fetching maps: \(error.localizedDescription)")
//                }
//            }
//        }
    }
}
