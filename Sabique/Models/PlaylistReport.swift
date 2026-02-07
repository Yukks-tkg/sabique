//
//  PlaylistReport.swift
//  Sabique
//
//  プレイリスト報告モデル
//

import Foundation
import FirebaseFirestore

/// プレイリスト報告
struct PlaylistReport: Codable {
    @DocumentID var id: String?
    var playlistId: String
    var reporterUserId: String
    var reason: String
    var comment: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case playlistId
        case reporterUserId
        case reason
        case comment
        case createdAt
    }
}

/// 報告カテゴリ
enum ReportReason: String, CaseIterable {
    case nickname = "nickname"
    case playlistName = "playlist_name"
    case other = "other"

    var localizedName: String {
        switch self {
        case .nickname: return String(localized: "report_category_nickname")
        case .playlistName: return String(localized: "report_category_playlist_name")
        case .other: return String(localized: "report_category_other")
        }
    }
}
