//
//  Playlist.swift
//  Sabique
//
//  Created by Sabiq App
//

import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \TrackInPlaylist.playlist)
    var tracks: [TrackInPlaylist] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
    
    /// 曲数を取得
    var trackCount: Int {
        tracks.count
    }
    
    /// orderIndex順にソートされた曲リスト
    var sortedTracks: [TrackInPlaylist] {
        tracks.sorted { $0.orderIndex < $1.orderIndex }
    }
}
