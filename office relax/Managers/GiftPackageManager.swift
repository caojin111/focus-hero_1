import Foundation
import StoreKit

#if canImport(UIKit)
import UIKit
#endif

class GiftPackageManager: NSObject, ObservableObject {
    static let shared = GiftPackageManager()
    
    @Published var isLoading = false
    @Published var starterPackage: GiftPackage
    @Published var purchaseResult: (success: Bool, message: String)? = nil
    @Published var products: [SKProduct] = []
    @Published var isProductRequestInProgress = false
    
    // 创建一个通知名称，用于在购买成功时通知其他组件
    static let giftPackagePurchasedNotification = Notification.Name("GiftPackagePurchased")
    
    private var productRequest: SKProductsRequest?
    private var purchaseCompletion: ((Bool, String) -> Void)?
    
    private override init() {
        // 初始化礼包数据
        starterPackage = GiftPackage.createStarterPackage()
        
        // 必须先完成初始化才能调用父类的初始化方法
        super.init()
        
        // 设置 StoreKit 支付队列观察者
        SKPaymentQueue.default().add(self)
        
        // 加载商店产品信息
        loadProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    // 加载商店商品
    func loadProducts() {
        guard !isProductRequestInProgress else { return }
        
        isProductRequestInProgress = true
        isLoading = true
        
        let productIDs = Set([starterPackage.id])
        productRequest = SKProductsRequest(productIdentifiers: productIDs)
        productRequest?.delegate = self
        productRequest?.start()
        
        print("开始请求商店产品信息: \(productIDs)")
    }
    
    // 获取礼包对应的SKProduct
    func getProduct(for packageID: String) -> SKProduct? {
        return products.first(where: { $0.productIdentifier == packageID })
    }
    
    // 格式化价格
    func formattedPrice(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
    
    // 处理购买请求
    func purchaseGiftPackage(completion: @escaping (Bool, String) -> Void) {
        isLoading = true
        purchaseCompletion = completion
        
        // 确保用户可以进行支付
        guard SKPaymentQueue.canMakePayments() else {
            handlePurchaseResult(success: false, message: "您的设备不支持内购功能")
            return
        }
        
        // 获取产品信息
        guard let product = getProduct(for: starterPackage.id) else {
            // 如果产品还未加载，尝试重新加载
            if products.isEmpty {
                loadProducts()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    if let product = self?.getProduct(for: self?.starterPackage.id ?? "") {
                        self?.startPurchase(product: product)
                    } else {
                        self?.handlePurchaseResult(success: false, message: "无法获取产品信息，请稍后再试")
                    }
                }
            } else {
                handlePurchaseResult(success: false, message: "产品信息不可用，请稍后再试")
            }
            return
        }
        
        // 开始购买流程
        startPurchase(product: product)
    }
    
    // 开始实际购买
    private func startPurchase(product: SKProduct) {
        print("开始购买产品: \(product.productIdentifier)")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    // 处理购买结果
    private func handlePurchaseResult(success: Bool, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isLoading = false
            self.purchaseResult = (success, message)
            
            if success {
                // 添加礼包内容到用户库存
                self.addItemsToUserInventory()
                
                // 发送购买成功通知
                NotificationCenter.default.post(name: Self.giftPackagePurchasedNotification, object: nil)
            }
            
            // 回调结果
            self.purchaseCompletion?(success, message)
            self.purchaseCompletion = nil
        }
    }
    
    // 将礼包中的物品添加到用户已购买清单
    private func addItemsToUserInventory() {
        let shopManager = ShopManager.shared
        
        // 遍历礼包中的每个物品ID
        for itemId in starterPackage.includedItems {
            // 检查商品是否存在于商店中
            if let item = shopManager.shopItems.first(where: { $0.id == itemId }) {
                // 将物品标记为已购买
                if let index = shopManager.shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopManager.shopItems[index].isPurchased = true
                }
                
                // 检查该物品是否已经在已购买列表中
                if !shopManager.purchasedItems.contains(where: { $0.id == itemId }) {
                // 添加到已购买列表
                var purchasedItem = item
                purchasedItem.isPurchased = true
                shopManager.purchasedItems.append(purchasedItem)
                } else {
                    // 如果物品已经在已购买列表中，确保其购买状态正确
                    if let index = shopManager.purchasedItems.firstIndex(where: { $0.id == itemId }) {
                        shopManager.purchasedItems[index].isPurchased = true
                    }
                }
            }
        }
        
        // 保存数据
        shopManager.savePurchasedItems()
        shopManager.saveEquippedItems()
        
        // 打印确认信息
        print("礼包中的物品已添加到用户库存: \(starterPackage.includedItems)")
        
        // 通知UI更新
        shopManager.objectWillChange.send()
    }
    
