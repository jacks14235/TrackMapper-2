//
//  SessionManager.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//

import Foundation
import Combine
import UIKit

struct MapMakerDraftState {
    var title: String = ""
    var description: String = ""
    var picked: Int = 0
    var imageData: Data? = nil
    var pairs: [CoordPair] = []
}

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var currentUser: UserProfile?
    @Published var mapMakerDrafts: [String: MapMakerDraftState] = [:]
    
    private init() {}
    
    func logout() {
        currentUser = nil
    }
    
    func mapMakerDraft(for key: String) -> MapMakerDraftState? {
        mapMakerDrafts[key]
    }
    
    func saveMapMakerDraft(_ draft: MapMakerDraftState, for key: String) {
        mapMakerDrafts[key] = draft
    }
    
    func clearMapMakerDraft(for key: String) {
        mapMakerDrafts.removeValue(forKey: key)
    }
}
