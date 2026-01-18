//
//  SettingsView.swift
//  Sabique
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("再生設定") {
                    Toggle(isOn: $autoPlayOnOpen) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自動再生")
                            Text("ハイライト設定画面を開いたときに自動的に再生を開始")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("このアプリについて") {
                    Text("Sabiqueは、Apple Musicの曲をハイライトだけで繋いで再生できる音楽アプリです。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section("法的情報") {
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Text("プライバシーポリシー")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Text("利用規約")
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
                        Text("Sabique v1.0.0")
                        Text("© 2026 Yuki Takagi")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
