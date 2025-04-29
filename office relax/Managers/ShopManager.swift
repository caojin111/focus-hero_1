import Foundation
import Combine
import SwiftUI

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
    
    // 添加刷新方法
    func refreshItems() {
        // 保存当前装备状态
        let currentEquippedEffects = equippedEffects
        let currentEquippedSounds = equippedSounds
        let currentEquippedBGM = equippedBGM
        let currentEquippedBackground = equippedBackground
        
        // 清空现有商品数据但保留已购买数据
        shopItems.removeAll()
        
        // 重新加载商品数据
        loadItems()
        
        // 确保装备状态与刷新前一致
        equippedEffects = currentEquippedEffects
        equippedSounds = currentEquippedSounds
        equippedBGM = currentEquippedBGM
        equippedBackground = currentEquippedBackground
        
        // 同步装备状态到purchasedItems
        for effectItem in equippedEffects {
            if let index = purchasedItems.firstIndex(where: { $0.id == effectItem.id }) {
                purchasedItems[index].isEquipped = true
            }
        }
        
        // 通知视图更新
        objectWillChange.send()
        
        print("🔄 商店数据已刷新")
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
                if let purchasedItem = purchasedItems.first(where: { $0.id == item.id }) {
                    shopItems[index].isPurchased = true
                    // 同步装备状态到商店商品
                    shopItems[index].isEquipped = purchasedItem.isEquipped
                } else {
                    shopItems[index].isPurchased = false
                }
            }
        }
        
        // 加载已装备商品
        loadEquippedItems()
    }
    
    private func loadEquippedItems() {
        if let data = UserDefaults.standard.data(forKey: "equippedItems"),
           let items = try? JSONDecoder().decode([ShopItem].self, from: data) {
            equippedEffects = items.filter { $0.type == .effect && ($0.isEquipped ?? false) }
            equippedSounds = items.filter { $0.type == .sound && ($0.isEquipped ?? false) }
            equippedBGM = items.first { $0.type == .bgm && ($0.isEquipped ?? false) }
            equippedBackground = items.first { $0.type == .background && ($0.isEquipped ?? false) }
        }
    }
    
    private func savePurchasedItems() {
        if let encoded = try? JSONEncoder().encode(purchasedItems) {
            UserDefaults.standard.set(encoded, forKey: "purchasedItems")
        }
    }
    
    func saveEquippedItems() {
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
        guard item.isPurchased != true else {
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
                    
                    // 如果是effect_1，重新加载动画配置并预加载动画
                    if itemId == "effect_1" {
                        AnimationManager.shared.reloadConfigurationAndRefresh()
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                    }
                    // 如果是effect_2，重新加载动画配置并预加载动画
                    else if itemId == "effect_2" {
                        AnimationManager.shared.reloadConfigurationAndRefresh()
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                    }
                }
                
                // 同步装备状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = true
                }
            }
        case .sound:
            if !equippedSounds.contains(where: { $0.id == itemId }) {
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = true
                    equippedSounds.append(purchasedItems[index])
                }
                
                // 同步装备状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = true
                }
            }
        case .bgm:
            // 取消当前装备的BGM
            if let currentBGM = equippedBGM,
               let index = purchasedItems.firstIndex(where: { $0.id == currentBGM.id }) {
                purchasedItems[index].isEquipped = false
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == currentBGM.id }) {
                    shopItems[shopIndex].isEquipped = false
                }
            }
            
            // 装备新的BGM
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = true
                equippedBGM = purchasedItems[index]
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = true
                }
            }
        case .background:
            // 取消当前装备的背景
            if let currentBackground = equippedBackground,
               let index = purchasedItems.firstIndex(where: { $0.id == currentBackground.id }) {
                purchasedItems[index].isEquipped = false
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == currentBackground.id }) {
                    shopItems[shopIndex].isEquipped = false
                }
            }
            
            // 装备新的背景
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = true
                equippedBackground = purchasedItems[index]
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = true
                }
            }
        case .bubble:
            // 气泡类型的装备逻辑
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = true
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = true
                }
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
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = false
                equippedEffects.removeAll(where: { $0.id == itemId })
                
                // 如果是effect_1，重新加载动画配置
                if itemId == "effect_1" {
                    AnimationManager.shared.reloadConfigurationAndRefresh()
                }
                // 如果是effect_2，重新加载动画配置
                else if itemId == "effect_2" {
                    AnimationManager.shared.reloadConfigurationAndRefresh()
                }
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = false
                }
            }
        case .sound:
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = false
                equippedSounds.removeAll(where: { $0.id == itemId })
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = false
                }
            }
        case .bgm:
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = false
                equippedBGM = nil
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = false
                }
            }
        case .background:
            if let currentBackground = equippedBackground {
                if let index = purchasedItems.firstIndex(where: { $0.id == currentBackground.id }) {
                    purchasedItems[index].isEquipped = false
                    
                    // 同步状态到shopItems
                    if let shopIndex = shopItems.firstIndex(where: { $0.id == currentBackground.id }) {
                        shopItems[shopIndex].isEquipped = false
                    }
                }
            }
            equippedBackground = nil
        case .bubble:
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = false
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = false
                }
            }
        case .premium:
            break
        }
        
        // 保存装备状态
        saveEquippedItems()
        
        // 通知观察者装备状态已更改
        objectWillChange.send()
    }
    
    func isItemEquipped(itemId: String) -> Bool {
        // 首先检查各个装备数组
        if equippedEffects.contains(where: { $0.id == itemId }) {
            return true
        }
        if equippedSounds.contains(where: { $0.id == itemId }) {
            return true
        }
        if let bgm = equippedBGM, bgm.id == itemId {
            return true
        }
        if let background = equippedBackground, background.id == itemId {
            return true
        }
        
        // 如果在装备数组中没找到，则回退到检查purchasedItems
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
        case .bubble:
            return []
        case .premium:
            return []
        }
    }
} 