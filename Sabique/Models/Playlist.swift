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
    var orderIndex: Int = 0
    
    @Relationship(deleteRule: .cascade, inverse: \TrackInPlaylist.playlist)
    var tracks: [TrackInPlaylist] = []
    
    init(name: String, orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.orderIndex = orderIndex
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
