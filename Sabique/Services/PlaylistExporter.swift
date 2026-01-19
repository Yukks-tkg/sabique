//
//  PlaylistExporter.swift
//  Sabique
//

import Foundation
import MusicKit

// MARK: - Export Data Structures

struct ExportedPlaylist: Codable {
    let name: String
    let exportedAt: Date
    let tracks: [ExportedTrack]
}

struct ExportedTrack: Codable {
    let isrc: String?
    let appleMusicId: String
    let title: String
    let artist: String
    let chorusStart: Double?
    let chorusEnd: Double?
}

// MARK: - Playlist Exporter

class PlaylistExporter {
    
    /// プレイリストをエクスポート用JSONに変換
    static func export(playlist: Playlist) async throws -> Data {
        var exportedTracks: [ExportedTrack] = []
        
        for track in playlist.sortedTracks {
            // ISRCを取得
            var isrc: String? = nil
            do {
                let request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(track.appleMusicSongId)
                )
                let response = try await request.response()
                if let song = response.items.first {
                    isrc = song.isrc
                }
            } catch {
                print("ISRC取得エラー: \(error)")
            }
            
            let exportedTrack = ExportedTrack(
                isrc: isrc,
                appleMusicId: track.appleMusicSongId,
                title: track.title,
                artist: track.artist,
                chorusStart: track.chorusStartSeconds,
                chorusEnd: track.chorusEndSeconds
            )
            exportedTracks.append(exportedTrack)
        }
        
        let exportedPlaylist = ExportedPlaylist(
            name: playlist.name,
            exportedAt: Date(),
            tracks: exportedTracks
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(exportedPlaylist)
    }
    
    /// エクスポートデータをファイルに保存
    static func exportToFile(playlist: Playlist) async throws -> URL {
        let data = try await export(playlist: playlist)
        
        // 日付フォーマット（YYYYMMDD）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        
        // ファイル名: プレイリスト名_日付.sabique
        let sanitizedName = playlist.name.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(sanitizedName)_\(dateString).sabique"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        return tempURL
    }
}
