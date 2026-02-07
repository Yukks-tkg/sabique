//
//  BlockManager.swift
//  Sabique
//
//  ブロックユーザーを管理するクラス
//

import Foundation

class BlockManager {
    static let shared = BlockManager()

    private let userDefaults = UserDefaults.standard
    private let blockedUsersKey = "blockedUserIds"

    private init() {}

    // MARK: - Public Methods

    /// ユーザーがブロック済みか確認
    func isBlocked(userId: String) -> Bool {
        let blockedUsers = getBlockedUsers()
        return blockedUsers.contains(userId)
    }

    /// ユーザーをブロック
    func blockUser(userId: String) {
        var blockedUsers = getBlockedUsers()
        if !blockedUsers.contains(userId) {
            blockedUsers.append(userId)
            saveBlockedUsers(blockedUsers)
        }
    }

    /// ユーザーのブロックを解除
    func unblockUser(userId: String) {
        var blockedUsers = getBlockedUsers()
        if let index = blockedUsers.firstIndex(of: userId) {
            blockedUsers.remove(at: index)
            saveBlockedUsers(blockedUsers)
        }
    }

    /// ブロック中のユーザーID一覧を取得
    func getBlockedUsers() -> [String] {
        return userDefaults.stringArray(forKey: blockedUsersKey) ?? []
    }

    /// ブロック中のユーザー数を取得
    func blockedCount() -> Int {
        return getBlockedUsers().count
    }

    /// 全てのブロックを解除
    func clearAllBlocks() {
        userDefaults.removeObject(forKey: blockedUsersKey)
    }

    // MARK: - Private Methods

    /// ブロック済みユーザーIDの配列を保存
    private func saveBlockedUsers(_ users: [String]) {
        userDefaults.set(users, forKey: blockedUsersKey)
    }
}
