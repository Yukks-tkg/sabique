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

/// 報告理由
enum ReportReason: String, CaseIterable {
    case spam = "スパム"
    case inappropriate = "不適切な内容"
    case misleading = "誤解を招く内容"
    case other = "その他"
}
