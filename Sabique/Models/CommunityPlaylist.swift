//
//  CommunityPlaylist.swift
//  Sabique
//
//  コミュニティプレイリストのモデル
//

import Foundation
import FirebaseFirestore
import MusicKit

/// コミュニティプレイリスト（Firestore用）
/// カスタムinit(from decoder:)は@DocumentIDの自動注入を妨げるため使用しない
struct CommunityPlaylist: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var authorId: String
    var authorName: String?
    var authorIsPremium: Bool
    var authorCountryCode: String?   // 投稿時の国コード（スナップショット）
    var authorArtworkURL: String?    // 投稿時のアートワークURL（スナップショット）
    var tracks: [CommunityTrack]
    var songIds: [String]  // 検索用（曲IDのリスト）
    var likeCount: Int
    var downloadCount: Int
    var viewCount: Int?  // 古いドキュメントにはこのフィールドがない場合がある
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case authorId
        case authorName
        case authorIsPremium
        case authorCountryCode
        case authorArtworkURL
        case tracks
        case songIds
        case likeCount
        case downloadCount
        case viewCount
        case createdAt
    }

    /// viewCountの安全なアクセス（nilの場合は0を返す）
    var safeViewCount: Int {
        viewCount ?? 0
    }
}

/// コミュニティプレイリスト内のトラック
struct CommunityTrack: Identifiable, Codable {
    var id: String  // UUID
    var appleMusicId: String
    var isrc: String?
    var title: String
    var artist: String
    var chorusStart: Double?
    var chorusEnd: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case appleMusicId
        case isrc
        case title
        case artist
        case chorusStart
        case chorusEnd
    }
}

// MARK: - 変換ヘルパー

extension CommunityPlaylist {
    /// マイプレイリストからコミュニティプレイリストを作成（ISRCなし）
    /// この関数は非推奨。代わりにasyncバージョンを使用してください。
    static func from(
        playlist: Playlist,
        authorId: String,
        authorName: String?,
        authorIsPremium: Bool,
        authorCountryCode: String?,
        authorArtworkURL: String?
    ) -> CommunityPlaylist {
        let communityTracks = playlist.sortedTracks.map { track in
            CommunityTrack(
                id: track.id.uuidString,
                appleMusicId: track.appleMusicSongId,
                isrc: nil,
                title: track.title,
                artist: track.artist,
                chorusStart: track.chorusStartSeconds,
                chorusEnd: track.chorusEndSeconds
            )
        }

        let songIds = communityTracks.map { $0.appleMusicId }

        return CommunityPlaylist(
            id: nil,  // Firestoreが自動生成
            name: playlist.name,
            authorId: authorId,
            authorName: authorName,
            authorIsPremium: authorIsPremium,
            authorCountryCode: authorCountryCode,
            authorArtworkURL: authorArtworkURL,
            tracks: communityTracks,
            songIds: songIds,
            likeCount: 0,
            downloadCount: 0,
            viewCount: 0,
            createdAt: Date()
        )
    }

    /// マイプレイリストからコミュニティプレイリストを作成（ISRCあり）
    static func fromWithISRC(
        playlist: Playlist,
        authorId: String,
        authorName: String?,
        authorIsPremium: Bool,
        authorCountryCode: String?,
        authorArtworkURL: String?
    ) async -> CommunityPlaylist {
        // 各トラックのISRCを非同期で取得
        var communityTracks: [CommunityTrack] = []

        for track in playlist.sortedTracks {
            let isrc = await fetchISRC(for: track.appleMusicSongId)

            let communityTrack = CommunityTrack(
                id: track.id.uuidString,
                appleMusicId: track.appleMusicSongId,
                isrc: isrc,
                title: track.title,
                artist: track.artist,
                chorusStart: track.chorusStartSeconds,
                chorusEnd: track.chorusEndSeconds
            )
            communityTracks.append(communityTrack)
        }

        let songIds = communityTracks.map { $0.appleMusicId }

        return CommunityPlaylist(
            id: nil,  // Firestoreが自動生成
            name: playlist.name,
            authorId: authorId,
            authorName: authorName,
            authorIsPremium: authorIsPremium,
            authorCountryCode: authorCountryCode,
            authorArtworkURL: authorArtworkURL,
            tracks: communityTracks,
            songIds: songIds,
            likeCount: 0,
            downloadCount: 0,
            viewCount: 0,
            createdAt: Date()
        )
    }

    /// Apple Music APIからISRCを取得
    private static func fetchISRC(for songId: String) async -> String? {
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(songId)
            )
            let response = try await request.response()
            return response.items.first?.isrc
        } catch {
            print("⚠️ ISRC取得失敗 (songId: \(songId)): \(error)")
            return nil
        }
    }
}

extension CommunityTrack {
    /// TrackInPlaylistに変換（インポート用）
    func toTrackInPlaylist(orderIndex: Int) -> TrackInPlaylist {
        return TrackInPlaylist(
            appleMusicSongId: appleMusicId,
            title: title,
            artist: artist,
            orderIndex: orderIndex,
            chorusStartSeconds: chorusStart,
            chorusEndSeconds: chorusEnd,
            isLocked: false
        )
    }
}
