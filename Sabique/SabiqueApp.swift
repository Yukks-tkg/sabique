//
//  SabiqueApp.swift
//  Sabique
//
//  Created by 高木祐輝 on 2026/01/14.
//

import SwiftUI
import SwiftData

@main
struct SabiqueApp: App {
    @StateObject private var playerManager = ChorusPlayerManager()
    
    var body: some Scene {
        WindowGroup {
            PlaylistListView()
                .environmentObject(playerManager)
        }
        .modelContainer(for: [Playlist.self, TrackInPlaylist.self])
    }
}
