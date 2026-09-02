//
//  LoginView.swift
//  broche
//
//  Created by Zhu Zhanyan on 4/6/26.
//

import FirebaseAuth
import SwiftUI

/// Authentication screen offering two methods: Firebase email/password sign-in
/// and Bring Your Own Key (BYOK) token-based access.
///
/// On success, sets ``isUnauthenticated`` to `false` to dismiss the sheet.
struct LoginView: View {
    /// Controls whether the login sheet is presented.
    /// Set to `false` on successful authentication.
    @Binding var isUnauthenticated: Bool

    @State private var selectedTab = 0

    @State private var email = ""
    @State private var password = ""
    @State private var authErrorMessage: String? = nil
    @State private var authIsLoading = false

    @State private var openRouterToken = ""
    @State private var replicateToken = ""
    @State private var byokErrorMessage: String? = nil
    @State private var byokIsLoading = false

    var body: some View {
        TabView(selection: $selectedTab) {
            firebaseLoginTab
                .tabItem {
                    Label("Sign In", systemImage: "person.crop.circle")
                }
                .tag(0)

            byokLoginTab
                .tabItem {
                    Label("BYOK", systemImage: "key")
                }
                .tag(1)
        }
        .padding(32)
        .interactiveDismissDisabled()
    }

    /// Firebase email/password sign-in form.
    private var firebaseLoginTab: some View {
        VStack(spacing: 32) {
            Text("Login")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.subheadline)
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    SecureField("••••••••", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                }

                if let authErrorMessage {
                    Text(authErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button {
                signIn()
            } label: {
                if authIsLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || authIsLoading)
        }
    }

    /// Bring Your Own Key form where the user manually enters
    /// OpenRouter and Replicate API tokens.
    ///
    /// On connect, injects a ``StaticSecrets`` instance into
    /// ``DefaultAIModelFactory/shared`` so all AI models use the provided keys.
    private var byokLoginTab: some View {
        VStack(spacing: 32) {
            Text("API Tokens")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenRouter Token")
                        .font(.subheadline)
                    SecureField("sk-or-...", text: $openRouterToken)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Replicate Token")
                        .font(.subheadline)
                    SecureField("r8_...", text: $replicateToken)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let byokErrorMessage {
                    Text(byokErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button {
                connectWithKeys()
            } label: {
                if byokIsLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                openRouterToken.isEmpty || replicateToken.isEmpty || byokIsLoading
            )
        }
    }

    /// Signs in with Firebase using ``email`` and ``password``.
    ///
    /// On failure, displays the error message inline.
    /// On success, sets ``isUnauthenticated`` to `false`.
    private func signIn() {
        authIsLoading = true
        authErrorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            authIsLoading = false

            if let error {
                authErrorMessage = error.localizedDescription
                return
            }

            isUnauthenticated = false
        }
    }

    /// Validates and applies the user-provided API tokens.
    ///
    /// Trims whitespace, then sets ``DefaultAIModelFactory/shared`` secrets
    /// to a ``StaticSecrets`` instance built from the input tokens.
    /// On success, sets ``isUnauthenticated`` to `false`.
    private func connectWithKeys() {
        byokIsLoading = true
        byokErrorMessage = nil

        let trimmedOR = openRouterToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRep = replicateToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOR.isEmpty, !trimmedRep.isEmpty else {
            byokErrorMessage = "Tokens must not be empty."
            byokIsLoading = false
            return
        }

        DefaultAIModelFactory.shared.secrets = StaticSecrets(
            openRouter: trimmedOR,
            replicate: trimmedRep
        )

        isUnauthenticated = false
    }
}

#Preview {
    LoginView(isUnauthenticated: .constant(false))
}
