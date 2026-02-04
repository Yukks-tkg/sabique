# Sabique - プロジェクトドキュメント

## 概要
SabiqueはSwiftUIとMusicKitを使用したiOS向け音楽プレイリスト管理アプリケーションです。Apple Musicと連携し、プレイリストの作成、曲のハイライト（サビ）区間の設定、連続再生などの機能を提供します。

## 主要機能
- プレイリストの作成・管理・削除
- Apple Musicからのプレイリストインポート
- プレイリストのエクスポート・インポート（.sabiqueファイル）
- 曲のハイライト（サビ）区間の設定と連続再生
- カスタム背景アートワーク設定
- プレミアム機能（In-App Purchase対応）

## アーキテクチャ

### プロジェクト構造
```
Sabique/
├── Models/                  # データモデル
│   ├── Playlist.swift      # プレイリストモデル（SwiftData）
│   ├── TrackInPlaylist.swift # トラックモデル（SwiftData）
│   └── PurchaseState.swift  # 課金状態管理
├── Views/                   # UI層
│   ├── PlaylistListView.swift        # プレイリスト一覧画面
│   ├── PlaylistDetailView.swift      # プレイリスト詳細画面
│   ├── ChorusEditView.swift          # ハイライト編集画面
│   ├── SongSearchView.swift          # 曲検索画面
│   ├── AppleMusicPlaylistImportView.swift # Apple Music連携
│   ├── ArtworkPickerView.swift       # アートワーク選択画面
│   ├── SettingsView.swift            # 設定画面
│   └── PaywallView.swift             # 課金画面
├── Services/                # ビジネスロジック層
│   ├── ChorusPlayerManager.swift     # ハイライト再生管理
│   ├── PlaylistImporter.swift        # プレイリストインポート処理
│   ├── PlaylistExporter.swift        # プレイリストエクスポート処理
│   └── StoreManager.swift            # App Store課金管理
├── ContentView.swift        # 旧音楽プレーヤー画面（現在未使用）
└── SabiqueApp.swift        # アプリエントリーポイント
```

## データモデル

### Playlist（プレイリスト）
- `id: UUID` - 一意識別子
- `name: String` - プレイリスト名
- `createdAt: Date` - 作成日時
- `orderIndex: Int` - 表示順序
- `tracks: [TrackInPlaylist]` - 含まれる曲のリスト（カスケード削除）

### TrackInPlaylist（トラック）
- `id: UUID` - 一意識別子
- `appleMusicSongId: String` - Apple Music曲ID
- `title: String` - 曲名
- `artist: String` - アーティスト名
- `chorusStartSeconds: Double?` - ハイライト開始位置（秒）
- `chorusEndSeconds: Double?` - ハイライト終了位置（秒）
- `artworkURL: URL?` - アートワークURLキャッシュ
- `orderIndex: Int` - プレイリスト内での表示順序
- `isLocked: Bool` - ロック状態（無料版制限用）
- `playlist: Playlist?` - 所属プレイリスト

## 主要サービス

### ChorusPlayerManager
ハイライト区間の連続再生を管理します。

**主要機能:**
- プレイリストのハイライト区間を順次再生
- 曲の開始位置へのシーク
- 終了位置での自動次曲遷移（タイマーベース）
- 次へ/前へスキップ機能
- リピート再生

**実装詳細:**
- `ApplicationMusicPlayer`を使用してApple Musicを制御
- 0.1秒間隔のタイマーで再生位置を監視
- ドラッグ＆ドロップによる曲順変更にも対応（常に最新の順序を取得）

### PlaylistImporter
プレイリストのインポート処理を担当します。

**主要機能:**
- JSONファイル（.sabique）からのインポート
- ISRC（国際標準レコーディングコード）による曲の照合
- リージョン間での曲ID変換
- 無料版の曲数制限対応

