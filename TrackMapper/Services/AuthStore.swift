//
//  AuthStore.swift
//  TrackMapper
//
//  Created by ChatGPT on 8/16/25.
//

import Foundation

final class AuthStore: ObservableObject {
    @Published var token: String? {
        didSet { persist() }
    }
    @Published var currentUser: AuthUser?
    
    private let tokenKey = "auth_token"
    
    init() {
        token = KeychainHelper.read(key: tokenKey)
    }
    
    func persist() {
        if let token = token {
            KeychainHelper.save(token, key: tokenKey)
        } else {
            KeychainHelper.delete(key: tokenKey)
        }
    }
    
    func logout() {
        token = nil
        currentUser = nil
    }
}


