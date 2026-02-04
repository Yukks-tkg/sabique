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

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            PlaylistListView()
                .environmentObject(playerManager)
                .environmentObject(storeManager)
                .environmentObject(authManager)
        }
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self])
    }
}
