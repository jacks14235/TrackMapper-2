//
//  RegistrationView.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 4/15/25.
//

import SwiftUI

struct RegistrationView: View {
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMsg: String?
    @State private var isRegistering: Bool = false
    @EnvironmentObject var auth: AuthStore
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Name", text: $name)
                    .autocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                if let errorMsg = errorMsg {
                    Text(errorMsg)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if isRegistering {
                    ProgressView("Registering...")
                }
                
                Button(action: {
                    registerUser()
                }) {
                    Text("Register")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Register")
        }
    }
    
    func registerUser() {
        isRegistering = true
        errorMsg = nil
        AuthService.shared.register(email: email, password: password) { result in
            DispatchQueue.main.async {
                self.isRegistering = false
                switch result {
                case .success(let payload):
                    auth.token = payload.token
                    auth.currentUser = payload.user
                case .failure(let error):
                    self.errorMsg = error.localizedDescription
                }
            }
        }
    }
}
