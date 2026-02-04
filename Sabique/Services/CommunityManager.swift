//
//  CommunityManager.swift
//  Sabique
//
//  コミュニティプレイリストの管理クラス
//

import Foundation
import Combine
import FirebaseFirestore
import SwiftData

class CommunityManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var playlists: [CommunityPlaylist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 投稿機能

    /// ユーザープロフィールを取得または作成
    func getUserProfile(userId: String) async throws -> UserProfile {
        let userDoc = try await db.collection("users").document(userId).getDocument()

        if let profile = try? userDoc.data(as: UserProfile.self) {
            return profile
        } else {
            // プロフィールが存在しない場合は作成
            let newProfile = UserProfile(
                id: userId,
                displayName: nil,
                createdAt: Date(),
                publishedPlaylistCount: 0,
                lastPublishedMonth: UserProfile.getCurrentYearMonth(),
                isPremium: false,
                isBanned: false
            )
            try db.collection("users").document(userId).setData(from: newProfile)
            return newProfile
        }
    }

    /// プレイリストをコミュニティに投稿
    func publishPlaylist(
        playlist: Playlist,
        authorId: String,
        authorName: String?,
        authorIsPremium: Bool
    ) async throws {
        // プレイリスト名のバリデーション
        let validationResult = PlaylistValidator.validate(playlistName: playlist.name)
        guard validationResult.isValid else {
            throw CommunityError.validationFailed(validationResult.errorMessage ?? "不正な入力です")
        }

        // ユーザープロフィールを取得
        let userProfile = try await getUserProfile(userId: authorId)

        // 投稿可能かチェック
        guard userProfile.canPublish(isPremium: authorIsPremium) else {
            throw CommunityError.publishLimitReached
        }

        // BANされていないかチェック
        guard !userProfile.isBanned else {
            throw CommunityError.userBanned
        }

        let communityPlaylist = CommunityPlaylist.from(
            playlist: playlist,
            authorId: authorId,
            authorName: authorName,
            authorIsPremium: authorIsPremium
        )

        do {
            // プレイリストを投稿
            _ = try db.collection("communityPlaylists").addDocument(from: communityPlaylist)

            // 投稿カウントを更新
            let currentMonth = UserProfile.getCurrentYearMonth()
            if currentMonth != userProfile.lastPublishedMonth {
                // 月が変わっていればリセット
                try await db.collection("users").document(authorId).updateData([
                    "publishedPlaylistCount": 1,
                    "lastPublishedMonth": currentMonth
                ])
            } else {
                // 同じ月ならインクリメント
                try await db.collection("users").document(authorId).updateData([
                    "publishedPlaylistCount": FieldValue.increment(Int64(1))
                ])
            }

            print("✅ プレイリスト投稿成功: \(playlist.name)")
        } catch {
            print("❌ プレイリスト投稿失敗: \(error)")
            throw error
        }
    }

    // MARK: - 閲覧機能

    /// プレイリスト一覧を取得
    func fetchPlaylists(sortBy: SortOption = .popular, limit: Int = 20) async throws {
        await MainActor.run { isLoading = true }

        do {
            let query: Query
            switch sortBy {
            case .popular:
                query = db.collection("communityPlaylists")
                    .order(by: "likeCount", descending: true)
                    .limit(to: limit)
            case .newest:
                query = db.collection("communityPlaylists")
                    .order(by: "createdAt", descending: true)
                    .limit(to: limit)
            }

            let snapshot = try await query.getDocuments()
            let fetchedPlaylists = snapshot.documents.compactMap { document -> CommunityPlaylist? in
                try? document.data(as: CommunityPlaylist.self)
            }

            await MainActor.run {
                self.playlists = fetchedPlaylists
                self.isLoading = false
            }

            print("✅ プレイリスト取得成功: \(fetchedPlaylists.count)件")
        } catch {
            await MainActor.run {
                self.errorMessage = "プレイリストの取得に失敗しました"
                self.isLoading = false
            }
            print("❌ プレイリスト取得失敗: \(error)")
            throw error
        }
    }

    /// プレイリストを検索
    func searchPlaylists(keyword: String, limit: Int = 20) async throws {
        await MainActor.run { isLoading = true }

        do {
            // Firestoreの制限により、完全一致検索のみ
            // プレイリスト名に含まれる検索（部分一致）はクライアント側でフィルタリング
            let snapshot = try await db.collection("communityPlaylists")
                .order(by: "likeCount", descending: true)
                .limit(to: 100)  // 多めに取得してフィルタリング
                .getDocuments()

            let allPlaylists = snapshot.documents.compactMap { document -> CommunityPlaylist? in
                try? document.data(as: CommunityPlaylist.self)
            }

            // クライアント側でフィルタリング（大文字小文字を区別しない）
            let lowercasedKeyword = keyword.lowercased()
            let filteredPlaylists = allPlaylists.filter { playlist in
                playlist.name.lowercased().contains(lowercasedKeyword) ||
                (playlist.authorName?.lowercased().contains(lowercasedKeyword) ?? false)
            }

            await MainActor.run {
                self.playlists = Array(filteredPlaylists.prefix(limit))
                self.isLoading = false
            }

            print("✅ 検索完了: \(filteredPlaylists.count)件")
        } catch {
            await MainActor.run {
                self.errorMessage = "検索に失敗しました"
                self.isLoading = false
            }
            print("❌ 検索失敗: \(error)")
            throw error
        }
    }

    /// 特定のプレイリストを取得
    func fetchPlaylist(id: String) async throws -> CommunityPlaylist {
        let document = try await db.collection("communityPlaylists").document(id).getDocument()
        guard let playlist = try? document.data(as: CommunityPlaylist.self) else {
            throw CommunityError.playlistNotFound
        }
        return playlist
    }

    // MARK: - インポート機能

    /// コミュニティプレイリストをマイプレイリストにインポート
    func importPlaylist(
        communityPlaylist: CommunityPlaylist,
        modelContext: ModelContext
    ) async throws {
        // 新しいプレイリストを作成
        let newPlaylist = Playlist(name: communityPlaylist.name, orderIndex: 0)
        modelContext.insert(newPlaylist)

        // トラックを追加
        for (index, communityTrack) in communityPlaylist.tracks.enumerated() {
            let track = communityTrack.toTrackInPlaylist(orderIndex: index)
            track.playlist = newPlaylist
            modelContext.insert(track)
        }

        // ダウンロード数をインクリメント
        await incrementDownloadCount(playlistId: communityPlaylist.id ?? "")

        print("✅ インポート成功: \(communityPlaylist.name)")
    }

    // MARK: - 報告機能

    /// プレイリストを報告
    func reportPlaylist(
        playlistId: String,
        reporterUserId: String,
        reason: ReportReason,
        comment: String?
    ) async throws {
        let report = PlaylistReport(
            id: nil,
            playlistId: playlistId,
            reporterUserId: reporterUserId,
            reason: reason.rawValue,
            comment: comment,
            createdAt: Date()
        )

        do {
            _ = try db.collection("reports").addDocument(from: report)
            print("✅ 報告送信成功")
        } catch {
            print("❌ 報告送信失敗: \(error)")
            throw error
        }
    }

    // MARK: - いいね機能

    /// いいね数をインクリメント
    func incrementLikeCount(playlistId: String) async {
        do {
            try await db.collection("communityPlaylists").document(playlistId).updateData([
                "likeCount": FieldValue.increment(Int64(1))
            ])
            print("✅ いいね数更新")
        } catch {
            print("❌ いいね数更新失敗: \(error)")
        }
    }

    /// ダウンロード数をインクリメント
    func incrementDownloadCount(playlistId: String) async {
        do {
            try await db.collection("communityPlaylists").document(playlistId).updateData([
                "downloadCount": FieldValue.increment(Int64(1))
            ])
            print("✅ ダウンロード数更新")
        } catch {
            print("❌ ダウンロード数更新失敗: \(error)")
        }
    }

    // MARK: - 削除機能（管理者用）

    /// プレイリストを削除
    func deletePlaylist(id: String) async throws {
        try await db.collection("communityPlaylists").document(id).delete()
        print("✅ プレイリスト削除成功")
    }

    // MARK: - プロフィール更新機能

    /// ニックネームを更新
    func updateNickname(userId: String, nickname: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "nickname": nickname
        ])
        print("✅ ニックネーム更新成功")
    }

    /// プロフィールアートワークを更新
    func updateProfileArtwork(userId: String, artworkURL: String, songTitle: String, artistName: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "profileArtworkURL": artworkURL,
            "profileSongTitle": songTitle,
            "profileArtistName": artistName
        ])
        print("✅ プロフィールアートワーク更新成功")
    }
}

// MARK: - Sort Option

enum SortOption {
    case popular  // 人気順
    case newest   // 新着順
}

// MARK: - Errors

enum CommunityError: LocalizedError {
    case playlistNotFound
    case importFailed
    case publishLimitReached
    case userBanned
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .playlistNotFound:
            return "プレイリストが見つかりません"
        case .importFailed:
            return "インポートに失敗しました"
        case .publishLimitReached:
            return "今月の投稿上限に達しました。プレミアム版にアップグレードすると無制限に投稿できます。"
        case .userBanned:
            return "このアカウントは利用停止になっています"
        case .validationFailed(let message):
            return message
        }
    }
}
