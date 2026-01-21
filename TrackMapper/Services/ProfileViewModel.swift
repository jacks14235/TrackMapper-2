//
//  ProfileViewModel.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//

import SwiftUI

final class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var message: String? = nil
    
    var session: SessionManager?
    var auth: AuthStore?

    init(session: SessionManager? = nil, auth: AuthStore? = nil) {
        self.session = session
        self.auth = auth
    }

    func configure(session: SessionManager, auth: AuthStore) {
        self.session = session
        self.auth = auth
    }
    
    /// Retrieves the current user ID from the session.
    var currentUserID: String? {
        // AuthService returns integer IDs, prefer auth.currentUser
        return auth?.currentUser?.id
    }
    
    /// Loads the profile for the current user.
    func loadProfile() {
        guard let userID = currentUserID else {
            self.message = "User not logged in."
            return
        }
        isLoading = true
        APIService.shared.fetchUserProfile(userID: userID) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let profile):
                    self?.name = profile.firstname
                    self?.username = profile.username
                    self?.password = ""
                    self?.email = profile.email
                case .failure(let error):
                    self?.message = "Failed to load profile: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Saves the updated profile details for the current user.
    func saveProfile() {
        guard let userID = currentUserID else {
            self.message = "User not logged in."
            return
        }
        var updatedData: [String: String] = [
            "firstname": name,
            "username": username
        ]
        if !password.isEmpty { updatedData["password"] = password }
        if !email.isEmpty { updatedData["email"] = email }
        isLoading = true
        APIService.shared.updateUserProfile(userID: userID, updatedData: updatedData) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let profile):
                    self?.message = "Profile updated successfully."
                    // update session/auth user
                    self?.session?.currentUser?.name = profile.firstname
                    self?.session?.currentUser?.username = profile.username
                case .failure(let error):
                    self?.message = "Error updating profile: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Logs the user out by clearing the session and local profile fields.
    func logout() {
        session?.logout()
        self.name = ""
        self.username = ""
        self.password = ""
        self.message = "Logged out."
    }
}
