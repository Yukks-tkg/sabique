//
//  ReportPlaylistView.swift
//  Sabique
//
//  プレイリスト報告画面
//

import SwiftUI
import FirebaseAuth

struct ReportPlaylistView: View {
    let playlist: CommunityPlaylist

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var communityManager: CommunityManager
    @EnvironmentObject private var authManager: AuthManager

    @State private var selectedReason: ReportReason = .spam
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("報告理由") {
                    Picker("理由を選択", selection: $selectedReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Text(reason.rawValue).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("詳細（任意）") {
                    TextEditor(text: $comment)
                        .frame(height: 100)
                }

                Section {
                    Button(action: { submitReport() }) {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("報告する")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("不適切な内容を報告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("報告完了", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("報告を受け付けました。ご協力ありがとうございます。")
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submitReport() {
        guard let userId = authManager.currentUser?.uid else {
            errorMessage = "報告するにはサインインが必要です"
            showingError = true
            return
        }

        isSubmitting = true

        Task {
            do {
                try await communityManager.reportPlaylist(
                    playlistId: playlist.id ?? "",
                    reporterUserId: userId,
                    reason: selectedReason,
                    comment: comment.isEmpty ? nil : comment
                )

                await MainActor.run {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    let samplePlaylist = CommunityPlaylist(
        id: "sample",
        name: "髭男サビメドレー",
        authorId: "user123",
        authorName: "田中太郎",
        authorIsPremium: true,
        tracks: [],
        songIds: [],
        likeCount: 0,
        downloadCount: 0,
        createdAt: Date()
    )

    return ReportPlaylistView(playlist: samplePlaylist)
        .environmentObject(CommunityManager())
        .environmentObject(AuthManager())
}
