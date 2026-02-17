# Sabique - プロジェクトドキュメント

## 概要
SabiqueはSwiftUIとMusicKitを使用したiOS向け音楽プレイリスト管理アプリケーションです。Apple Musicと連携し、プレイリストの作成、曲のハイライト（サビ）区間の設定、連続再生などの機能を提供します。

## 主要機能
- プレイリストの作成・管理・削除・リネーム
- Apple Musicからのプレイリストインポート
- 曲のハイライト（サビ）区間の設定と連続再生
- レコードプレイヤー風の再生UI（アートワーク回転、長い曲名の自動レイアウト調整）
- カスタム背景アートワーク設定
- プレミアム機能（In-App Purchase対応）
- コミュニティ機能（プレイリスト公開・共有）
- Sign in with Apple認証
- トラック情報のローカライズ（デバイス言語に応じたタイトル・アーティスト名表示）
- レビューリクエスト（10回起動時に表示）

## アーキテクチャ

### プロジェクト構造
```
Sabique/
├── Models/                  # データモデル
│   ├── Playlist.swift           # プレイリストモデル（SwiftData）
│   ├── TrackInPlaylist.swift    # トラックモデル（SwiftData）
│   ├── PurchaseState.swift      # 課金状態管理・FreeTierLimits定義
│   ├── CommunityPlaylist.swift  # コミュニティプレイリストモデル
│   ├── UserProfile.swift        # ユーザープロファイルモデル
│   └── PlaylistReport.swift     # 通報モデル
├── Views/                   # UI層
│   ├── MainTabView.swift                # メインタブナビゲーション
│   ├── PlaylistListView.swift           # プレイリスト一覧画面
│   ├── PlaylistDetailView.swift         # プレイリスト詳細画面
│   ├── ChorusEditView.swift             # ハイライト編集画面
│   ├── SongSearchView.swift             # 曲検索画面
│   ├── AppleMusicPlaylistImportView.swift # Apple Music連携
│   ├── ArtworkPickerView.swift          # アートワーク選択画面
│   ├── SettingsView.swift               # 設定画面
│   ├── PaywallView.swift                # 課金画面
│   ├── ProfileView.swift                # プロフィール画面
│   ├── CommunityView.swift              # コミュニティ一覧画面
│   ├── CommunityPlaylistDetailView.swift # コミュニティプレイリスト詳細
│   ├── PublishPlaylistView.swift        # プレイリスト公開画面
│   ├── ReportPlaylistView.swift         # 通報画面
│   └── SignInTestView.swift             # サインインテスト画面
├── Services/                # ビジネスロジック層
│   ├── ChorusPlayerManager.swift     # ハイライト再生管理
│   ├── PlaylistImporter.swift        # プレイリストインポート処理
│   ├── PlaylistExporter.swift        # プレイリストエクスポート処理
│   ├── StoreManager.swift            # App Store課金管理
│   ├── AuthManager.swift             # 認証管理（Sign in with Apple）
│   ├── CommunityManager.swift        # コミュニティ機能管理
│   ├── LikeManager.swift             # いいね機能管理
│   └── PlaylistValidator.swift       # プレイリスト検証
├── ContentView.swift        # 旧音楽プレーヤー画面（現在未使用）
└── SabiqueApp.swift        # アプリエントリーポイント
```

## データモデル

### Playlist（プレイリスト）
- `id: UUID` - 一意識別子
- `name: String` - プレイリスト名（最大50文字）
- `createdAt: Date` - 作成日時
- `orderIndex: Int` - 表示順序
- `tracks: [TrackInPlaylist]` - 含まれる曲のリスト（カスケード削除）

### TrackInPlaylist（トラック）
- `id: UUID` - 一意識別子
- `appleMusicSongId: String` - Apple Music曲ID
- `title: String` - 曲名（デバイス言語でローカライズ済み）
- `artist: String` - アーティスト名（デバイス言語でローカライズ済み）
- `chorusStartSeconds: Double?` - ハイライト開始位置（秒）
- `chorusEndSeconds: Double?` - ハイライト終了位置（秒）
- `artworkURL: URL?` - アートワークURLキャッシュ
- `orderIndex: Int` - プレイリスト内での表示順序
- `isLocked: Bool` - ロック状態（無料版制限用）
- `playlist: Playlist?` - 所属プレイリスト

**ローカライズ対応メソッド:**
- `refreshLocalizedInfo()` - MusicKitから現在のデバイス言語のタイトル・アーティスト名を再取得して更新（@MainActor）
- `fetchLocalizedInfo(songId:)` - Apple Music IDからローカライズされた情報を取得（static）