    // 恢复购买
    func restorePurchases(completion: @escaping (Bool, String) -> Void) {
        isLoading = true
        purchaseCompletion = completion
        
        print("开始恢复购买")
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // 完成交易
    private func finishTransaction(_ transaction: SKPaymentTransaction) {
        print("完成交易: \(transaction.payment.productIdentifier)")
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    // 验证购买收据
    private func verifyPurchase(transaction: SKPaymentTransaction) -> Bool {
        // 检查收据是否有效
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            print("收据文件不存在")
            return false
        }
        
        do {
            // 读取收据数据
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            let receiptString = receiptData.base64EncodedString(options: [])
            
            // 在实际应用中，您应该将收据发送到您的服务器进行验证
            // 这里简化为只检查产品ID是否匹配
            print("收据验证 - 产品ID: \(transaction.payment.productIdentifier)")
            return transaction.payment.productIdentifier == starterPackage.id
        } catch {
            print("读取收据数据失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension GiftPackageManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.products = response.products
            self.isProductRequestInProgress = false
            self.isLoading = false
            
            print("获取到 \(self.products.count) 个产品")
            
            if !response.invalidProductIdentifiers.isEmpty {
                print("无效的产品ID: \(response.invalidProductIdentifiers)")
            }
            
            // 打印产品信息便于调试
            for product in self.products {
                let formattedPrice = self.formattedPrice(for: product)
                print("产品: \(product.productIdentifier), 标题: \(product.localizedTitle), 价格: \(formattedPrice)")
            }
            
            // 更新礼包价格显示（使用实际价格而非硬编码）
            if let product = self.products.first(where: { $0.productIdentifier == self.starterPackage.id }) {
                self.starterPackage.priceString = self.formattedPrice(for: product)
            }
            
            // 发送产品加载成功通知
            NotificationCenter.default.post(name: NSNotification.Name("ProductsLoaded"), object: nil)
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isProductRequestInProgress = false
            self.isLoading = false
            
            print("产品请求失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - SKPaymentTransactionObserver
extension GiftPackageManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                print("正在购买: \(transaction.payment.productIdentifier)")
                
            case .purchased:
                if verifyPurchase(transaction: transaction) {
                    print("购买成功: \(transaction.payment.productIdentifier)")
                    handlePurchaseResult(success: true, message: "购买成功！")
                } else {
                    print("购买验证失败: \(transaction.payment.productIdentifier)")
                    handlePurchaseResult(success: false, message: "购买验证失败")
                }
                finishTransaction(transaction)
                
            case .failed:
                let errorMessage = transaction.error?.localizedDescription ?? "未知错误"
                print("\(errorMessage)")
                handlePurchaseResult(success: false, message: "\(errorMessage)")
                finishTransaction(transaction)
                
            case .restored:
                print("恢复购买: \(transaction.payment.productIdentifier)")
                if verifyPurchase(transaction: transaction) {
                    handlePurchaseResult(success: true, message: "购买已恢复！")
                }
                finishTransaction(transaction)
                
            case .deferred:
                print("购买延期: \(transaction.payment.productIdentifier)")
                handlePurchaseResult(success: false, message: "购买已延期，请等待审核")
                
            @unknown default:
                print("未知的交易状态")
                finishTransaction(transaction)
            }
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("\(error.localizedDescription)")
        handlePurchaseResult(success: false, message: "\(error.localizedDescription)")
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("恢复购买流程已完成")
        
        // 如果没有恢复任何购买，返回相应信息
        if queue.transactions.isEmpty {
            handlePurchaseResult(success: false, message: "没有找到可恢复的购买")
        } else {
            // 恢复购买成功的处理已在updatedTransactions方法中完成
            print("已恢复 \(queue.transactions.count) 个购买")
        }
    }
} 
