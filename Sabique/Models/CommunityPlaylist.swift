//
//  CommunityPlaylist.swift
//  Sabique
//
//  コミュニティプレイリストのモデル
//

import Foundation
import FirebaseFirestore

/// コミュニティプレイリスト（Firestore用）
struct CommunityPlaylist: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var authorId: String
    var authorName: String?
    var authorIsPremium: Bool
    var tracks: [CommunityTrack]
    var songIds: [String]  // 検索用（曲IDのリスト）
    var likeCount: Int
    var downloadCount: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case authorId
        case authorName
        case authorIsPremium
        case tracks
        case songIds
        case likeCount
        case downloadCount
        case createdAt
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
        authorIsPremium: Bool
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
            tracks: communityTracks,
            songIds: songIds,
            likeCount: 0,
            downloadCount: 0,
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
