//
//  LoginView.swift
//  broche
//
//  Created by Zhu Zhanyan on 4/6/26.
//

import FirebaseAuth
import SwiftUI

struct LoginView: View {
    @Binding var isUnauthenticated: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false

    var body: some View {
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

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button {
                signIn()
            } label: {
                if isLoading {
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
            .disabled(email.isEmpty || password.isEmpty || isLoading)
        }
        .padding(32)
        .interactiveDismissDisabled()
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isLoading = false

            if let error {
                errorMessage = error.localizedDescription
                return
            }

            isUnauthenticated = false
        }
    }
}

#Preview {
    LoginView(isUnauthenticated: .constant(false))
}
