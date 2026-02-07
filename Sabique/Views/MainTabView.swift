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

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: マイリスト
            PlaylistListView()
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
