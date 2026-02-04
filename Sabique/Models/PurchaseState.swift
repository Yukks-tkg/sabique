//
//  PurchaseState.swift
//  Sabique
//
//  Created by Sabiq App
//

import Foundation

/// 無料版の制限を定義
enum FreeTierLimits {
    /// プレイリストの最大数
    static let maxPlaylists = 2

    /// 各プレイリストの最大トラック数
    static let maxTracksPerPlaylist = 3

    /// コミュニティ投稿に必要な最小トラック数
    static let minTracksForPublish = 3

    /// コミュニティ投稿の最大トラック数（プレミアム）
    static let maxTracksForPublishPremium = 100
}
