//
//  SabiqueApp.swift
//  Sabique
//
//  Created by 高木祐輝 on 2026/01/14.
//

import SwiftUI
import SwiftData
import StoreKit
import FirebaseCore

@main
struct SabiqueApp: App {
    @StateObject private var playerManager = ChorusPlayerManager()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var authManager = AuthManager()
    @StateObject private var communityManager = CommunityManager()
    @Environment(\.requestReview) private var requestReview
    @AppStorage("appLaunchCount") private var appLaunchCount = 0

    let modelContainer: ModelContainer

    init() {
        FirebaseApp.configure()

        do {
            let schema = Schema(SchemaV1.models)
            let config = ModelConfiguration()
            self.modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: SabiqueMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(playerManager)
                .environmentObject(storeManager)
                .environmentObject(authManager)
                .environmentObject(communityManager)
                .onAppear {
                    appLaunchCount += 1
                    if appLaunchCount == 10 {
                        // 少し遅延させてアプリの表示が安定してから表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            requestReview()
                        }
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
