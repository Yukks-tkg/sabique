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
    var authorCountryCode: String?   // 投稿時の国コード（スナップショット）
    var authorArtworkURL: String?    // 投稿時のアートワークURL（スナップショット）
    var tracks: [CommunityTrack]
    var songIds: [String]  // 検索用（曲IDのリスト）
    var likeCount: Int
    var downloadCount: Int
    var viewCount: Int
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

    init(
        id: String? = nil,
        name: String,
        authorId: String,
        authorName: String? = nil,
        authorIsPremium: Bool,
        authorCountryCode: String? = nil,
        authorArtworkURL: String? = nil,
        tracks: [CommunityTrack],
        songIds: [String],
        likeCount: Int = 0,
        downloadCount: Int = 0,
        viewCount: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.authorId = authorId
        self.authorName = authorName
        self.authorIsPremium = authorIsPremium
        self.authorCountryCode = authorCountryCode
        self.authorArtworkURL = authorArtworkURL
        self.tracks = tracks
        self.songIds = songIds
        self.likeCount = likeCount
        self.downloadCount = downloadCount
        self.viewCount = viewCount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID(wrappedValue: nil)
        name = try container.decode(String.self, forKey: .name)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        authorIsPremium = try container.decode(Bool.self, forKey: .authorIsPremium)
        authorCountryCode = try container.decodeIfPresent(String.self, forKey: .authorCountryCode)
        authorArtworkURL = try container.decodeIfPresent(String.self, forKey: .authorArtworkURL)
        tracks = try container.decode([CommunityTrack].self, forKey: .tracks)
        songIds = try container.decode([String].self, forKey: .songIds)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        downloadCount = try container.decode(Int.self, forKey: .downloadCount)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
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
