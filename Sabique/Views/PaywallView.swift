//
//  PaywallView.swift
//  Sabique
//
//  Created by Sabiq App
//

import SwiftUI
import StoreKit

/// ペイウォール画面
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // グラデーション背景（アプリアイコンに合わせたダークネイビー）
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.13),
                        Color(red: 0.04, green: 0.06, blue: 0.10),
                        Color(red: 0.03, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        VStack(spacing: 16) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 80))
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
                            
                            Text(String(localized: "paywall_title"))
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(String(localized: "paywall_description"))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // 機能リスト
                        VStack(spacing: 16) {
                            FeatureRow(
                                icon: "music.note.list",
                                title: String(localized: "paywall_feature_unlimited_playlists"),
                                description: String(localized: "paywall_feature_unlimited_playlists_desc")
                            )
                            
                            FeatureRow(
                                icon: "music.note",
                                title: String(localized: "paywall_feature_unlimited_tracks"),
                                description: String(localized: "paywall_feature_unlimited_tracks_desc")
                            )
                            
                            FeatureRow(
                                icon: "square.and.arrow.up",
                                title: String(localized: "paywall_feature_more_publishes"),
                                description: String(localized: "paywall_feature_more_publishes_desc")
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 12)
                        
                        // 購入ボタン
                        VStack(spacing: 12) {
                            if let product = storeManager.products.first {
                                Button(action: {
                                    Task {
                                        let success = await storeManager.purchase()
                                        if success {
                                            dismiss()
                                        }
                                    }
                                }) {
                                    HStack {
                                        if storeManager.isPurchasing {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Text(String(localized: "purchase_button"))
                                            Text("(\(product.displayPrice))")
                                        }
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.7, blue: 0.2),
                                                Color(red: 1.0, green: 0.45, blue: 0.35),
                                                Color(red: 0.9, green: 0.3, blue: 0.35)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                }
                                .disabled(storeManager.isPurchasing)
                            } else {
                                ProgressView()
                                    .padding()
                            }
                            
                            // リストアボタン
                            Button(action: {
                                Task {
                                    await storeManager.restorePurchases()
                                    if storeManager.isPremium {
                                        dismiss()
                                    }
                                }
                            }) {
                                Text(String(localized: "restore_purchases"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 利用規約・プライバシーポリシー
                            HStack(spacing: 16) {
                                Link(String(localized: "terms_of_use"), destination: URL(string: "https://immense-engineer-7f8.notion.site/Terms-of-Use-Sabique-2ed0dee3bb098038983feb7ecea57f7a")!)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Link(String(localized: "privacy_policy"), destination: URL(string: "https://immense-engineer-7f8.notion.site/Privacy-Policy-Sabique-2ed0dee3bb098077b979d500914ffbba")!)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Apple Music注記
                            Text(String(localized: "paywall_apple_music_note"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert(String(localized: "error"), isPresented: .constant(storeManager.errorMessage != nil)) {
                Button(String(localized: "ok")) {
                    storeManager.errorMessage = nil
                }
            } message: {
                Text(storeManager.errorMessage ?? "")
            }
        }
    }
}

// MARK: - FeatureRow

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    // アプリアイコンに合わせたオレンジ系のアクセントカラー
    private let accentColor = Color(red: 1.0, green: 0.55, blue: 0.3)
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(accentColor)
                .frame(width: 44, height: 44)
                .background(accentColor.opacity(0.15))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}
