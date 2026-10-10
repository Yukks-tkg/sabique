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
    @Published var popularPlaylists: [CommunityPlaylist] = []
    @Published var newestPlaylists: [CommunityPlaylist] = []
    @Published var isLoading = false
    @Published var isLoadingPopular = false
    @Published var isLoadingNewest = false
    @Published var errorMessage: String?

    // プロフィール統計のキャッシュ
    @Published var cachedTotalLikes: Int? = nil
    @Published var cachedTotalDownloads: Int? = nil
    @Published var cachedTotalViews: Int? = nil
    @Published var cachedUserProfile: UserProfile? = nil
    @Published var cachedMyPublishedPlaylists: [CommunityPlaylist]? = nil

    /// アプリ起動時にプロフィールデータを事前取得
    func prefetchUserProfile(userId: String) async {
        async let likes = try? getTotalLikesForUser(userId: userId)
        async let downloads = try? getTotalDownloadsForUser(userId: userId)
        async let views = try? getTotalViewsForUser(userId: userId)
        async let profile = try? getUserProfile(userId: userId)
        async let playlists = try? getUserPlaylists(userId: userId)

        let (l, d, v, p, pl) = await (likes, downloads, views, profile, playlists)

        await MainActor.run {
            if let l { cachedTotalLikes = l }
            if let d { cachedTotalDownloads = d }
            if let v { cachedTotalViews = v }
            if let p { cachedUserProfile = p }
            if let pl { cachedMyPublishedPlaylists = pl }
        }
    }

    // MARK: - 投稿機能

    /// ユーザープロフィールを取得または作成
    func getUserProfile(userId: String) async throws -> UserProfile {
        let userDoc = try await db.collection("users").document(userId).getDocument()

        if let profile = try Self.decodeExistingUserProfile(
            documentExists: userDoc.exists,
            decode: { try userDoc.data(as: UserProfile.self) }
        ) {
            print("🔍 プロフィール取得成功:")
            print("  - userId: \(userId)")
            print("  - nickname: \(profile.nickname ?? "nil")")
            print("  - displayName: \(profile.displayName ?? "nil")")
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

    /// Only an absent document may fall through to profile creation.
    /// An existing document that cannot be decoded must remain untouched.
    static func decodeExistingUserProfile(
        documentExists: Bool,
        decode: () throws -> UserProfile
    ) throws -> UserProfile? {
        guard documentExists else { return nil }
        return try decode()
    }

    /// プレイリストをコミュニティに投稿
    func publishPlaylist(
        playlist: Playlist,
        authorId: String,
        authorName: String?,
        authorIsPremium: Bool,
        authorCountryCode: String?,
        authorArtworkURL: String?
    ) async throws {
        // プレイリスト名のバリデーション
        let validationResult = PlaylistValidator.validate(playlistName: playlist.name)
        guard validationResult.isValid else {
            throw CommunityError.validationFailed(validationResult.errorMessage ?? "不正な入力です")
        }

        // トラック数のバリデーション（サーバー側で再チェック）
        let trackCount = playlist.tracks.count
        guard trackCount >= 3 else {
            throw CommunityError.validationFailed("投稿には最低3曲必要です")
        }

        let maxTracks = authorIsPremium ? 100 : 3
        guard trackCount <= maxTracks else {
            throw CommunityError.validationFailed("投稿できる曲数は最大\(maxTracks)曲までです")
        }

        // 全ての曲にハイライトが設定されているか検証
        let allTracksHaveChorus = playlist.tracks.allSatisfy { track in
            track.chorusStartSeconds != nil && track.chorusEndSeconds != nil
        }
        guard allTracksHaveChorus else {
            throw CommunityError.validationFailed("全ての曲にハイライト区間を設定してください")
        }

        // ユーザープロフィールを取得
        let userProfile = try await getUserProfile(userId: authorId)

        // 投稿可能かチェック
        guard userProfile.canPublish(isPremium: authorIsPremium) else {
            throw CommunityError.publishLimitReached(isPremium: authorIsPremium)
        }

        // BANされていないかチェック
        guard !userProfile.isBanned else {
            throw CommunityError.userBanned
        }

        // ISRCを含むコミュニティプレイリストを作成
        let communityPlaylist = await CommunityPlaylist.fromWithISRC(
            playlist: playlist,
            authorId: authorId,
            authorName: authorName,
            authorIsPremium: authorIsPremium,
            authorCountryCode: authorCountryCode,
            authorArtworkURL: authorArtworkURL
        )

        // デバッグログ：Firestore保存直前のデータ
        print("🔍 Firestore保存直前のCommunityPlaylist:")
        print("  - name: \(communityPlaylist.name)")
        print("  - authorId: \(communityPlaylist.authorId)")
        print("  - authorName: \(communityPlaylist.authorName ?? "nil")")
        print("  - authorIsPremium: \(communityPlaylist.authorIsPremium)")
        print("  - authorCountryCode: \(communityPlaylist.authorCountryCode ?? "nil")")
        print("  - tracks count: \(communityPlaylist.tracks.count)")
        print("  - ISRCs: \(communityPlaylist.tracks.map { $0.isrc ?? "nil" })")

        do {
            // プレイリストを投稿
            let docRef = try db.collection("communityPlaylists").addDocument(from: communityPlaylist)
            print("✅ Firestore保存成功: documentID=\(docRef.documentID)")

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

    /// 人気・新着両方のプレイリストを同時に取得
    func fetchAllPlaylists(limit: Int = 20) async throws {
        await MainActor.run {
            isLoading = true
            isLoadingPopular = true
            isLoadingNewest = true
        }

        async let popularTask = fetchPopularPlaylists(limit: limit)
        async let newestTask = fetchNewestPlaylists(limit: limit)

        do {
            let (popular, newest) = try await (popularTask, newestTask)
            await MainActor.run {
                self.popularPlaylists = popular
                self.newestPlaylists = newest
                self.playlists = popular // デフォルトは人気
                self.isLoading = false
                self.isLoadingPopular = false
                self.isLoadingNewest = false
            }
            print("✅ 両方のプレイリスト取得成功: 人気\(popular.count)件, 新着\(newest.count)件")
        } catch {
            await MainActor.run {
                self.errorMessage = "プレイリストの取得に失敗しました"
                self.isLoading = false
                self.isLoadingPopular = false
                self.isLoadingNewest = false
            }
            throw error
        }
    }

    /// 人気プレイリストを取得
    private func fetchPopularPlaylists(limit: Int) async throws -> [CommunityPlaylist] {
        let query = db.collection("communityPlaylists")
            .order(by: "likeCount", descending: true)
            .limit(to: limit)
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityPlaylist.self) }
    }

    /// 新着プレイリストを取得
    private func fetchNewestPlaylists(limit: Int) async throws -> [CommunityPlaylist] {
        let query = db.collection("communityPlaylists")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityPlaylist.self) }
    }

    /// プレイリスト一覧を取得（既存互換用）
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
                // 個別のリストも更新
                switch sortBy {
                case .popular:
                    self.popularPlaylists = fetchedPlaylists
                case .newest:
                    self.newestPlaylists = fetchedPlaylists
                }
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
    /// - Parameters:
    ///   - countDownload: 利用数にカウントするか（自分の投稿の場合はfalse）
    /// - Returns: (インポートした曲数, スキップされた曲数)
    func importPlaylist(
        communityPlaylist: CommunityPlaylist,
        modelContext: ModelContext,
        isPremium: Bool,
        countDownload: Bool = true
    ) async throws -> (importedCount: Int, skippedCount: Int) {
        // 無料会員は最大3曲まで
        let maxTracks = isPremium ? communityPlaylist.tracks.count : FreeTierLimits.maxTracksPerPlaylist
        let tracksToImport = Array(communityPlaylist.tracks.prefix(maxTracks))
        let skippedCount = max(0, communityPlaylist.tracks.count - maxTracks)

        // 新しいプレイリストを作成
        let newPlaylist = Playlist(name: communityPlaylist.name, orderIndex: 0)
        modelContext.insert(newPlaylist)

        // トラックを追加（MusicKitからローカライズ名を取得）
        for (index, communityTrack) in tracksToImport.enumerated() {
            let track = communityTrack.toTrackInPlaylist(orderIndex: index)

            // デバイス言語に合ったタイトル・アーティスト名を取得
            if let localized = await TrackInPlaylist.fetchLocalizedInfo(songId: communityTrack.appleMusicId) {
                track.title = localized.title
                track.artist = localized.artist
            }

            track.playlist = newPlaylist
            modelContext.insert(track)
        }

        // 自分の投稿でない場合のみダウンロード数をインクリメント
        if countDownload {
            await incrementDownloadCount(playlistId: communityPlaylist.id ?? "")
        }

        print("✅ インポート成功: \(communityPlaylist.name) (\(tracksToImport.count)曲インポート, \(skippedCount)曲スキップ, カウント: \(countDownload))")

        return (tracksToImport.count, skippedCount)
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
        guard !playlistId.isEmpty else {
            print("⚠️ いいね数更新スキップ: playlistIdが空です")
            return
        }
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
        guard !playlistId.isEmpty else {
            print("⚠️ ダウンロード数更新スキップ: playlistIdが空です")
            return
        }
        do {
            try await db.collection("communityPlaylists").document(playlistId).updateData([
                "downloadCount": FieldValue.increment(Int64(1))
            ])
            print("✅ ダウンロード数更新")
        } catch {
            print("❌ ダウンロード数更新失敗: \(error)")
        }
    }

    /// 閲覧数をインクリメント
    func incrementViewCount(playlistId: String) async {
        guard !playlistId.isEmpty else {
            print("⚠️ 閲覧数更新スキップ: playlistIdが空です")
            return
        }
        do {
            try await db.collection("communityPlaylists").document(playlistId).updateData([
                "viewCount": FieldValue.increment(Int64(1))
            ])
            print("✅ 閲覧数更新")
        } catch {
            print("❌ 閲覧数更新失敗: \(error)")
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
        // ニックネームのバリデーション
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedNickname.isEmpty else {
            throw CommunityError.validationFailed("ニックネームを入力してください")
        }

        guard trimmedNickname.count <= 10 else {
            throw CommunityError.validationFailed("ニックネームは10文字以内にしてください")
        }

        // NGワードチェック
        let ngResult = PlaylistValidator.validateNickname(trimmedNickname)
        guard ngResult.isValid else {
            throw CommunityError.validationFailed(ngResult.errorMessage ?? "不正な入力です")
        }

        // 不正な文字のチェック（制御文字やゼロ幅文字など）
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.punctuationCharacters)
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "あ-んア-ンー一-龯ぁ-ゔァ-ヴｱ-ﾝﾞﾟ"))

        if trimmedNickname.unicodeScalars.contains(where: { !allowedCharacterSet.contains($0) }) {
            // 基本的な文字以外が含まれている場合は警告（ただしエラーにはしない - 多言語対応のため）
            print("⚠️ ニックネームに特殊文字が含まれています: \(trimmedNickname)")
        }

        // クールダウンチェック
        let userProfile = try await getUserProfile(userId: userId)
        let (canChange, remainingDays) = userProfile.canChangeNickname()
        guard canChange else {
            throw CommunityError.cooldownActive(remainingDays: remainingDays)
        }

        print("🔍 ニックネーム更新開始:")
        print("  - userId: \(userId)")
        print("  - nickname: \(trimmedNickname)")

        try await db.collection("users").document(userId).updateData([
            "nickname": trimmedNickname,
            "nicknameChangeCount": FieldValue.increment(Int64(1)),
            "lastNicknameChangeAt": Timestamp(date: Date())
        ])
        print("✅ ニックネーム更新成功: \(trimmedNickname)")
    }

    /// プロフィールアートワークを更新
    func updateProfileArtwork(userId: String, artworkURL: String, songTitle: String, artistName: String) async throws {
        // URLの検証
        guard let url = URL(string: artworkURL), url.scheme == "https" else {
            throw CommunityError.validationFailed("無効なアートワークURLです")
        }

        // Apple Music CDNのURLかチェック（セキュリティ強化）
        let allowedHosts = ["is1-ssl.mzstatic.com", "is2-ssl.mzstatic.com", "is3-ssl.mzstatic.com",
                           "is4-ssl.mzstatic.com", "is5-ssl.mzstatic.com"]
        guard let host = url.host, allowedHosts.contains(host) else {
            throw CommunityError.validationFailed("Apple Music以外のアートワークは使用できません")
        }

        // 曲名とアーティスト名の長さチェック
        let trimmedTitle = songTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artistName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTitle.count <= 200 else {
            throw CommunityError.validationFailed("曲名が長すぎます")
        }

        guard trimmedArtist.count <= 200 else {
            throw CommunityError.validationFailed("アーティスト名が長すぎます")
        }

        try await db.collection("users").document(userId).updateData([
            "profileArtworkURL": artworkURL,
            "profileSongTitle": trimmedTitle,
            "profileArtistName": trimmedArtist
        ])
        print("✅ プロフィールアートワーク更新成功")
    }

    /// 国コードを更新
    func updateCountryCode(userId: String, countryCode: String) async throws {
        // 国コードの検証（ISO 3166-1 alpha-2形式: 2文字の大文字、または空文字）
        let trimmedCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedCode.isEmpty {
            // 空でない場合は2文字の大文字アルファベットか検証
            guard trimmedCode.count == 2,
                  trimmedCode.allSatisfy({ $0.isLetter && $0.isUppercase }) else {
                throw CommunityError.validationFailed("無効な国コードです")
            }
        }

        // クールダウンチェック
        let userProfile = try await getUserProfile(userId: userId)
        let (canChange, remainingDays) = userProfile.canChangeCountry()
        guard canChange else {
            throw CommunityError.cooldownActive(remainingDays: remainingDays)
        }

        try await db.collection("users").document(userId).updateData([
            "countryCode": trimmedCode,
            "countryChangeCount": FieldValue.increment(Int64(1)),
            "lastCountryChangeAt": Timestamp(date: Date())
        ])
        print("✅ 国コード更新成功: \(trimmedCode)")
    }

    /// ユーザーが投稿したプレイリストの合計いいね数を取得
    func getTotalLikesForUser(userId: String) async throws -> Int {
        let snapshot = try await db.collection("communityPlaylists")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()

        let totalLikes = snapshot.documents.reduce(0) { sum, document in
            let likeCount = document.data()["likeCount"] as? Int ?? 0
            return sum + likeCount
        }

        return totalLikes
    }

    /// ユーザーが投稿したプレイリストの合計インポート数を取得
    func getTotalDownloadsForUser(userId: String) async throws -> Int {
        let snapshot = try await db.collection("communityPlaylists")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()

        let totalDownloads = snapshot.documents.reduce(0) { sum, document in
            let downloadCount = document.data()["downloadCount"] as? Int ?? 0
            return sum + downloadCount
        }

        return totalDownloads
    }

    /// ユーザーが投稿したプレイリストの合計閲覧数を取得
    func getTotalViewsForUser(userId: String) async throws -> Int {
        let snapshot = try await db.collection("communityPlaylists")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()

        let totalViews = snapshot.documents.reduce(0) { sum, document in
            let viewCount = document.data()["viewCount"] as? Int ?? 0
            return sum + viewCount
        }

        return totalViews
    }

    /// ユーザーが投稿したプレイリスト一覧を取得
    func getUserPlaylists(userId: String) async throws -> [CommunityPlaylist] {
        print("🔍 getUserPlaylists開始: userId=\(userId)")

        let snapshot = try await db.collection("communityPlaylists")
            .whereField("authorId", isEqualTo: userId)
            // インデックスが作成されるまで一時的にソートを無効化
            // .order(by: "createdAt", descending: true)
            .getDocuments()

        print("📦 Firestore検索結果: \(snapshot.documents.count)件")

        let playlists = snapshot.documents.compactMap { document -> CommunityPlaylist? in
            let playlist = try? document.data(as: CommunityPlaylist.self)
            if playlist == nil {
                print("⚠️ プレイリスト変換失敗: \(document.documentID)")
            }
            return playlist
        }

        print("✅ getUserPlaylists完了: \(playlists.count)件のプレイリストを返却")
        return playlists
    }

    // MARK: - アカウント削除機能

    /// ユーザーの全データを削除（アカウント削除時に使用）
    func deleteAllUserData(userId: String) async throws {
        print("🗑️ ユーザーデータ削除開始: \(userId)")

        // 1. ユーザーが投稿した全プレイリストを削除
        let playlistsSnapshot = try await db.collection("communityPlaylists")
            .whereField("authorId", isEqualTo: userId)
            .getDocuments()

        for document in playlistsSnapshot.documents {
            try await document.reference.delete()
            print("  ✅ プレイリスト削除: \(document.documentID)")
        }
        print("✅ \(playlistsSnapshot.documents.count)件のプレイリストを削除")

        // 2. ユーザーのいいね履歴を削除（likesコレクションがある場合）
        let likesSnapshot = try await db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        for document in likesSnapshot.documents {
            try await document.reference.delete()
        }
        print("✅ \(likesSnapshot.documents.count)件のいいね履歴を削除")

        // 3. ユーザーの通報履歴を削除
        let reportsSnapshot = try await db.collection("reports")
            .whereField("reporterUserId", isEqualTo: userId)
            .getDocuments()

        for document in reportsSnapshot.documents {
            try await document.reference.delete()
        }
        print("✅ \(reportsSnapshot.documents.count)件の通報履歴を削除")

        // 4. ユーザープロフィールを削除
        try await db.collection("users").document(userId).delete()
        print("✅ ユーザープロフィールを削除")

        print("🗑️ ユーザーデータ削除完了: \(userId)")
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
    case publishLimitReached(isPremium: Bool)
    case userBanned
    case validationFailed(String)
    case cooldownActive(remainingDays: Int)

    var errorDescription: String? {
        switch self {
        case .playlistNotFound:
            return "プレイリストが見つかりません"
        case .importFailed:
            return "インポートに失敗しました"
        case .publishLimitReached(let isPremium):
            if isPremium {
                return "今月の投稿上限（\(FreeTierLimits.maxPremiumPublishesPerMonth)回）に達しました。来月になるとリセットされます。"
            } else {
                return "今月の投稿上限（\(FreeTierLimits.maxPublishesPerMonth)回）に達しました。プレミアム版にアップグレードすると月\(FreeTierLimits.maxPremiumPublishesPerMonth)回まで投稿できます。"
            }
        case .userBanned:
            return "このアカウントは利用停止になっています"
        case .validationFailed(let message):
            return message
        case .cooldownActive(let remainingDays):
            return String(format: NSLocalizedString("profile_change_cooldown_error", comment: ""), remainingDays)
        }
    }
}
