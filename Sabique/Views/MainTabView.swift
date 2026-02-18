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
    @State private var widgetOpenPlaylistId: String? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: マイリスト
            PlaylistListView(widgetOpenPlaylistId: $widgetOpenPlaylistId)
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
                  !idParam.isEmpty
            else { return }

            widgetOpenPlaylistId = idParam
            selectedTab = 0 // マイリストタブに切り替え
        }
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
