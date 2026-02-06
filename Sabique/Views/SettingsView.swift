//
//  SettingsView.swift
//  Sabique
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communityManager: CommunityManager
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = true
    @State private var developerTapCount = 0
    @State private var isDeveloperMode = false
    @State private var showingPaywall = false
    @State private var isRestoring = false
    @State private var showingArtworkPicker = false
    @State private var showingSignInTest = false
    @State private var showingPublishTest = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showingDeleteAccountError = false
    @AppStorage("customBackgroundArtworkURLString") private var customBackgroundArtworkURLString: String = ""
    @AppStorage("customBackgroundSongTitle") private var customBackgroundSongTitle: String = ""
    @AppStorage("customBackgroundArtistName") private var customBackgroundArtistName: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background View
                if !customBackgroundArtworkURLString.isEmpty, let url = URL(string: customBackgroundArtworkURLString) {
                    GeometryReader { geometry in
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .blur(radius: 30)
                                .opacity(0.6)
                        } placeholder: {
                            Color.black
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                }
                
                // Overlay for readability (matching PlaylistListView)
                if !customBackgroundArtworkURLString.isEmpty {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                }
                
                List {
                    // アカウントセクション
                    if authManager.isSignedIn {
                        Section {
                            HStack {
                                Label("Apple IDで連携中", systemImage: "applelogo")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }

                            Button(action: { authManager.signOut() }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("サインアウト")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .foregroundColor(.orange)
                            }

                            Button(action: { showingDeleteAccountAlert = true }) {
                                HStack {
                                    if isDeletingAccount {
                                        ProgressView()
                                            .frame(width: 20)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text("アカウントを削除")
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .foregroundColor(.red)
                            }
                            .disabled(isDeletingAccount)
                        } header: {
                            Text("アカウント")
                        } footer: {
                            Text("アカウントを削除すると、投稿したハイライトリストやいいね履歴など、すべてのデータが完全に削除されます。")
                                .font(.caption)
                        }
                    } else {
                        // 未サインイン時
                        Section {
                            SignInWithAppleButton(
                                .signIn,
                                onRequest: { request in
                                    let nonce = authManager.generateNonce()
                                    request.requestedScopes = [.email]
                                    request.nonce = authManager.sha256(nonce)
                                },
                                onCompletion: { result in
                                    switch result {
                                    case .success(let authorization):
                                        Task {
                                            try? await authManager.signInWithApple(authorization: authorization)
                                        }
                                    case .failure(let error):
                                        print("Sign in with Apple failed: \(error)")
                                    }
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        } header: {
                            Text("アカウント")
                        } footer: {
                            Text("サインインすると、コミュニティにハイライトリストを投稿したり、他のユーザーのハイライトリストにいいねができます。")
                                .font(.caption)
                        }
                    }

                    // プレミアムセクション
                    if storeManager.isPremium {
                        Section {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.85, blue: 0.3),
                                                Color(red: 1.0, green: 0.55, blue: 0.3),
                                                Color(red: 0.95, green: 0.35, blue: 0.35)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text(String(localized: "premium_badge"))
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                            }
                        } header: {
                            Text(String(localized: "premium_status"))
                        }
                    } else {
                        Section {
                            Button(action: { showingPaywall = true }) {
                                HStack {
                                    Image(systemName: "star.circle.fill")
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.85, blue: 0.3),
                                                    Color(red: 1.0, green: 0.55, blue: 0.3),
                                                    Color(red: 0.95, green: 0.35, blue: 0.35)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    Text(String(localized: "upgrade_to_premium"))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Button(action: restorePurchases) {
                                HStack {
                                    if isRestoring {
                                        ProgressView()
                                            .frame(width: 20)
                                    } else {
                                        Image(systemName: "arrow.counterclockwise")
                                    }
                                    Text(String(localized: "restore_purchases"))
                                    Spacer()
                                }
                            }
                            .disabled(isRestoring)
                        } header: {
                            Text(String(localized: "premium_section"))
                        }
                    }
                    
                    if isDeveloperMode {
                        Section(String(localized: "playback_settings")) {
                            Toggle(isOn: $autoPlayOnOpen) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "auto_play"))
                                    Text(String(localized: "auto_play_description"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        #if DEBUG
                        Section("デバッグ設定") {
                            Toggle(isOn: $storeManager.debugForceFreeMode) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("無料版として動作")
                                    Text("プレミアム購入済みでも無料版の制限をテストできます")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack {
                                Text("現在の状態:")
                                Spacer()
                                Text(storeManager.isPremium ? "プレミアム" : "無料版")
                                    .fontWeight(.semibold)
                                    .foregroundColor(storeManager.isPremium ? .green : .orange)
                            }
                        }
                        #endif

                        Section("開発者向け") {
                            Button(action: { showingSignInTest = true }) {
                                HStack {
                                    Text("Apple Sign Inテスト")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }

                            Button(action: { showingPublishTest = true }) {
                                HStack {
                                    Text("プレイリスト投稿テスト")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    

                    
                    Section(String(localized: "background_settings")) {
                        if !customBackgroundArtworkURLString.isEmpty, let url = URL(string: customBackgroundArtworkURLString) {
                            HStack {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading) {
                                    Text(customBackgroundSongTitle.isEmpty ? String(localized: "custom_background_set") : customBackgroundSongTitle)
                                        .font(.headline)
                                        .lineLimit(1)
                                    if !customBackgroundArtistName.isEmpty {
                                        Text(customBackgroundArtistName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                        
                                    Text(String(localized: "reset_to_random"))
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.top, 2)
                                        .onTapGesture {
                                            customBackgroundArtworkURLString = ""
                                            customBackgroundSongTitle = ""
                                            customBackgroundArtistName = ""
                                            UserDefaults.standard.removeObject(forKey: "customBackgroundSongId")
                                        }
                                }
                                
                                Spacer()
                                
                                Button(String(localized: "change")) {
                                    showingArtworkPicker = true
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.white)
                            }
                        } else {
                            Button(action: { showingArtworkPicker = true }) {
                                HStack {
                                    Text(String(localized: "select_background_artwork"))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Section(String(localized: "about_this_app")) {
                        Text(String(localized: "app_description"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(String(localized: "legal_info")) {
                        Link(destination: URL(string: "https://immense-engineer-7f8.notion.site/Privacy-Policy-Sabique-2ed0dee3bb098077b979d500914ffbba")!) {
                            HStack {
                                Text(String(localized: "privacy_policy"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Link(destination: URL(string: "https://immense-engineer-7f8.notion.site/Terms-of-Use-Sabique-2ed0dee3bb098038983feb7ecea57f7a")!) {
                            HStack {
                                Text(String(localized: "terms_of_use"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // フッター
                    Section {
                    } footer: {
                        VStack(spacing: 4) {
                            let fullVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                            let versionParts = fullVersion.split(separator: ".")
                            let version = versionParts.prefix(2).joined(separator: ".")
                            Text("Sabique \(version)")
                                .onTapGesture {
                                    developerTapCount += 1
                                    if developerTapCount >= 7 {
                                        withAnimation {
                                            isDeveloperMode.toggle()
                                        }
                                        developerTapCount = 0
                                    }
                                }
                            Text("© 2026 Yuki Takagi")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(String(localized: "settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingArtworkPicker) {
                ArtworkPickerView()
            }
            .sheet(isPresented: $showingSignInTest) {
                SignInTestView()
            }
            .sheet(isPresented: $showingPublishTest) {
                PublishPlaylistView()
            }
            .alert("アカウントを削除しますか？", isPresented: $showingDeleteAccountAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("削除する", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("この操作は取り消せません。投稿したハイライトリスト、いいね履歴、プロフィール情報など、すべてのデータが完全に削除されます。")
            }
            .alert("エラー", isPresented: $showingDeleteAccountError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountError ?? "アカウントの削除に失敗しました")
            }
        }
    }

    private func restorePurchases() {
        isRestoring = true
        Task {
            await storeManager.restorePurchases()
            isRestoring = false
        }
    }

    private func deleteAccount() {
        guard let userId = authManager.currentUser?.uid else { return }

        isDeletingAccount = true

        Task {
            do {
                // 1. Firestoreのユーザーデータを全て削除
                try await communityManager.deleteAllUserData(userId: userId)

                // 2. Firebase Authのアカウントを削除
                try await authManager.deleteAccount()

                await MainActor.run {
                    isDeletingAccount = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteAccountError = error.localizedDescription
                    showingDeleteAccountError = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
        .environmentObject(AuthManager())
        .environmentObject(CommunityManager())
}

