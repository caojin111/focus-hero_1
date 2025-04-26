import Foundation
import Combine

class ShopManager: ObservableObject {
    static let shared = ShopManager()
    
    @Published var shopItems: [ShopItem] = []
    @Published var purchasedItems: [ShopItem] = []
    @Published var equippedEffects: [ShopItem] = []
    @Published var equippedSounds: [ShopItem] = []
    @Published var equippedBGM: ShopItem?
    @Published var equippedBackground: ShopItem?
    
    private init() {
        loadItems()
    }
    
    private func loadItems() {
        // 加载商店商品
        shopItems = ShopItem.loadItemsFromJSON()
        
        // 加载已购买商品
        if let data = UserDefaults.standard.data(forKey: "purchasedItems"),
           let items = try? JSONDecoder().decode([ShopItem].self, from: data) {
            purchasedItems = items
            
            // 更新商店商品的购买状态
            for (index, item) in shopItems.enumerated() {
                if purchasedItems.contains(where: { $0.id == item.id }) {
                    shopItems[index].isPurchased = true
                }
            }
        }
        
        // 加载已装备商品
        loadEquippedItems()
    }
    
    private func loadEquippedItems() {
        if let data = UserDefaults.standard.data(forKey: "equippedItems"),
           let items = try? JSONDecoder().decode([ShopItem].self, from: data) {
            equippedEffects = items.filter { $0.type == .effect && $0.isEquipped }
            equippedSounds = items.filter { $0.type == .sound && $0.isEquipped }
            equippedBGM = items.first { $0.type == .bgm && $0.isEquipped }
            equippedBackground = items.first { $0.type == .background && $0.isEquipped }
        }
    }
    
    private func savePurchasedItems() {
        if let encoded = try? JSONEncoder().encode(purchasedItems) {
            UserDefaults.standard.set(encoded, forKey: "purchasedItems")
        }
    }
    
    private func saveEquippedItems() {
        var allEquippedItems = equippedEffects + equippedSounds
        if let bgm = equippedBGM {
            allEquippedItems.append(bgm)
        }
        if let background = equippedBackground {
            allEquippedItems.append(background)
        }
        
        if let encoded = try? JSONEncoder().encode(allEquippedItems) {
            UserDefaults.standard.set(encoded, forKey: "equippedItems")
        }
    }
    
    // 购买结果结构体
    struct PurchaseResult {
        let success: Bool
        let errorCode: String
    }
    
    func purchaseItem(itemId: String) -> PurchaseResult {
        // 检查商品是否存在
        guard let item = shopItems.first(where: { $0.id == itemId }) else {
            return PurchaseResult(success: false, errorCode: "ITEM_NOT_FOUND")
        }
        
        // 检查是否已购买
        guard !item.isPurchased else {
            return PurchaseResult(success: false, errorCode: "ALREADY_PURCHASED")
        }
        
        // 检查金币是否足够
        let userDataManager = UserDataManager.shared
        guard userDataManager.userProfile.coins >= item.price else {
            return PurchaseResult(success: false, errorCode: "INSUFFICIENT_COINS")
        }
        
        // 扣除金币
        guard userDataManager.deductCoins(item.price) else {
            return PurchaseResult(success: false, errorCode: "DEDUCT_COINS_FAILED")
        }
        
        // 更新商店商品状态
        if let index = shopItems.firstIndex(where: { $0.id == itemId }) {
            shopItems[index].isPurchased = true
        }
        
        // 添加到已购买列表
        var purchasedItem = item
        purchasedItem.isPurchased = true
        purchasedItems.append(purchasedItem)
        
        // 保存数据
        savePurchasedItems()
        
        // 通知UI更新
        objectWillChange.send()
        
        return PurchaseResult(success: true, errorCode: "")
    }
    
    func equipItem(itemId: String) {
        guard let item = purchasedItems.first(where: { $0.id == itemId }) else {
            return
        }
        
        switch item.type {
        case .effect:
            if !equippedEffects.contains(where: { $0.id == itemId }) {
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = true
                    equippedEffects.append(purchasedItems[index])
                }
            }
        case .sound:
            if !equippedSounds.contains(where: { $0.id == itemId }) {
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = true
                    equippedSounds.append(purchasedItems[index])
                }
            }
        case .bgm:
            // 取消当前装备的BGM
            if let currentBGM = equippedBGM,
               let index = purchasedItems.firstIndex(where: { $0.id == currentBGM.id }) {
                purchasedItems[index].isEquipped = false
            }
            
            // 装备新的BGM
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = true
                equippedBGM = purchasedItems[index]
            }
        case .background:
            // 取消当前装备的背景
            if let currentBackground = equippedBackground,
               let index = purchasedItems.firstIndex(where: { $0.id == currentBackground.id }) {
                purchasedItems[index].isEquipped = false
            }
            
            // 装备新的背景
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = true
                equippedBackground = purchasedItems[index]
            }
        case .premium:
            // 处理付费道具的装备逻辑
            break
        }
        
        saveEquippedItems()
        objectWillChange.send()
    }
    
    func unequipItem(itemId: String) {
        guard let item = purchasedItems.first(where: { $0.id == itemId }) else {
            return
        }
        
        switch item.type {
        case .effect:
            equippedEffects.removeAll { $0.id == itemId }
        case .sound:
            equippedSounds.removeAll { $0.id == itemId }
        case .bgm:
            equippedBGM = nil
        case .background:
            equippedBackground = nil
        case .premium:
            break
        }
        
        if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
            purchasedItems[index].isEquipped = false
        }
        
        saveEquippedItems()
        objectWillChange.send()
    }
    
    func isItemEquipped(itemId: String) -> Bool {
        return purchasedItems.first(where: { $0.id == itemId })?.isEquipped ?? false
    }
    
    func getEquippedItems(ofType type: ShopItem.ItemType) -> [ShopItem] {
        switch type {
        case .effect:
            return equippedEffects
        case .sound:
            return equippedSounds
        case .bgm:
            return equippedBGM.map { [$0] } ?? []
        case .background:
            return equippedBackground.map { [$0] } ?? []
        case .premium:
            return []
        }
    }
} 