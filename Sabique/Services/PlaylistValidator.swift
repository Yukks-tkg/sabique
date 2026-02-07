//
//  PlaylistValidator.swift
//  Sabique
//
//  プレイリスト投稿時のバリデーション
//

import Foundation
import FirebaseFirestore

struct PlaylistValidator {
    // 文字数制限
    static let minNameLength = 3
    static let maxNameLength = 50

    // フォールバック用NGワード（Firestoreから取得できない場合に使用）
    static let fallbackNGWords = [
        "スパム",
        "宣伝",
        "広告",
        "フォロー",
        "相互",
        "フォロバ",
        "いいね",
        "LINE",
        "Instagram",
        "Twitter",
        "Discord"
    ]

    // リモートから取得したNGワードのキャッシュ
    private static var cachedNGWords: [String]?

    // 有効なNGワードリスト（キャッシュ優先、なければフォールバック）
    static var effectiveNGWords: [String] {
        cachedNGWords ?? fallbackNGWords
    }

    /// FirestoreからNGワードリストを取得してキャッシュ
    static func fetchNGWords() async {
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("config").document("ngWords").getDocument()
            if let words = document.data()?["words"] as? [String], !words.isEmpty {
                cachedNGWords = words
                print("✅ NGワードリスト取得成功: \(words.count)件")
            } else {
                print("⚠️ NGワードドキュメントが空またはフォーマット不正。フォールバックを使用")
            }
        } catch {
            print("❌ NGワード取得失敗（フォールバック使用）: \(error)")
        }
    }

    /// プレイリスト名をバリデーション
    static func validate(playlistName: String) -> ValidationResult {
        // 空白をトリム
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 文字数チェック
        if trimmedName.count < minNameLength {
            return .failure("プレイリスト名は\(minNameLength)文字以上必要です")
        }

        if trimmedName.count > maxNameLength {
            return .failure("プレイリスト名は\(maxNameLength)文字以内にしてください")
        }

        // NGワードチェック
        let lowercasedName = trimmedName.lowercased()
        for word in effectiveNGWords {
            if lowercasedName.contains(word.lowercased()) {
                return .failure("使用できない単語が含まれています: \(word)")
            }
        }

        return .success(trimmedName)
    }

    /// ニックネームのNGワードチェック
    static func validateNickname(_ text: String) -> ValidationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let lowercased = trimmed.lowercased()
        for word in effectiveNGWords {
            if lowercased.contains(word.lowercased()) {
                return .failure("使用できない単語が含まれています")
            }
        }

        return .success(trimmed)
    }
}

/// バリデーション結果
enum ValidationResult {
    case success(String)  // 成功（トリムされた名前）
    case failure(String)  // 失敗（エラーメッセージ）

    var isValid: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }

    var validatedValue: String? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
}