### CommunityPlaylist（コミュニティプレイリスト）
- Firestore上で管理される公開プレイリスト
- ユーザーが自分のプレイリストをコミュニティに公開可能
- いいね数、ダウンロード数でランキング
- 投稿時のスナップショット情報を保持:
  - `authorName` - 投稿時のニックネーム
  - `authorIsPremium` - 投稿時のプレミアム状態
  - `authorCountryCode` - 投稿時の国コード（国旗表示用）
  - `authorArtworkURL` - 投稿時のプロフィール画像

### UserProfile（ユーザープロファイル）
- Sign in with Appleによる認証情報
- 表示名（ニックネーム、最大10文字）
- 国コード（ISO 3166-1 alpha-2形式）
- プロフィール画像URL

### PlaylistReport（通報）
- 不適切なプレイリストの通報機能

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
- 無料版の曲数制限対応（最大3曲）

**インポートフロー:**
1. ISRCで曲を検索
2. 見つからない場合はApple Music IDで検証
3. 有効なIDが見つかった曲のみインポート
4. MusicKitからデバイス言語に合ったタイトル・アーティスト名を取得して保存

### StoreManager
App Store課金管理を担当します。

**主要機能:**
- プレミアム購入状態の管理
- 購入処理
- リストア処理

### AuthManager
Sign in with Appleによる認証を管理します。

**主要機能:**
- Apple ID認証
- ユーザーセッション管理
- サインアウト処理
- アカウント削除（Apple要件準拠）

### CommunityManager
コミュニティ機能を管理します（Firestore連携）。

**主要機能:**
- プレイリストの公開・削除
- コミュニティプレイリストの取得（人気・新着を同時取得）
- ランキング（いいね数、ダウンロード数）
- プレイリストのインポート（無料版は3曲制限、インポート時にデバイス言語でローカライズ）
- ユーザーデータの全削除（アカウント削除時）

**データ管理:**
- `popularPlaylists` - 人気順プレイリスト
- `newestPlaylists` - 新着順プレイリスト
- `fetchAllPlaylists()` - 両方を同時に取得

### LikeManager
いいね機能を管理します。

**主要機能:**
- プレイリストへのいいね/いいね解除
- いいね状態の取得（UserDefaultsで管理）

### PlaylistValidator
プレイリストの検証を担当します。

**主要機能:**
- 公開前のプレイリスト検証
- コンテンツポリシーチェック
- 文字数制限（プレイリスト名: 最大50文字）

## 無料版制限（FreeTierLimits）
- 最大プレイリスト数: 2
- プレイリストあたりの最大曲数: 3
- コミュニティからのインポート: 最大3曲

## 使用技術

### フレームワーク
- **SwiftUI** - UI構築
- **SwiftData** - ローカルデータ永続化
- **MusicKit** - Apple Music連携
- **Combine** - リアクティブプログラミング
- **StoreKit 2** - App内課金
- **Firebase/Firestore** - コミュニティデータ管理
- **FirebaseAuth** - 認証管理
- **AuthenticationServices** - Sign in with Apple

### デザインパターン
- **MVVM** - Model-View-ViewModelパターン
- **ObservableObject** - 状態管理（ChorusPlayerManager, StoreManager, CommunityManager, AuthManager）
- **Environment** - 依存性注入（ModelContext, PlayerManager等）

## Apple Music連携

### 必要な権限
- MusicKit使用許可（`MusicAuthorization.request()`）

### 主要API
- `MusicCatalogSearchRequest` - 曲検索
- `MusicCatalogResourceRequest` - 曲IDからの取得（ローカライズ名取得にも使用）
- `ApplicationMusicPlayer` - 再生制御

### ローカライズ対応
曲追加・インポート時にMusicKitのカタログAPIからデバイス言語に合ったタイトル・アーティスト名を取得して保存する。これにより、他言語で投稿されたコミュニティプレイリストをインポートしても、ユーザーの言語で表示される。
- `TrackInPlaylist.fetchLocalizedInfo(songId:)` を全インポート経路で使用
- 対応箇所: SongSearchView（曲追加）、CommunityManager（コミュニティインポート）、PlaylistImporter（ファイルインポート・バックアップ復元）

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

### 再生プレイヤー（PlaylistDetailView下部）
- レコードプレイヤー風デザイン（`RotatingArtwork`でアートワークが回転）
- 長押しで一時停止、離すと再開
- 長い曲名は`ViewThatFits`で自動レイアウト調整（通常: 15pt/1行、フォールバック: 12pt/2行、アーティスト名も同比率で縮小）
- 左利きモード対応（`isLeftHandedMode`でレイアウト反転）

