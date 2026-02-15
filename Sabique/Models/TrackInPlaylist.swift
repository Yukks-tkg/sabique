//
//  TrackInPlaylist.swift
//  Sabique
//
//  Created by Sabiq App
//

import Foundation
import SwiftData
import MusicKit

@Model
final class TrackInPlaylist {
    @Attribute(.unique) var id: UUID
    var appleMusicSongId: String
    var title: String
    var artist: String
    var chorusStartSeconds: Double?
    var chorusEndSeconds: Double?
    var artworkURL: URL?
    var orderIndex: Int
    var isLocked: Bool = false
    
    var playlist: Playlist?
    
    init(
        appleMusicSongId: String,
        title: String,
        artist: String,
        orderIndex: Int,
        chorusStartSeconds: Double? = nil,
        chorusEndSeconds: Double? = nil,
        isLocked: Bool = false
    ) {
        self.id = UUID()
        self.appleMusicSongId = appleMusicSongId
        self.title = title
        self.artist = artist
        self.orderIndex = orderIndex
        self.chorusStartSeconds = chorusStartSeconds
        self.chorusEndSeconds = chorusEndSeconds
        self.isLocked = isLocked
    }
    
    /// ハイライト区間が設定済みかどうか
    var hasChorusSettings: Bool {
        guard let start = chorusStartSeconds, let end = chorusEndSeconds else {
            return false
        }
        return start >= 0 && end > start
    }
    
    /// ハイライトの長さ（秒）
    var chorusDuration: Double? {
        guard let start = chorusStartSeconds, let end = chorusEndSeconds else {
            return nil
        }
        return end - start
    }
    
    /// 開始時間をmm:ss形式で取得
    var chorusStartFormatted: String {
        guard let seconds = chorusStartSeconds else { return "--:--" }
        return formatTime(seconds)
    }
    
    /// 終了時間をmm:ss形式で取得
    var chorusEndFormatted: String {
        guard let seconds = chorusEndSeconds else { return "--:--" }
        return formatTime(seconds)
    }
    
    private func formatTime(_ totalSeconds: Double) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - ローカライズ名取得

    /// Apple Music APIから現在のデバイス言語に合ったタイトル・アーティスト名を取得
    /// 取得できた場合はSwiftDataのプロパティも更新する
    @MainActor
    func refreshLocalizedInfo() async {
        guard let (localizedTitle, localizedArtist) = await Self.fetchLocalizedInfo(songId: appleMusicSongId) else {
            return
        }
        self.title = localizedTitle
        self.artist = localizedArtist
    }

    /// Apple Music IDからローカライズされたタイトル・アーティスト名を取得
    static func fetchLocalizedInfo(songId: String) async -> (title: String, artist: String)? {
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(songId)
            )
            let response = try await request.response()
            if let song = response.items.first {
                return (song.title, song.artistName)
            }
        } catch {
            print("⚠️ ローカライズ名取得失敗 (songId: \(songId)): \(error)")
        }
        return nil
    }
}
