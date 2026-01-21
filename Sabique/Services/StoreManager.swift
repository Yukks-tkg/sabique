//
//  StoreManager.swift
//  Sabique
//
//  Created by Sabiq App
//

import Foundation
import StoreKit
import Combine

/// アプリ内課金を管理するクラス
@MainActor
class StoreManager: ObservableObject {
    /// プレミアム版が購入済みかどうか
    @Published private(set) var isPremium: Bool = false
    
    /// 取得した製品情報
    @Published private(set) var products: [Product] = []
    
    /// 購入処理中かどうか
    @Published private(set) var isPurchasing: Bool = false
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    /// 製品ID
    static let premiumProductID = "com.yukitakagi.sabique.premium"
    
    /// トランザクション監視用タスク
    private var transactionListener: Task<Void, Error>?
    
    init() {
        // 起動時にトランザクションを監視開始
        transactionListener = listenForTransactions()
        
        // 既存の購入状態を確認
        Task {
            await updatePurchaseStatus()
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// 製品情報を読み込む
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: [Self.premiumProductID])
            products = storeProducts
        } catch {
            print("製品情報の読み込みに失敗: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// 購入処理を実行
    func purchase() async -> Bool {
        guard let product = products.first else {
            errorMessage = "製品が見つかりません"
            return false
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchaseStatus()
                return true
                
            case .userCancelled:
                return false
                
            case .pending:
                return false
                
            @unknown default:
                return false
            }
        } catch {
            print("購入エラー: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// 購入を復元
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchaseStatus()
        } catch {
            print("復元エラー: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private Methods
    
    /// トランザクションを監視
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchaseStatus()
                    await transaction.finish()
                } catch {
                    print("トランザクション検証エラー: \(error)")
                }
            }
        }
    }
    
    /// 購入状態を更新
    private func updatePurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == Self.premiumProductID {
                    isPremium = true
                    return
                }
            } catch {
                print("エンタイトルメント検証エラー: \(error)")
            }
        }
        isPremium = false
    }
    
    /// トランザクションを検証
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Error Types

enum StoreError: Error {
    case failedVerification
}
