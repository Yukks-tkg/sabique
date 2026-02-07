//
//  SchemaVersioning.swift
//  Sabique
//
//  スキーマバージョニングとマイグレーション設定
//

import Foundation
import SwiftData

// MARK: - スキーマバージョン定義

/// v1: 初期リリース時のスキーマ（現在のモデル構造）
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Playlist.self, TrackInPlaylist.self]
    }
}

// MARK: - マイグレーションプラン

/// マイグレーションプラン
/// 新しいスキーマバージョンを追加する場合:
/// 1. SchemaV2 を定義（VersionedSchema準拠）
/// 2. MigrateV1toV2 を定義（MigrationStage）
/// 3. stages に追加
///
/// 例:
/// ```
/// enum SchemaV2: VersionedSchema {
///     static var versionIdentifier = Schema.Version(2, 0, 0)
///     static var models: [any PersistentModel.Type] {
///         [PlaylistV2.self, TrackInPlaylistV2.self]
///     }
/// }
///
/// static var stages: [MigrationStage] {
///     [migrateV1toV2]
/// }
///
/// static let migrateV1toV2 = MigrationStage.lightweight(
///     fromVersion: SchemaV1.self,
///     toVersion: SchemaV2.self
/// )
/// ```
enum SabiqueMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // 現在はv1のみのため空。v2追加時にここにマイグレーションを定義
        []
    }
}
