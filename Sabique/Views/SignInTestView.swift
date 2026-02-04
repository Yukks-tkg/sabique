//
//  SignInTestView.swift
//  Sabique
//
//  Apple Sign Inのテスト画面
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct SignInTestView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 30) {
            if authManager.isSignedIn {
                // サインイン済み
                signedInView
            } else {
                // サインインしていない
                signInView
            }
        }
        .padding()
    }

    var signedInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("サインイン成功！")
                .font(.title)
                .bold()

            if let email = authManager.currentUser?.email {
                Text("メール: \(email)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let userId = authManager.currentUser?.uid {
                Text("ユーザーID: \(userId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                authManager.signOut()
            }) {
                Text("サインアウト")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
    }

    var signInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Apple Sign Inテスト")
                .font(.title)
                .bold()

            Text("Apple IDでサインインしてください")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    let nonce = authManager.generateNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authManager.sha256(nonce)
                },
                onCompletion: { result in
                    Task {
                        switch result {
                        case .success(let authorization):
                            do {
                                try await authManager.signInWithApple(authorization: authorization)
                            } catch {
                                print("サインインエラー: \(error)")
                            }
                        case .failure(let error):
                            print("Apple Sign Inエラー: \(error)")
                        }
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
        }
    }
}

#Preview {
    SignInTestView()
        .environmentObject(AuthManager())
}
