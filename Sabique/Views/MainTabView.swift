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
            // Tab 1: マイプレイリスト
            PlaylistListView()
                .tabItem {
                    Label("マイプレイリスト", systemImage: "music.note.list")
                }
                .tag(0)

            // Tab 2: みんなのプレイリスト
            CommunityView()
                .tabItem {
                    Label("みんなのプレイリスト", systemImage: "globe")
                }
                .tag(1)

            // Tab 3: プロフィール
            ProfileView()
                .tabItem {
                    Label("プロフィール", systemImage: "person.circle")
                }
                .tag(2)
        }
        .preferredColorScheme(.dark)
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
