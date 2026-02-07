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

    // クールダウン管理（ニックネーム）
    var nicknameChangeCount: Int  // ニックネーム変更回数
    var lastNicknameChangeAt: Date?  // 最後にニックネームを変更した日時

    // クールダウン管理（国コード）
    var countryChangeCount: Int  // 国コード変更回数
    var lastCountryChangeAt: Date?  // 最後に国コードを変更した日時

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
        case nicknameChangeCount
        case lastNicknameChangeAt
        case countryChangeCount
        case lastCountryChangeAt
    }

    init(
        id: String? = nil,
        displayName: String? = nil,
        nickname: String? = nil,
        profileArtworkURL: String? = nil,
        profileSongTitle: String? = nil,
        profileArtistName: String? = nil,
        countryCode: String? = nil,
        createdAt: Date = Date(),
        publishedPlaylistCount: Int = 0,
        lastPublishedMonth: String = "",
        isPremium: Bool = false,
        isBanned: Bool = false,
        nicknameChangeCount: Int = 0,
        lastNicknameChangeAt: Date? = nil,
        countryChangeCount: Int = 0,
        lastCountryChangeAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.nickname = nickname
        self.profileArtworkURL = profileArtworkURL
        self.profileSongTitle = profileSongTitle
        self.profileArtistName = profileArtistName
        self.countryCode = countryCode
        self.createdAt = createdAt
        self.publishedPlaylistCount = publishedPlaylistCount
        self.lastPublishedMonth = lastPublishedMonth
        self.isPremium = isPremium
        self.isBanned = isBanned
        self.nicknameChangeCount = nicknameChangeCount
        self.lastNicknameChangeAt = lastNicknameChangeAt
        self.countryChangeCount = countryChangeCount
        self.lastCountryChangeAt = lastCountryChangeAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        profileArtworkURL = try container.decodeIfPresent(String.self, forKey: .profileArtworkURL)
        profileSongTitle = try container.decodeIfPresent(String.self, forKey: .profileSongTitle)
        profileArtistName = try container.decodeIfPresent(String.self, forKey: .profileArtistName)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        publishedPlaylistCount = try container.decode(Int.self, forKey: .publishedPlaylistCount)
        lastPublishedMonth = try container.decode(String.self, forKey: .lastPublishedMonth)
        isPremium = try container.decode(Bool.self, forKey: .isPremium)
        isBanned = try container.decode(Bool.self, forKey: .isBanned)
        // 既存ユーザー互換: フィールドが存在しない場合はデフォルト値
        nicknameChangeCount = try container.decodeIfPresent(Int.self, forKey: .nicknameChangeCount) ?? 0
        lastNicknameChangeAt = try container.decodeIfPresent(Date.self, forKey: .lastNicknameChangeAt)
        countryChangeCount = try container.decodeIfPresent(Int.self, forKey: .countryChangeCount) ?? 0
        lastCountryChangeAt = try container.decodeIfPresent(Date.self, forKey: .lastCountryChangeAt)
    }
}

extension UserProfile {
    /// ニックネーム変更可否をチェック
    /// - Returns: (allowed: 変更可能か, remainingDays: 残り日数)
    func canChangeNickname() -> (allowed: Bool, remainingDays: Int) {
        // 1回目は常に許可
        if nicknameChangeCount < 1 { return (true, 0) }

        // 2回目以降: 30日チェック
        guard let lastChange = lastNicknameChangeAt else { return (true, 0) }
        let daysSinceChange = Calendar.current.dateComponents([.day], from: lastChange, to: Date()).day ?? 0
        if daysSinceChange >= 30 { return (true, 0) }
        return (false, 30 - daysSinceChange)
    }

    /// 国コード変更可否をチェック
    /// - Returns: (allowed: 変更可能か, remainingDays: 残り日数)
    func canChangeCountry() -> (allowed: Bool, remainingDays: Int) {
        // 1回目は常に許可
        if countryChangeCount < 1 { return (true, 0) }

        // 2回目以降: 30日チェック
        guard let lastChange = lastCountryChangeAt else { return (true, 0) }
        let daysSinceChange = Calendar.current.dateComponents([.day], from: lastChange, to: Date()).day ?? 0
        if daysSinceChange >= 30 { return (true, 0) }
        return (false, 30 - daysSinceChange)
    }

    /// 現在の年月を取得（"2026-02" 形式）
    static func getCurrentYearMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    /// 今月の投稿可能回数を取得
    func remainingPublishesThisMonth(isPremium: Bool) -> Int {
        let maxPublishes = isPremium
            ? FreeTierLimits.maxPremiumPublishesPerMonth
            : FreeTierLimits.maxPublishesPerMonth

        let currentMonth = UserProfile.getCurrentYearMonth()

        // 月が変わっていればリセット
        if currentMonth != lastPublishedMonth {
            return maxPublishes
        }

        // 残り回数を計算
        return max(0, maxPublishes - publishedPlaylistCount)
    }

    /// 投稿可能かチェック
    func canPublish(isPremium: Bool) -> Bool {
        return remainingPublishesThisMonth(isPremium: isPremium) > 0
    }
}

// MARK: - FreeTierLimits拡張

extension FreeTierLimits {
    /// 月あたりの最大投稿数（無料）
    static let maxPublishesPerMonth = 3
    /// 月あたりの最大投稿数（プレミアム）
    static let maxPremiumPublishesPerMonth = 10
}
