//
//  PlaylistImporter.swift
//  Sabique
//

import Foundation
import MusicKit
import SwiftData

// MARK: - Import Result

struct ImportResult {
    let playlist: Playlist
    let importedTrackCount: Int
    let skippedTrackCount: Int

    var hasSkippedTracks: Bool {
        skippedTrackCount > 0
    }
}

// MARK: - Bulk Import Result

struct BulkImportResult {
    let importedPlaylistCount: Int
    let totalTrackCount: Int
    let skippedTrackCount: Int
    let skippedPlaylistCount: Int
}

// MARK: - Playlist Importer

class PlaylistImporter {
    
    /// JSONファイルからプレイリストをインポート
    /// - Parameters:
    ///   - url: インポートするJSONファイルのURL
    ///   - modelContext: SwiftDataのモデルコンテキスト
    ///   - isPremium: プレミアムユーザーかどうか
    /// - Returns: インポート結果（プレイリスト、インポートされた曲数、スキップされた曲数）
    static func importFromFile(url: URL, modelContext: ModelContext, isPremium: Bool) async throws -> ImportResult {
        // ファイルにアクセス
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // JSONを読み込み
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.corruptedFile
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportedPlaylist: ExportedPlaylist
        do {
            exportedPlaylist = try decoder.decode(ExportedPlaylist.self, from: data)
        } catch {
            throw ImportError.invalidFormat
        }
        
        // プレイリストを作成
        let playlist = Playlist(name: exportedPlaylist.name, orderIndex: 0)
        modelContext.insert(playlist)
        
        // 無料版の場合はトラック数を制限
        let maxTracks = isPremium ? exportedPlaylist.tracks.count : FreeTierLimits.maxTracksPerPlaylist
        let tracksToImport = Array(exportedPlaylist.tracks.prefix(maxTracks))
        let skippedCount = max(0, exportedPlaylist.tracks.count - maxTracks)
        
        var importedCount = 0
        
        // トラックを追加
        for (index, exportedTrack) in tracksToImport.enumerated() {
            // まずISRCで検索、なければAppleMusicIdで検索
            var songId: String? = nil
            
            // ISRCで曲を検索
            if let isrc = exportedTrack.isrc {
                if let foundId = await findSongByISRC(isrc: isrc) {
                    songId = foundId
                }
            }
            
            // ISRCで見つからなければAppleMusicIdを使用
            if songId == nil {
                // AppleMusicIdが同じリージョンで有効か確認
                if await verifySongExists(appleMusicId: exportedTrack.appleMusicId) {
                    songId = exportedTrack.appleMusicId
                }
            }
            
            // 曲が見つかった場合のみトラックを追加
            if let validSongId = songId {
                let track = TrackInPlaylist(
                    appleMusicSongId: validSongId,
                    title: exportedTrack.title,
                    artist: exportedTrack.artist,
                    orderIndex: index,
                    chorusStartSeconds: exportedTrack.chorusStart,
                    chorusEndSeconds: exportedTrack.chorusEnd
                )
                track.playlist = playlist
                modelContext.insert(track)
                importedCount += 1
            }
        }
        
        return ImportResult(
            playlist: playlist,
            importedTrackCount: importedCount,
            skippedTrackCount: skippedCount
        )
    }
    
    /// ISRCで曲を検索
    private static func findSongByISRC(isrc: String) async -> String? {
        do {
            var request = MusicCatalogSearchRequest(term: isrc, types: [Song.self])
            request.limit = 5
            let response = try await request.response()
            
            // ISRCが一致する曲を探す
            for song in response.songs {
                if song.isrc == isrc {
                    return song.id.rawValue
                }
            }
        } catch {
            print("ISRC search error: \(error)")
        }
        return nil
    }
    
