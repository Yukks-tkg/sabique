//
//  CommunityPlaylist.swift
//  Sabique
//
//  コミュニティプレイリストのモデル
//

import Foundation
import FirebaseFirestore

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
    /// マイプレイリストからコミュニティプレイリストを作成
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
                isrc: nil,  // TODO: ISRCを取得する処理を追加
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
