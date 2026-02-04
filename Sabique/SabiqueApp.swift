//
//  SabiqueApp.swift
//  Sabique
//
//  Created by 高木祐輝 on 2026/01/14.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SabiqueApp: App {
    @StateObject private var playerManager = ChorusPlayerManager()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var authManager = AuthManager()
    @StateObject private var communityManager = CommunityManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(playerManager)
                .environmentObject(storeManager)
                .environmentObject(authManager)
                .environmentObject(communityManager)
        }
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self])
    }
}