**インポートフロー:**
1. ISRCで曲を検索
2. 見つからない場合はApple Music IDで検証
3. 有効なIDが見つかった曲のみインポート

### PlaylistExporter
プレイリストのエクスポート処理を担当します。

**エクスポート形式:**
```json
{
  "name": "プレイリスト名",
  "exportedAt": "2026-02-04T12:00:00Z",
  "tracks": [
    {
      "appleMusicId": "...",
      "isrc": "...",
      "title": "曲名",
      "artist": "アーティスト名",
      "chorusStart": 45.0,
      "chorusEnd": 75.0
    }
  ]
}
```

### StoreManager
App Store課金管理を担当します。

**主要機能:**
- プレミアム購入状態の管理
- 購入処理
- リストア処理

## 無料版制限（FreeTierLimits）
- 最大プレイリスト数: 3
- プレイリストあたりの最大曲数: 20

## 使用技術

### フレームワーク
- **SwiftUI** - UI構築
- **SwiftData** - データ永続化
- **MusicKit** - Apple Music連携
- **Combine** - リアクティブプログラミング
- **StoreKit 2** - App内課金

### デザインパターン
- **MVVM** - Model-View-ViewModelパターン
- **ObservableObject** - 状態管理（ChorusPlayerManager, StoreManager）
- **Environment** - 依存性注入（ModelContext, PlayerManager等）

## Apple Music連携

### 必要な権限
- MusicKit使用許可（`MusicAuthorization.request()`）

### 主要API
- `MusicCatalogSearchRequest` - 曲検索
- `MusicCatalogResourceRequest` - 曲IDからの取得
- `ApplicationMusicPlayer` - 再生制御

## データ永続化
SwiftDataを使用してプレイリストとトラックを永続化。

**ModelContainer設定:**
```swift
.modelContainer(for: [Playlist.self, TrackInPlaylist.self])
```

## UIの特徴

### カスタム背景
- プレイリストのランダムなアートワークをぼかして背景に表示
- カスタム背景URLの設定が可能（AppStorage）
- 0.5秒のフェードアニメーション

### ダークモード
- `.preferredColorScheme(.dark)` で強制ダークモード

### リスト表示
- プレイリスト一覧: ドラッグ＆ドロップで並び替え可能
- トラック一覧: スワイプで削除、並び替え対応

## 主要な画面フロー

1. **PlaylistListView** - アプリ起動時の画面
   - プレイリスト一覧表示
   - 新規作成、Apple Musicインポート、ファイルインポート

2. **PlaylistDetailView** - プレイリスト詳細
   - トラック一覧表示
   - ハイライト再生開始
   - 曲の追加・削除・並び替え

3. **ChorusEditView** - ハイライト編集
   - 曲の再生
   - 開始/終了位置の設定
   - 波形表示（未実装）

4. **SongSearchView** - 曲検索
   - Apple Music Catalogから曲を検索
   - プレイリストへの追加

## 開発時の注意点

### 再生制御
- `ApplicationMusicPlayer`は非同期処理が多いため、Task/awaitを多用
- タイマーベースの制御で曲の切り替えを実現
- `isTransitioning`フラグで連続スキップを防止

### データの整合性
- プレイリスト削除時はトラックもカスケード削除
- `orderIndex`で並び順を管理（0が最上位）

### パフォーマンス
- アートワークURLをキャッシュして再取得を防止
- `@Query`でデータベースからの自動更新

### 課金制限
- 無料版は`FreeTierLimits`で制限
- プレミアム判定は`StoreManager.isPremium`

## テスト
- **SabiqueTests/** - 単体テスト
- **SabiqueUITests/** - UIテスト

## ビルド設定
- **ターゲット:** Sabique
- **Configuration:** Debug / Release
- **Scheme:** Sabique

## 今後の拡張案
- 波形表示の実装
- プレイリストのシェア機能
- ソーシャル機能（コミュニティプレイリスト）
- オフライン再生対応
- ウィジェット対応
