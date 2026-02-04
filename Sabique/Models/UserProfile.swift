//
//  UserProfile.swift
//  Sabique
//
//  ユーザープロフィール（Firestore用）
//

import Foundation
import FirebaseFirestore

/// ユーザープロフィール
struct UserProfile: Codable {
    @DocumentID var id: String?
    var displayName: String?
    var nickname: String?  // 表示用ニックネーム
    var profileArtworkURL: String?  // プロフィールアイコン（アートワークURL）
    var profileSongTitle: String?  // プロフィールアイコンの曲名
    var profileArtistName: String?  // プロフィールアイコンのアーティスト名
    var countryCode: String?  // 国コード（ISO 3166-1 alpha-2: "JP", "US", "GB" など）
    var createdAt: Date
    var publishedPlaylistCount: Int
    var lastPublishedMonth: String  // "2026-02" 形式
    var isPremium: Bool
    var isBanned: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case nickname
        case profileArtworkURL
        case profileSongTitle
        case profileArtistName
        case countryCode
        case createdAt
        case publishedPlaylistCount
        case lastPublishedMonth
        case isPremium
        case isBanned
    }
}

extension UserProfile {
    /// 現在の年月を取得（"2026-02" 形式）
    static func getCurrentYearMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    /// 今月の投稿可能回数を取得
    func remainingPublishesThisMonth(isPremium: Bool) -> Int {
        // プレミアムユーザーは無制限
        if isPremium {
            return Int.max
        }

        let currentMonth = UserProfile.getCurrentYearMonth()

        // 月が変わっていればリセット
        if currentMonth != lastPublishedMonth {
            return FreeTierLimits.maxPublishesPerMonth
        }

        // 残り回数を計算
        return max(0, FreeTierLimits.maxPublishesPerMonth - publishedPlaylistCount)
    }

    /// 投稿可能かチェック
    func canPublish(isPremium: Bool) -> Bool {
        return remainingPublishesThisMonth(isPremium: isPremium) > 0
    }
}

// MARK: - FreeTierLimits拡張

extension FreeTierLimits {
    /// 月あたりの最大投稿数
    static let maxPublishesPerMonth = 3
}
