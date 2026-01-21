//
//  LoginView.swift
//  TrackMapper
//
//  Created by Arnav Nayak on 3/27/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @State private var email: String = "prattdawn@example.com"
    @State private var password: String = "user_deborah02"
    @State private var error: String?
    @State private var isLoading: Bool = false
    @EnvironmentObject var auth: AuthStore
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Login")
                    .font(.largeTitle)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                if let error = error { Text(error).foregroundColor(.red).font(.caption) }
                Button(action: login) {
                    HStack { if isLoading { ProgressView() } ; Text("Sign In") }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isLoading)
                
                GoogleSignInButton(action: signInWithGoogle)
                    .frame(height: 44)
                    .disabled(isLoading)
                
                SignInWithAppleButton(onRequest: { _ in }, onCompletion: { _ in })
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .padding(.top, 8)
                    .disabled(true)
                    .overlay(Text("Apple Sign-In (dev placeholder)").font(.footnote).foregroundColor(.secondary))
                
                NavigationLink("Create an account", destination: RegistrationView())
                    .padding(.top, 8)
            }
            .padding()
        }
    }
    
    func login() {
        error = nil
        isLoading = true
        AuthService.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let payload):
                    auth.token = payload.token
                    auth.currentUser = payload.user
                case .failure(let e):
                    error = e.localizedDescription
                }
            }
        }
    }
    
    func signInWithGoogle() {
        error = nil
        isLoading = true
        guard let presentingViewController = topViewController() else {
            error = "Unable to present Google Sign-In."
            isLoading = false
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, signInError in
            DispatchQueue.main.async {
                isLoading = false
                if let signInError {
                    error = signInError.localizedDescription
                    return
                }
                guard let result else {
                    error = "Google Sign-In returned no result."
                    return
                }
                
                let user = result.user
                let email = user.profile?.email ?? ""
                let firstname = user.profile?.givenName ?? ""
                let lastname = user.profile?.familyName ?? ""
                let username = email.split(separator: "@").first.map(String.init) ?? email
                let googleId = user.userID ?? ""
                
                AuthService.shared.googleLogin(
                    email: email,
                    googleId: googleId,
                    firstname: firstname.isEmpty ? "Google" : firstname,
                    lastname: lastname,
                    username: username
                ) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let payload):
                            auth.token = payload.token
                            auth.currentUser = payload.user
                        case .failure(let e):
                            error = e.localizedDescription
                        }
                    }
                }
            }
        }
    }
    
    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        var topController = window?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}

//#Preview {
//    LoginView(isLoggedIn: .constant(false))
//}
