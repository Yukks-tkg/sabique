//
//  ProfileView.swift
//  Sabique
//
//  プロフィール画面
//

import SwiftUI
import FirebaseAuth
import MusicKit
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var storeManager: StoreManager

    @State private var userProfile: UserProfile?
    @State private var nickname: String = ""
    @State private var isEditingNickname = false
    @State private var showingArtworkPicker = false
    @State private var showingSettings = false
    @State private var showingCountryPicker = false
    @State private var isLoading = false
    @State private var totalLikes: Int = 0
    @State private var totalDownloads: Int = 0
    @State private var myPublishedPlaylists: [CommunityPlaylist] = []
    @AppStorage("customBackgroundArtworkURLString") private var customBackgroundArtworkURLString: String = ""

    private let maxNicknameLength = 10

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                backgroundView

                // オーバーレイ
                if !customBackgroundArtworkURLString.isEmpty {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                }

                if authManager.isSignedIn {
                    signedInView
                } else {
                    signedOutView
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingArtworkPicker) {
                ArtworkPickerView(
                    onArtworkSelected: { song in
                        updateProfileArtwork(song: song)
                    }
                )
            }
            .sheet(isPresented: $showingCountryPicker) {
                CountryPickerView(
                    selectedCountryCode: userProfile?.countryCode,
                    onSelect: { countryCode in
                        updateCountryCode(countryCode)
                    }
                )
            }
            .task {
                await loadUserProfile()
            }
        }
    }

    // MARK: - Subviews

    private var signedInView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // プロフィールヘッダー（アイコン + 基本情報）
                profileHeaderSection
                    .padding(.top, 8)

                // ステータスカード
                statusSection

                // デバッグ情報（一時的）
                Text("Debug: プレイリスト数 = \(myPublishedPlaylists.count)")
                    .font(.caption)
                    .foregroundColor(.yellow)

                // 投稿プレイリスト一覧
                if !myPublishedPlaylists.isEmpty {
                    myPlaylistsSection
                } else {
                    Text("投稿プレイリストがありません")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 50)
            }
            .padding(.horizontal)
        }
    }

    private var profileHeaderSection: some View {
        VStack(spacing: 24) {
            // アートワーク
            VStack(spacing: 16) {
                if let artworkURLString = userProfile?.profileArtworkURL,
                   let artworkURL = URL(string: artworkURLString) {
                    AsyncImage(url: artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 160)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                    } placeholder: {
                        defaultProfileIconLarge
                    }
                } else {
                    defaultProfileIconLarge
                }

                // 曲情報
                if let songTitle = userProfile?.profileSongTitle {
                    VStack(spacing: 4) {
                        Text(songTitle)
                            .font(.callout)
                            .fontWeight(.semibold)
                        if let artistName = userProfile?.profileArtistName {
                            Text(artistName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 変更ボタン
                Button(action: { showingArtworkPicker = true }) {
                    Text("お気に入りのアートワーク")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            // プロフィール情報カード
            VStack(spacing: 16) {
                // ニックネーム
                if isEditingNickname {
                    VStack(spacing: 8) {
                        HStack {
                            TextField("ニックネーム", text: $nickname)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .onChange(of: nickname) { oldValue, newValue in
                                    if newValue.count > maxNicknameLength {
                                        nickname = String(newValue.prefix(maxNicknameLength))
                                    }
                                }

                            Button("保存") {
                                saveNickname()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(nickname.isEmpty || nickname.count > maxNicknameLength)

                            Button("キャンセル") {
                                isEditingNickname = false
                                nickname = userProfile?.nickname ?? ""
                            }
                            .buttonStyle(.bordered)
                        }

                        // 文字数カウンター
                        HStack {
                            Spacer()
                            Text("\(nickname.count)/\(maxNicknameLength)")
                                .font(.caption2)
                                .foregroundColor(nickname.count > maxNicknameLength ? .red : .secondary)
                        }
                    }
                } else {
                    HStack {
                        Text(userProfile?.nickname ?? "ニックネーム未設定")
                            .font(.title2)
                            .fontWeight(.bold)

                        // 国旗表示
                        if let countryCode = userProfile?.countryCode, !countryCode.isEmpty {
                            Text(flagEmoji(for: countryCode))
                                .font(.title2)
                        }

                        Button(action: { isEditingNickname = true }) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }

                Divider()

                // 国/地域
                HStack {
                    Label("国/地域", systemImage: "globe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { showingCountryPicker = true }) {
                        HStack(spacing: 4) {
                            Text(countryName(for: userProfile?.countryCode))
                                .font(.subheadline)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
    }

    private var defaultProfileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            Image(systemName: "person.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
        }
    }

    private var defaultProfileIconLarge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)

            Image(systemName: "person.fill")
                .font(.system(size: 70))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private var backgroundView: some View {
        GeometryReader { geometry in
            if !customBackgroundArtworkURLString.isEmpty, let url = URL(string: customBackgroundArtworkURLString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .blur(radius: 30)
                        .opacity(0.6)
                } placeholder: {
                    Color(.systemGroupedBackground)
                }
            } else {
                Color(.systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
    }


    private var statusSection: some View {
        VStack(spacing: 16) {
            // プレミアムステータス
            if storeManager.isPremium {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text("プレミアムユーザー")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }

            // 統計カード
            VStack(spacing: 0) {
                // 上段：いいねとインポート
                HStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            Text("\(totalLikes)")
                                .font(.system(size: 32, weight: .bold))
                        }
                        Text("合計いいね")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    Divider()
                        .frame(height: 50)

                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text("\(totalDownloads)")
                                .font(.system(size: 32, weight: .bold))
                        }
                        Text("インポート数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }

                Divider()

                // 下段：今月の投稿と残り投稿数
                HStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("\(userProfile?.publishedPlaylistCount ?? 0)")
                            .font(.system(size: 32, weight: .bold))
                        Text("今月の投稿")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    Divider()
                        .frame(height: 50)

                    VStack(spacing: 8) {
                        let remaining = userProfile?.remainingPublishesThisMonth(isPremium: storeManager.isPremium) ?? 0
                        Text(storeManager.isPremium ? "∞" : "\(remaining)")
                            .font(.system(size: 32, weight: .bold))
                        Text("残り投稿数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
    }

    private var myPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投稿したプレイリスト")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(myPublishedPlaylists) { playlist in
                    NavigationLink(destination: CommunityPlaylistDetailView(playlist: playlist)) {
                        HStack(spacing: 12) {
                            // プレイリスト情報
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                HStack(spacing: 12) {
                                    Label("\(playlist.tracks.count)曲", systemImage: "music.note.list")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Label("\(playlist.likeCount)", systemImage: "heart.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)

                                    Label("\(playlist.downloadCount)", systemImage: "arrow.down.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }

    private var signedOutView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("サインインしてください")
                .font(.headline)

            Text("プロフィール機能を使用するにはApple IDでサインインしてください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Apple Sign Inボタン
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    let nonce = authManager.generateNonce()
                    request.requestedScopes = []  // 本名は要求しない
                    request.nonce = authManager.sha256(nonce)
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task {
                            do {
                                try await authManager.signInWithApple(authorization: authorization)
                            } catch {
                                print("❌ サインインエラー: \(error)")
                            }
                        }
                    case .failure(let error):
                        print("❌ Apple Sign In エラー: \(error)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }

    // MARK: - Actions

    private func loadUserProfile() async {
        guard let userId = authManager.currentUser?.uid else {
            print("❌ ユーザーIDが取得できません")
            return
        }

        print("🔄 プロフィール読み込み開始: \(userId)")
        isLoading = true

        // プロフィールを取得（必須）
        do {
            let profile = try await communityManager.getUserProfile(userId: userId)
            print("✅ プロフィール取得成功: nickname=\(profile.nickname ?? "nil")")
            await MainActor.run {
                userProfile = profile
                nickname = profile.nickname ?? ""
            }
        } catch {
            print("❌ プロフィール読み込みエラー: \(error)")
            await MainActor.run {
                isLoading = false
            }
            return
        }

        // 統計情報を並行取得（失敗しても続行）
        var likes = 0
        var downloads = 0
        var playlists: [CommunityPlaylist] = []

        do {
            likes = try await communityManager.getTotalLikesForUser(userId: userId)
            print("✅ いいね数取得成功: \(likes)")
        } catch {
            print("❌ いいね数取得エラー: \(error)")
        }

        do {
            downloads = try await communityManager.getTotalDownloadsForUser(userId: userId)
            print("✅ インポート数取得成功: \(downloads)")
        } catch {
            print("❌ インポート数取得エラー: \(error)")
        }

        do {
            playlists = try await communityManager.getUserPlaylists(userId: userId)
            print("✅ プレイリスト一覧取得成功: \(playlists.count)件")
        } catch {
            print("❌ プレイリスト一覧取得エラー: \(error)")
        }

        print("✅ 統計情報取得完了: likes=\(likes), downloads=\(downloads), playlists=\(playlists.count)")

        await MainActor.run {
            totalLikes = likes
            totalDownloads = downloads
            myPublishedPlaylists = playlists
            isLoading = false
        }
    }

    private func saveNickname() {
        guard let userId = authManager.currentUser?.uid else { return }
        guard !nickname.isEmpty else { return }
        guard nickname.count <= maxNicknameLength else { return }

        Task {
            do {
                try await communityManager.updateNickname(userId: userId, nickname: nickname)
                await loadUserProfile()
                await MainActor.run {
                    isEditingNickname = false
                }
            } catch {
                print("❌ ニックネーム保存エラー: \(error)")
            }
        }
    }

    private func updateProfileArtwork(song: Song) {
        guard let userId = authManager.currentUser?.uid else { return }
        guard let artworkURL = song.artwork?.url(width: 300, height: 300) else { return }

        Task {
            do {
                try await communityManager.updateProfileArtwork(
                    userId: userId,
                    artworkURL: artworkURL.absoluteString,
                    songTitle: song.title,
                    artistName: song.artistName
                )
                await loadUserProfile()
            } catch {
                print("❌ アートワーク更新エラー: \(error)")
            }
        }
    }

    private func updateCountryCode(_ countryCode: String) {
        guard let userId = authManager.currentUser?.uid else { return }

        // 空文字列の場合はnilとして扱う
        let finalCountryCode = countryCode.isEmpty ? "" : countryCode

        Task {
            do {
                try await communityManager.updateCountryCode(userId: userId, countryCode: finalCountryCode)
                await loadUserProfile()
            } catch {
                print("❌ 国コード更新エラー: \(error)")
            }
        }
    }

    private func countryName(for code: String?) -> String {
        guard let code = code, !code.isEmpty else { return "未設定" }
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji
    }
}

// MARK: - CountryPickerView

struct CountryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedCountryCode: String?
    let onSelect: (String) -> Void

    // 主要な国のリスト
    private let popularCountries = [
        "JP", "US", "GB", "CA", "AU", "DE", "FR", "KR", "CN", "IN",
        "BR", "MX", "ES", "IT", "RU", "NL", "SE", "NO", "FI", "DK"
    ]

    var body: some View {
        NavigationStack {
            List {
                // 未設定オプション
                Section {
                    Button(action: {
                        onSelect("")
                        dismiss()
                    }) {
                        HStack {
                            Text("未設定")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCountryCode == nil || selectedCountryCode == "" {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // 国リスト
                Section {
                    ForEach(popularCountries, id: \.self) { code in
                        Button(action: {
                            onSelect(code)
                            dismiss()
                        }) {
                            HStack {
                                Text(flagEmoji(for: code))
                                    .font(.title3)
                                Text(countryName(for: code))
                                    .foregroundColor(.primary)
                                Spacer()
                                if code == selectedCountryCode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("国/地域を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func countryName(for code: String) -> String {
        return Locale.current.localizedString(forRegionCode: code) ?? code
    }

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(CommunityManager())
        .environmentObject(StoreManager())
}
