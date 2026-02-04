//
//  PlaylistValidator.swift
//  Sabique
//
//  プレイリスト投稿時のバリデーション
//

import Foundation

struct PlaylistValidator {
    // 文字数制限
    static let minNameLength = 3
    static let maxNameLength = 50

    // NGワード
    static let ngWords = [
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
        for word in ngWords {
            if lowercasedName.contains(word.lowercased()) {
                return .failure("使用できない単語が含まれています: \(word)")
            }
        }

        return .success(trimmedName)
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
