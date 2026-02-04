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
    @AppStorage("customBackgroundArtworkURLString") private var customBackgroundArtworkURLString: String = ""

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
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .task {
                await loadUserProfile()
            }
        }
    }

    // MARK: - Subviews

    private var signedInView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // プロフィールアイコン
                profileIconSection

                // ニックネーム
                nicknameSection

                // 国設定
                countrySection

                // ステータス
                statusSection

                // アカウント情報
                accountSection

                Spacer(minLength: 50)
            }
            .padding()
        }
    }

    private var profileIconSection: some View {
        VStack(spacing: 12) {
            // アートワーク
            if let artworkURLString = userProfile?.profileArtworkURL,
               let artworkURL = URL(string: artworkURLString) {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .cornerRadius(16)
                } placeholder: {
                    defaultProfileIcon
                }
            } else {
                defaultProfileIcon
            }

            // 変更ボタン
            Button(action: { showingArtworkPicker = true }) {
                Text("お気に入りのアートワーク")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }

            // 曲情報
            if let songTitle = userProfile?.profileSongTitle {
                VStack(spacing: 4) {
                    Text(songTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                    if let artistName = userProfile?.profileArtistName {
                        Text(artistName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
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

    private var nicknameSection: some View {
        VStack(spacing: 12) {
            if isEditingNickname {
                HStack {
                    TextField("ニックネーム", text: $nickname)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)

                    Button("保存") {
                        saveNickname()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("キャンセル") {
                        isEditingNickname = false
                        nickname = userProfile?.nickname ?? ""
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack {
                    Text(userProfile?.nickname ?? "ニックネーム未設定")
                        .font(.title2)
                        .fontWeight(.bold)

                    Button(action: { isEditingNickname = true }) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var countrySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("国/地域")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showingCountryPicker = true }) {
                    HStack {
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
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showingCountryPicker) {
            CountryPickerView(
                selectedCountryCode: userProfile?.countryCode,
                onSelect: { countryCode in
                    updateCountryCode(countryCode)
                }
            )
        }
    }

    private var statusSection: some View {
        VStack(spacing: 16) {
            // プレミアムステータス
            if storeManager.isPremium {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("プレミアムユーザー")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }

            // 投稿数
            HStack(spacing: 30) {
                VStack {
                    Text("\(userProfile?.publishedPlaylistCount ?? 0)")
                        .font(.title2)
                        .bold()
                    Text("今月の投稿")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    let remaining = userProfile?.remainingPublishesThisMonth(isPremium: storeManager.isPremium) ?? 0
                    Text(storeManager.isPremium ? "∞" : "\(remaining)")
                        .font(.title2)
                        .bold()
                    Text("残り投稿数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }

    private var accountSection: some View {
        VStack(spacing: 12) {
            // Apple ID
            HStack {
                Image(systemName: "applelogo")
                Text("Apple IDで連携中")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            // サインアウトボタン
            Button(action: { authManager.signOut() }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("サインアウト")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(12)
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
        guard let userId = authManager.currentUser?.uid else { return }

        isLoading = true
        do {
            let profile = try await communityManager.getUserProfile(userId: userId)
            await MainActor.run {
                userProfile = profile
                nickname = profile.nickname ?? ""
                isLoading = false
            }
        } catch {
            print("❌ プロフィール読み込みエラー: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func saveNickname() {
        guard let userId = authManager.currentUser?.uid else { return }
        guard !nickname.isEmpty else { return }

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