    /// AppleMusicIdで曲が存在するか確認
    private static func verifySongExists(appleMusicId: String) async -> Bool {
        do {
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(appleMusicId)
            )
            let response = try await request.response()
            return response.items.first != nil
        } catch {
            print("Song verification error: \(error)")
            return false
        }
    }

    // MARK: - Bulk Restore from Backup

    /// バックアップファイルから複数プレイリストを一括復元
    /// - Parameters:
    ///   - url: バックアップファイルのURL
    ///   - modelContext: SwiftDataのモデルコンテキスト
    ///   - isPremium: プレミアムユーザーかどうか
    ///   - existingPlaylistCount: 現在のプレイリスト数（無料版制限チェック用）
    /// - Returns: 一括インポート結果
    static func importFromBackupFile(
        url: URL,
        modelContext: ModelContext,
        isPremium: Bool,
        existingPlaylistCount: Int
    ) async throws -> BulkImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.corruptedFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // バックアップは [ExportedPlaylist] 配列、単体は ExportedPlaylist
        var exportedPlaylists: [ExportedPlaylist]
        do {
            exportedPlaylists = try decoder.decode([ExportedPlaylist].self, from: data)
        } catch {
            // 配列でなければ単体として試行
            do {
                let single = try decoder.decode(ExportedPlaylist.self, from: data)
                exportedPlaylists = [single]
            } catch {
                throw ImportError.invalidFormat
            }
        }

        // 無料版の場合はプレイリスト数を制限
        let availableSlots = isPremium
            ? exportedPlaylists.count
            : max(0, FreeTierLimits.maxPlaylists - existingPlaylistCount)
        let playlistsToImport = Array(exportedPlaylists.prefix(availableSlots))
        let skippedPlaylistCount = exportedPlaylists.count - playlistsToImport.count

        var totalImportedTracks = 0
        var totalSkippedTracks = 0
        var importedPlaylistCount = 0

        for (playlistIndex, exportedPlaylist) in playlistsToImport.enumerated() {
            let playlist = Playlist(
                name: exportedPlaylist.name,
                orderIndex: existingPlaylistCount + playlistIndex
            )
            modelContext.insert(playlist)

            // 無料版の場合はトラック数を制限
            let maxTracks = isPremium
                ? exportedPlaylist.tracks.count
                : FreeTierLimits.maxTracksPerPlaylist
            let tracksToImport = Array(exportedPlaylist.tracks.prefix(maxTracks))
            totalSkippedTracks += max(0, exportedPlaylist.tracks.count - maxTracks)

            var trackImported = false

            for (trackIndex, exportedTrack) in tracksToImport.enumerated() {
                var songId: String? = nil

                // ISRCで曲を検索
                if let isrc = exportedTrack.isrc {
                    if let foundId = await findSongByISRC(isrc: isrc) {
                        songId = foundId
                    }
                }

                // ISRCで見つからなければAppleMusicIdを使用
                if songId == nil {
                    if await verifySongExists(appleMusicId: exportedTrack.appleMusicId) {
                        songId = exportedTrack.appleMusicId
                    }
                }

                if let validSongId = songId {
                    let track = TrackInPlaylist(
                        appleMusicSongId: validSongId,
                        title: exportedTrack.title,
                        artist: exportedTrack.artist,
                        orderIndex: trackIndex,
                        chorusStartSeconds: exportedTrack.chorusStart,
                        chorusEndSeconds: exportedTrack.chorusEnd
                    )
                    track.playlist = playlist
                    modelContext.insert(track)
                    totalImportedTracks += 1
                    trackImported = true
                } else {
                    totalSkippedTracks += 1
                }
            }

            if trackImported {
                importedPlaylistCount += 1
            } else {
                // トラックが1つもインポートできなかった場合は空のプレイリストも削除
                modelContext.delete(playlist)
            }
        }

        return BulkImportResult(
            importedPlaylistCount: importedPlaylistCount,
            totalTrackCount: totalImportedTracks,
            skippedTrackCount: totalSkippedTracks,
            skippedPlaylistCount: skippedPlaylistCount
        )
    }
}

// MARK: - Import Error

enum ImportError: LocalizedError {
    case accessDenied
    case invalidFormat
    case noTracksFound
    case corruptedFile
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "ファイルにアクセスできません"
        case .invalidFormat:
            return "ファイル形式が正しくありません。Sabiqueでエクスポートされたファイルか確認してください。"
        case .noTracksFound:
            return "曲が見つかりませんでした"
        case .corruptedFile:
            return "ファイルが破損しているか、読み込めません。別のファイルをお試しください。"
        }
    }
}
