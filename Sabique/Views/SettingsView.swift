//
//  SettingsView.swift
//  Sabique
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import FirebaseAuth
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var communityManager: CommunityManager
    @Query(sort: \Playlist.orderIndex) private var playlists: [Playlist]
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = true
    @State private var developerTapCount = 0
    @State private var isDeveloperMode = false
    @State private var showingPaywall = false
    @State private var isRestoring = false
    @State private var showingArtworkPicker = false
    @State private var showingSignInTest = false
    @State private var showingPublishTest = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showingDeleteAccountError = false
    @State private var isBackingUp = false
    @State private var backupFileURL: URL?
    @State private var showingBackupShare = false
    @State private var showingFileImporter = false
    @State private var isRestoringBackup = false
    @State private var showingRestoreResult = false
    @State private var restoreResultMessage = ""
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
                                Image(systemName: "applelogo")
                                Text(String(localized: "linked_with_apple_id"))
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .foregroundColor(.primary)

                            Button(action: { showingSignOutAlert = true }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text(String(localized: "sign_out"))
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .foregroundColor(.primary)
                            }

                            Button(action: { showingDeleteAccountAlert = true }) {
                                HStack {
                                    if isDeletingAccount {
                                        ProgressView()
                                            .frame(width: 20)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text(String(localized: "delete_account"))
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .foregroundColor(.red)
                            }
                            .disabled(isDeletingAccount)
                        } header: {
                            Text(String(localized: "account"))
                        } footer: {
                            Text(String(localized: "delete_account_warning"))
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
                            Text(String(localized: "account"))
                        } footer: {
                            Text(String(localized: "sign_in_benefits"))
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
                                        .foregroundColor(.primary)
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
                                            .foregroundColor(.primary)
                                    }
                                    Text(String(localized: "restore_purchases"))
                                        .foregroundColor(.primary)
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
                        Section(String(localized: "debug_settings")) {
                            Toggle(isOn: $storeManager.debugForceFreeMode) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "run_as_free"))
                                    Text(String(localized: "test_free_mode_description"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack {
                                Text(String(localized: "current_status"))
                                Spacer()
                                Text(storeManager.isPremium ? String(localized: "premium") : String(localized: "free"))
                                    .fontWeight(.semibold)
                                    .foregroundColor(storeManager.isPremium ? .green : .orange)
                            }
                        }
                        #endif

                        Section(String(localized: "developer_section")) {
                            Button(action: { showingSignInTest = true }) {
                                HStack {
                                    Text(String(localized: "apple_sign_in_test"))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }

                            Button(action: { showingPublishTest = true }) {
                                HStack {
                                    Text(String(localized: "playlist_publish_test"))
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
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // データバックアップセクション
                    Section {
                        Button(action: performBackup) {
                            HStack {
                                if isBackingUp {
                                    ProgressView()
                                        .frame(width: 20)
                                } else {
                                    Image(systemName: "arrow.down.doc")
                                        .foregroundColor(.primary)
                                }
                                Text(String(localized: "backup_data"))
                                    .foregroundColor(.primary)
                                Spacer()
                                if !isBackingUp {
                                    Text("\(playlists.count) \(String(localized: "backup_playlist_count"))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(isBackingUp || playlists.isEmpty)

                        Button(action: { showingFileImporter = true }) {
                            HStack {
                                if isRestoringBackup {
                                    ProgressView()
                                        .frame(width: 20)
                                } else {
                                    Image(systemName: "arrow.up.doc")
                                        .foregroundColor(.primary)
                                }
                                Text(String(localized: "restore_data"))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .disabled(isRestoringBackup)
                    } header: {
                        Text(String(localized: "backup_section"))
                    } footer: {
                        Text(String(localized: "backup_description"))
                            .font(.caption)
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
            .alert(String(localized: "sign_out_confirm"), isPresented: $showingSignOutAlert) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "sign_out"), role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text(String(localized: "sign_out_confirm_message"))
            }
            .alert(String(localized: "delete_account_confirm"), isPresented: $showingDeleteAccountAlert) {
                Button(String(localized: "cancel"), role: .cancel) { }
                Button(String(localized: "delete"), role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(String(localized: "delete_account_confirm_message"))
            }
            .alert(String(localized: "error"), isPresented: $showingDeleteAccountError) {
                Button(String(localized: "ok"), role: .cancel) { }
            } message: {
                Text(deleteAccountError ?? String(localized: "delete_account_failed"))
            }
            .sheet(isPresented: $showingBackupShare) {
                if let url = backupFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.item],
                onCompletion: { result in
                    switch result {
                    case .success(let url):
                        performRestore(url: url)
                    case .failure(let error):
                        deleteAccountError = error.localizedDescription
                        showingDeleteAccountError = true
                    }
                }
            )
            .alert(String(localized: "restore_success"), isPresented: $showingRestoreResult) {
                Button(String(localized: "ok"), role: .cancel) { }
            } message: {
                Text(restoreResultMessage)
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

    private func performBackup() {
        isBackingUp = true
        Task {
            do {
                let url = try await PlaylistExporter.exportAllToFile(playlists: playlists)
                await MainActor.run {
                    backupFileURL = url
                    isBackingUp = false
                    showingBackupShare = true
                }
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    deleteAccountError = String(localized: "backup_failed")
                    showingDeleteAccountError = true
                }
            }
        }
    }

    private func performRestore(url: URL) {
        isRestoringBackup = true
        Task {
            do {
                let result = try await PlaylistImporter.importFromBackupFile(
                    url: url,
                    modelContext: modelContext,
                    isPremium: storeManager.isPremium,
                    existingPlaylistCount: playlists.count
                )
                await MainActor.run {
                    isRestoringBackup = false
                    var message = String(
                        format: NSLocalizedString("restore_result", comment: ""),
                        result.importedPlaylistCount,
                        result.totalTrackCount
                    )
                    if result.skippedTrackCount > 0 {
                        message += "\n" + String(
                            format: NSLocalizedString("restore_skipped", comment: ""),
                            result.skippedTrackCount
                        )
                    }
                    if result.skippedPlaylistCount > 0 {
                        message += "\n" + String(
                            format: NSLocalizedString("restore_limited", comment: ""),
                            result.skippedPlaylistCount
                        )
                    }
                    restoreResultMessage = message
                    showingRestoreResult = true
                }
            } catch {
                await MainActor.run {
                    isRestoringBackup = false
                    deleteAccountError = String(localized: "restore_failed")
                    showingDeleteAccountError = true
                }
            }
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

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
        .environmentObject(AuthManager())
        .environmentObject(CommunityManager())
}