### MarqueeText（横スクロールテキスト）
- トラック一覧で再生中の曲名が長い場合に横スクロール
- 曲切り替え時は`resetId`（UUID）を変更してViewを再生成し、進行中アニメーションを確実に破棄

### ダークモード
- `.preferredColorScheme(.dark)` で強制ダークモード

### リスト表示
- プレイリスト一覧: ドラッグ＆ドロップで並び替え可能
- トラック一覧: スワイプで削除、並び替え対応

### コミュニティ画面
- 人気・新着タブを横スワイプで切り替え可能（TabView pageスタイル）
- 両方のリストを事前読み込みしてスムーズな切り替え
- プレイリスト検索機能

## 主要な画面フロー

### メインタブ（MainTabView）
アプリはタブベースのナビゲーションを採用。

1. **PlaylistListView** - マイプレイリストタブ
   - プレイリスト一覧表示
   - 新規作成、Apple Musicインポート

2. **CommunityView** - コミュニティタブ
   - 公開プレイリスト一覧（人気・新着）
   - ランキング表示（いいね数、ダウンロード数）
   - プレイリスト検索

3. **ProfileView** - プロフィールタブ
   - ユーザー情報表示・編集
   - メンバーシップ状態（Sabique Premiumメンバー / Sabiqueメンバー）
   - 自分が公開したプレイリスト一覧
   - 設定へのアクセス

### 詳細画面

4. **PlaylistDetailView** - プレイリスト詳細
   - トラック一覧表示
   - ハイライト再生開始
   - 曲の追加・削除・並び替え
   - プレイリスト名の編集（ペンシルアイコン）
   - プレイリスト公開機能

5. **CommunityPlaylistDetailView** - コミュニティプレイリスト詳細
   - 公開プレイリストの詳細表示
   - 曲のタップで試聴再生
   - いいね機能
   - インポート機能（無料版は3曲制限）
   - 自分の投稿: 削除ボタン表示
   - 他人の投稿: 通報ボタン表示

6. **ChorusEditView** - ハイライト編集
   - 曲の再生
   - 開始/終了位置の設定

7. **SongSearchView** - 曲検索
   - Apple Music Catalogから曲を検索
   - プレイリストへの追加

8. **PublishPlaylistView** - プレイリスト公開
   - プレイリスト選択（アートワーク表示）
   - 公開設定

9. **SettingsView** - 設定画面
   - Sign in with Appleボタン（未サインイン時）
   - アカウント削除機能

## 開発時の注意点

### 再生制御
- `ApplicationMusicPlayer`は非同期処理が多いため、Task/awaitを多用
- タイマーベースの制御で曲の切り替えを実現
- `isTransitioning`フラグで連続スキップを防止

### データの整合性
- プレイリスト削除時はトラックもカスケード削除
- `orderIndex`で並び順を管理（0が最上位）
- コミュニティプレイリスト削除時はFirestoreから完全削除

### パフォーマンス
- アートワークURLをキャッシュして再取得を防止
- `@Query`でデータベースからの自動更新
- コミュニティ画面で人気・新着を同時取得してスワイプをスムーズに

### 課金制限
- 無料版は`FreeTierLimits`で制限
- プレミアム判定は`StoreManager.isPremium`
- コミュニティからのインポートも曲数制限適用

### レビューリクエスト
- `AppStorage("appLaunchCount")`で起動回数を管理
- 10回目の起動時に`requestReview()`を呼び出し（2秒遅延）
- AppleのAPIが表示頻度を自動制御するため過剰表示なし

### Firebaseセキュリティルール
```javascript
// communityPlaylists コレクション
match /communityPlaylists/{playlistId} {
  allow read: if true;
  allow create: if request.auth != null;
  allow update, delete: if request.auth != null
                        && request.auth.uid == resource.data.authorId;
}
```

## テスト
- **SabiqueTests/** - 単体テスト
- **SabiqueUITests/** - UIテスト

## ビルド設定
- **ターゲット:** Sabique
- **Configuration:** Debug / Release
- **Scheme:** Sabique

### SwiftUIアニメーションの注意点
- `withAnimation(.linear(duration:))`で開始されたアニメーションはTaskキャンセルだけでは停止しない
- 確実に停止するには`.id()`modifierのIDを変更してView再生成する手法が有効（MarqueeTextで採用）

## 今後の拡張案
- 波形表示の実装
- オフライン再生対応
- ウィジェット対応
- コミュニティ機能の拡張（フォロー、コメント等）
