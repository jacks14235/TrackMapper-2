import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var viewModel: ProfileViewModel

    init() {
        // create with shared session and auth; will be overridden by environmentObject when previewing
        _viewModel = StateObject(wrappedValue: ProfileViewModel(session: SessionManager.shared, auth: AuthStore()))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Info")) {
                    TextField("First Name", text: $viewModel.firstname)
                        .autocapitalization(.words)
                    TextField("Last Name", text: $viewModel.lastname)
                        .autocapitalization(.words)
                    TextField("Username", text: $viewModel.username)
                        .autocapitalization(.none)
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .disabled(true)
                    // SecureField("Password (leave blank to keep)", text: $viewModel.password)
                }

                Section {
                    Button(action: {
                        viewModel.saveProfile()
                    }) {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                    }
                }

                Section {
                    Button("Logout") {
                        auth.logout()
                        session.logout()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }

                if let msg = viewModel.message {
                    Section {
                        Text(msg)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Profile")
            .overlay(
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading...")
                    }
                }
            )
            .onAppear {
                // inject the real auth and session
                viewModel.session = session
                viewModel.auth = auth
                viewModel.loadProfile()
            }
        }
    }
}

#Preview {
    let auth = AuthStore()
    let session = SessionManager.shared
    ProfileView()
        .environmentObject(auth)
        .environmentObject(session)
}
