//
//  MainTabView.swift
//  Sabique
//
//  メインのタブビュー
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var playlistNavigationPath: [Playlist] = []
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var playerManager: ChorusPlayerManager
    @Query(sort: \Playlist.orderIndex) private var playlists: [Playlist]

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: マイリスト
            PlaylistListView(navigationPath: $playlistNavigationPath)
                .tabItem {
                    Label(String(localized: "my_list"), systemImage: "music.note.list")
                }
                .tag(0)

            // Tab 2: コミュニティ
            CommunityView()
                .tabItem {
                    Label(String(localized: "community"), systemImage: "globe")
                }
                .tag(1)

            // Tab 3: プロフィール
            ProfileView()
                .tabItem {
                    Label(String(localized: "profile"), systemImage: "person.circle")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark)
        .task {
            await PlaylistValidator.fetchNGWords()
        }
        .onOpenURL { url in
            // sabique://playlist?id=〇〇 の形式で受け取る
            guard url.scheme == "sabique",
                  url.host == "playlist",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idParam = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  !idParam.isEmpty,
                  let uuid = UUID(uuidString: idParam),
                  let playlist = playlists.first(where: { $0.id == uuid })
            else { return }

            selectedTab = 0
            playlistNavigationPath = [playlist]
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkWidgetPlayRequest()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                checkWidgetPlayRequest()
            }
        }
    }

    /// ウィジェットからの再生リクエストを処理
    private func checkWidgetPlayRequest() {
        let defaults = UserDefaults(suiteName: "group.com.yuki.Sabique")
        guard defaults?.bool(forKey: "widget.playRequested") == true else { return }
        defaults?.set(false, forKey: "widget.playRequested")
        defaults?.synchronize()

        print("🎵 ウィジェットからの再生リクエストを検知")

        let playlistId = defaults?.string(forKey: "nowPlaying.playlistId") ?? ""
        guard !playlistId.isEmpty,
              let playlist = playlists.first(where: { $0.id.uuidString == playlistId }),
              !playlist.tracks.isEmpty
        else {
            print("⚠️ プレイリストが見つかりません: \(playlistId)")
            return
        }

        let trackTitle = defaults?.string(forKey: "nowPlaying.trackTitle") ?? ""
        let sortedTracks = playlist.tracks.sorted { $0.orderIndex < $1.orderIndex }

        if let track = sortedTracks.first(where: { $0.title == trackTitle }) {
            print("▶️ ウィジェットから再生開始: \(track.title)")
            playerManager.playFrom(track: track, tracks: { sortedTracks })
        } else {
            print("▶️ ウィジェットから先頭再生開始")
            playerManager.play(tracks: { sortedTracks })
        }

        // PlaylistDetailViewへ直接遷移
        selectedTab = 0
        playlistNavigationPath = [playlist]
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self], inMemory: true)
        .environmentObject(ChorusPlayerManager())
        .environmentObject(StoreManager())
        .environmentObject(AuthManager())
        .environmentObject(CommunityManager())
}
