//
//  LikeManager.swift
//  Sabique
//
//  いいね状態を管理するクラス
//

import Foundation

class LikeManager {
    static let shared = LikeManager()

    private let userDefaults = UserDefaults.standard
    private let likedPlaylistsKey = "likedPlaylists"

    private init() {}

    // MARK: - Public Methods

    /// プレイリストにいいね済みか確認
    func hasLiked(playlistId: String) -> Bool {
        let likedPlaylists = getLikedPlaylists()
        return likedPlaylists.contains(playlistId)
    }

    /// プレイリストにいいねを追加
    func addLike(playlistId: String) {
        var likedPlaylists = getLikedPlaylists()
        if !likedPlaylists.contains(playlistId) {
            likedPlaylists.append(playlistId)
            saveLikedPlaylists(likedPlaylists)
        }
    }

    /// プレイリストのいいねを削除（今回は使用しないが将来のため）
    func removeLike(playlistId: String) {
        var likedPlaylists = getLikedPlaylists()
        if let index = likedPlaylists.firstIndex(of: playlistId) {
            likedPlaylists.remove(at: index)
            saveLikedPlaylists(likedPlaylists)
        }
    }

    // MARK: - Private Methods

    /// いいね済みプレイリストIDの配列を取得
    private func getLikedPlaylists() -> [String] {
        return userDefaults.stringArray(forKey: likedPlaylistsKey) ?? []
    }

    /// いいね済みプレイリストIDの配列を保存
    private func saveLikedPlaylists(_ playlists: [String]) {
        userDefaults.set(playlists, forKey: likedPlaylistsKey)
    }
}
