//
//  AuthManager.swift
//  Sabique
//
//  Firebase認証を管理するクラス
//

import Foundation
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

class AuthManager: ObservableObject {
    @Published var currentUser: FirebaseAuth.User?
    @Published var isSignedIn = false
    @Published var errorMessage: String?

    // Apple Sign In用のnonce
    private var currentNonce: String?

    init() {
        // 既存の認証状態をチェック
        self.currentUser = Auth.auth().currentUser
        self.isSignedIn = currentUser != nil

        // 認証状態の変更を監視
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isSignedIn = user != nil
            }
        }
    }

    /// Apple Sign Inを開始
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }

        guard let nonce = currentNonce else {
            throw AuthError.invalidNonce
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.missingToken
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.tokenSerializationFailed
        }

        // Firebaseの認証情報を作成
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        // Firebaseにサインイン
        let result = try await Auth.auth().signIn(with: credential)
        self.currentUser = result.user
        self.isSignedIn = true

        // 新規ユーザーの場合、Firestoreにユーザー情報を保存
        if result.additionalUserInfo?.isNewUser == true {
            await createUserProfile(
                userId: result.user.uid,
                displayName: appleIDCredential.fullName?.givenName
            )
        }
    }

    /// サインアウト
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isSignedIn = false
        } catch {
            self.errorMessage = "サインアウトに失敗しました: \(error.localizedDescription)"
        }
    }

    /// Nonceを生成（セキュリティのため）
    func generateNonce() -> String {
        let nonce = randomNonceString()
        self.currentNonce = nonce
        return nonce
    }

    /// SHA256ハッシュを生成
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    // MARK: - Private Methods

    /// ランダムなNonce文字列を生成
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// Firestoreに新規ユーザー情報を保存
    private func createUserProfile(userId: String, displayName: String?) async {
        // TODO: Phase 2でFirestoreへの保存を実装
        print("新規ユーザー作成: \(userId), 名前: \(displayName ?? "未設定")")
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case invalidCredential
    case invalidNonce
    case missingToken
    case tokenSerializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "認証情報が無効です"
        case .invalidNonce:
            return "セキュリティトークンが無効です"
        case .missingToken:
            return "認証トークンが見つかりません"
        case .tokenSerializationFailed:
            return "認証トークンの処理に失敗しました"
        }
    }
}
