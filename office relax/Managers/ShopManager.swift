import Foundation
import Combine
import SwiftUI

class ShopManager: ObservableObject {
    static let shared = ShopManager()
    
    @Published var shopItems: [ShopItem] = []
    @Published var purchasedItems: [ShopItem] = []
    @Published var equippedEffects: [ShopItem] = []
    @Published var equippedSounds: [ShopItem] = []
    @Published var equippedBGMs: [ShopItem] = []
    @Published var equippedBackgrounds: [ShopItem] = []
    
    private init() {
        // 首先尝试从Keychain加载装备状态
        loadEquippedItemsFromKeychain()
        
        // 然后再从UserDefaults加载（如果Keychain加载失败）
        loadItems()
        
        // 通知其他组件ShopManager已准备完成
        NotificationCenter.default.post(
            name: NSNotification.Name("ShopManagerReady"),
            object: nil
        )
    }
    
    // 添加刷新方法
    func refreshItems() {
        // 保存当前装备状态
        let currentEquippedEffects = equippedEffects
        let currentEquippedSounds = equippedSounds
        let currentEquippedBGMs = equippedBGMs
        let currentEquippedBackgrounds = equippedBackgrounds
        
        // 保存已购买的商品
        let currentPurchasedItems = purchasedItems
        
        // 清空现有商品数据但保留已购买数据
        shopItems.removeAll()
        
        // 重新加载商品数据
        loadItems()
        
        // 确保购买状态与刷新前一致
        for purchasedItem in currentPurchasedItems {
            if let index = shopItems.firstIndex(where: { $0.id == purchasedItem.id }) {
                shopItems[index].isPurchased = true
            }
            
            // 确保purchasedItems中包含所有已购买的商品
            if !purchasedItems.contains(where: { $0.id == purchasedItem.id }) {
                purchasedItems.append(purchasedItem)
            }
        }
        
        // 确保装备状态与刷新前一致
        equippedEffects = currentEquippedEffects
        equippedSounds = currentEquippedSounds
        equippedBGMs = currentEquippedBGMs
        equippedBackgrounds = currentEquippedBackgrounds
        
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
            equippedBGMs = items.filter { $0.type == .bgm && ($0.isEquipped ?? false) }
            equippedBackgrounds = items.filter { $0.type == .background && ($0.isEquipped ?? false) }
        }
    }
    
    func savePurchasedItems() {
        if let encoded = try? JSONEncoder().encode(purchasedItems) {
            UserDefaults.standard.set(encoded, forKey: "purchasedItems")
        }
    }
    
    func saveEquippedItems() {
        var allEquippedItems = equippedEffects + equippedSounds + equippedBGMs + equippedBackgrounds
        
        // 同时保存到UserDefaults（作为备份）
        if let encoded = try? JSONEncoder().encode(allEquippedItems) {
            UserDefaults.standard.set(encoded, forKey: "equippedItems")
        }
        
        // 保存到Keychain（更安全的持久化存储）
        saveEquippedItemsToKeychain(allEquippedItems)
        
        print("已保存装备状态到Keychain和UserDefaults")
    }
    
    // 保存装备物品到Keychain
    private func saveEquippedItemsToKeychain(_ items: [ShopItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            
            // 使用KeychainHelper保存数据
            KeychainHelper.standard.save(data, service: "com.lazygeng.officerelax", account: "equippedItems")
            
            print("成功保存\(items.count)个装备物品到Keychain")
        } catch {
            print("保存装备物品到Keychain失败: \(error)")
        }
    }
    
    // 从Keychain加载装备物品
    private func loadEquippedItemsFromKeychain() {
        print("尝试从Keychain加载装备状态")
        
        // 从Keychain读取数据
        if let data = KeychainHelper.standard.read(service: "com.lazygeng.officerelax", account: "equippedItems") {
            do {
                let items = try JSONDecoder().decode([ShopItem].self, from: data)
                
                // 清空当前装备状态
                equippedEffects.removeAll()
                equippedSounds.removeAll()
                equippedBGMs.removeAll()
                equippedBackgrounds.removeAll()
                
                // 重新填充装备数组
                equippedEffects = items.filter { $0.type == .effect && ($0.isEquipped ?? false) }
                equippedSounds = items.filter { $0.type == .sound && ($0.isEquipped ?? false) }
                equippedBGMs = items.filter { $0.type == .bgm && ($0.isEquipped ?? false) }
                equippedBackgrounds = items.filter { $0.type == .background && ($0.isEquipped ?? false) }
                
                print("成功从Keychain加载\(items.count)个装备物品")
                
                // 执行特殊动画的初始化
                initializeSpecialAnimationsAndEffects(items: items)
                
            } catch {
                print("从Keychain解码装备物品失败: \(error)")
            }
        } else {
            print("未找到Keychain中的装备数据，将尝试从UserDefaults加载")
        }
    }
    
    // 初始化特殊动画和效果
    private func initializeSpecialAnimationsAndEffects(items: [ShopItem]) {
        DispatchQueue.main.async {
            for item in items {
                if item.isEquipped ?? false {
                    // 检查effect_3装备状态
                    if item.id == "effect_3" {
                        // 发送通知以刷新UI状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("Effect3StatusChanged"),
                            object: nil,
                            userInfo: ["isEquipped": true]
                        )
                        
                        // 确保预加载hammer girl动画
                        AnimationManager.shared.safeReloadAnimation(for: "hammer.run")
                        AnimationManager.shared.safeReloadAnimation(for: "hammer.attack")
                        
                        print("Keychain: 重新装备effect_3特效，启用hammer girl动画")
                    }
                    
                    // 检查effect_6装备状态
                    else if item.id == "effect_6" {
                        // 发送通知以刷新UI状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("Effect6StatusChanged"),
                            object: nil,
                            userInfo: ["isEquipped": true]
                        )
                        
                        // 预加载cat动画
                        AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
                        
                        print("Keychain: 重新装备effect_6特效，启用cat动画")
                    }
                    
                    // 检查sound_2装备状态(攻击音效)
                    else if item.id == "sound_2" {
                        // 发送通知以刷新攻击音效状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("EquipmentStatusChanged"),
                            object: nil
                        )
                        
                        print("Keychain: 重新装备sound_2，启用攻击音效")
                    }
                }
            }
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
        
        // 记录状态是否发生变化
        var stateChanged = false
        
        switch item.type {
        case .effect:
            if !equippedEffects.contains(where: { $0.id == itemId }) {
                // 添加互斥逻辑：如果装备effect_1，先卸载effect_6
                if itemId == "effect_1" && isItemEquipped(itemId: "effect_6") {
                    unequipItem(itemId: "effect_6")
                    print("互斥处理：装备effect_1时自动卸载effect_6")
                }
                // 添加互斥逻辑：如果装备effect_6，先卸载effect_1
                else if itemId == "effect_6" && isItemEquipped(itemId: "effect_1") {
                    unequipItem(itemId: "effect_1")
                    print("互斥处理：装备effect_6时自动卸载effect_1")
                }
                
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = true
                    equippedEffects.append(purchasedItems[index])
                    
                    // 同步状态到shopItems
                    if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                        shopItems[shopIndex].isEquipped = true
                    }
                    
                    stateChanged = true
                }
            }
        case .sound:
            if !equippedSounds.contains(where: { $0.id == itemId }) {
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = true
                    equippedSounds.append(purchasedItems[index])
                    
                    // 同步状态到shopItems
                    if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                        shopItems[shopIndex].isEquipped = true
                    }
                    
                    // 如果是sound_2，发送装备状态变更通知
                    if itemId == "sound_2" {
                        print("装备sound_2，启用攻击音效")
                        // 发送通知以刷新攻击音效状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("EquipmentStatusChanged"),
                            object: nil
                        )
                    }
                    
                    stateChanged = true
                }
            }
        case .bgm:
            // 检查是否已经装备了这个BGM
            if !equippedBGMs.contains(where: { $0.id == itemId }) {
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = true
                    equippedBGMs.append(purchasedItems[index])
                    
                    // 同步状态到shopItems
                    if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                        shopItems[shopIndex].isEquipped = true
                    }
                    
                    // 立即刷新音乐播放器状态
                    AudioManager.shared.refreshBGMPlayers()
                    
                    stateChanged = true
                }
            }
        case .background:
            // 如果背景已经装备，则不重复装备
            if !equippedBackgrounds.contains(where: { $0.id == itemId }) {
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = true
                    equippedBackgrounds.append(purchasedItems[index])
                    
                    // 同步状态到shopItems
                    if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                        shopItems[shopIndex].isEquipped = true
                    }
                    
                    stateChanged = true
                }
            }
        case .premium:
            // 处理特殊的premium道具装备逻辑
            if itemId == "effect_3" || itemId == "effect_6" {
                // 因为这些是特效类型的premium物品，将它们添加到equippedEffects中
                if !equippedEffects.contains(where: { $0.id == itemId }) {
                    // 添加互斥逻辑：如果装备effect_6，先卸载effect_1
                    if itemId == "effect_6" && isItemEquipped(itemId: "effect_1") {
                        unequipItem(itemId: "effect_1")
                        print("互斥处理：装备premium的effect_6时自动卸载effect_1")
                    }
                    
                    if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                        purchasedItems[index].isEquipped = true
                        equippedEffects.append(purchasedItems[index])
                        
                        // 同步状态到shopItems
                        if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                            shopItems[shopIndex].isEquipped = true
                        }
                        
                        // 对effect_3特效的特殊处理
                        if itemId == "effect_3" {
                            // 发送通知以刷新UI状态
                            NotificationCenter.default.post(
                                name: NSNotification.Name("Effect3StatusChanged"),
                                object: nil,
                                userInfo: ["isEquipped": true]
                            )
                            
                            // 预加载hammer girl动画
                            _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                            _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                            
                            print("装备effect_3特效，启用hammer girl动画")
                        }
                        
                        stateChanged = true
                    }
                }
            }
        }
        
        // 保存装备状态
        saveEquippedItems()
        
        // 如果状态变化，立即保存到keychain确保持久化
        if stateChanged {
            let allEquippedItems = equippedEffects + equippedSounds + equippedBGMs + equippedBackgrounds
            saveEquippedItemsToKeychain(allEquippedItems)
            print("装备状态已变更，已立即保存到KeyChain，当前装备总数: \(allEquippedItems.count)")
        }
        
        objectWillChange.send()
    }
    
    func unequipItem(itemId: String) {
        guard let item = purchasedItems.first(where: { $0.id == itemId }) else {
            return
        }
        
        // 记录状态是否发生变化
        var stateChanged = false
        
        switch item.type {
        case .effect:
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = false
                equippedEffects.removeAll(where: { $0.id == itemId })
                
                stateChanged = true
                
                // 如果是effect_1，不再重置所有动画配置
                if itemId == "effect_1" {
                    // 改为安全重载wizard动画
                    AnimationManager.shared.safeReloadAnimation(for: "effect.wizard_attack")
                    
                    // 发送通知以刷新UI
                    NotificationCenter.default.post(
                        name: NSNotification.Name("Effect1StatusChanged"),
                        object: nil,
                        userInfo: ["isEquipped": false]
                    )
                }
                // 如果是effect_6，不再重置所有动画配置
                else if itemId == "effect_6" {
                    // 改为安全重载cat动画
                    AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
                    
                    // 发送通知以刷新UI
                    NotificationCenter.default.post(
                        name: NSNotification.Name("Effect6StatusChanged"),
                        object: nil,
                        userInfo: ["isEquipped": false]
                    )
                }
                // 如果是effect_2，不再重置所有动画配置
                else if itemId == "effect_2" {
                    // 改为安全重载闪电动画
                    AnimationManager.shared.safeReloadAnimation(for: "effect.lightning")
                    
                    // 停止闪电音效播放
                    AudioManager.shared.stopSound("shop_thunder")
                    
                    print("已卸载闪电特效，闪电音效将不再播放")
                }
                // 如果是effect_5，不再重置所有动画配置
                else if itemId == "effect_5" {
                    // 改为安全重载旅人动画
                    AnimationManager.shared.safeReloadAnimation(for: "traveller.sit")
                    print("已卸载旅人特效")
                }
                // 如果是effect_3，不再重置所有动画配置
                else if itemId == "effect_3" {
                    // 不再重置动画配置，只预加载原始英雄动画
                    // 改为安全重载英雄动画
                    AnimationManager.shared.safeReloadAnimation(for: "hero.run")
                    AnimationManager.shared.safeReloadAnimation(for: "hero.attack")
                    
                    print("已卸载effect_3特效，恢复原始英雄动画")
                    
                    // 发送通知以刷新UI状态
                    NotificationCenter.default.post(
                        name: NSNotification.Name("Effect3StatusChanged"),
                        object: nil,
                        userInfo: ["isEquipped": false]
                    )
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
                
                // 如果是sound_1，停止任何正在播放的闪电音效
                if itemId == "sound_1" {
                    // 停止闪电音效播放
                    AudioManager.shared.stopSound("shop_thunder")
                    print("卸载sound_1，停止闪电音效播放")
                }
                // 如果是sound_2，发送装备状态变更通知
                else if itemId == "sound_2" {
                    print("卸载sound_2，不再播放攻击音效")
                    // 发送通知以刷新攻击音效状态
                    NotificationCenter.default.post(
                        name: NSNotification.Name("EquipmentStatusChanged"),
                        object: nil
                    )
                }
            }
        case .bgm:
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = false
                equippedBGMs.removeAll(where: { $0.id == itemId })
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = false
                }
                
                // 立即刷新音乐播放器状态
                AudioManager.shared.refreshBGMPlayers()
            }
        case .background:
            if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                purchasedItems[index].isEquipped = false
                equippedBackgrounds.removeAll(where: { $0.id == itemId })
                
                // 同步状态到shopItems
                if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                    shopItems[shopIndex].isEquipped = false
                }
            }
        case .premium:
            // 处理特殊的premium道具卸载逻辑
            if itemId == "effect_3" || itemId == "effect_6" {
                // 因为这些是特效类型的premium物品，从equippedEffects中移除它们
                if let index = purchasedItems.firstIndex(where: { $0.id == itemId }) {
                    purchasedItems[index].isEquipped = false
                    equippedEffects.removeAll(where: { $0.id == itemId })
                    
                    // 同步状态到shopItems
                    if let shopIndex = shopItems.firstIndex(where: { $0.id == itemId }) {
                        shopItems[shopIndex].isEquipped = false
                    }
                    
                    // 对effect_3特效的特殊处理
                    if itemId == "effect_3" {
                        // 不再重置动画配置，只预加载原始英雄动画
                        // 改为安全重载英雄动画
                        AnimationManager.shared.safeReloadAnimation(for: "hero.run")
                        AnimationManager.shared.safeReloadAnimation(for: "hero.attack")
                        
                        print("已卸载effect_3特效，恢复原始英雄动画")
                        
                        // 发送通知以刷新UI状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("Effect3StatusChanged"),
                            object: nil,
                            userInfo: ["isEquipped": false]
                        )
                    }
                    // 对effect_6特效的特殊处理
                    else if itemId == "effect_6" {
                        // 不再重置动画配置
                        // 改为安全重载cat动画
                        AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
                        print("已卸载effect_6特效")
                        
                        // 发送通知以刷新UI状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("Effect6StatusChanged"),
                            object: nil,
                            userInfo: ["isEquipped": false]
                        )
                    }
                }
            }
        }
        
        // 保存装备状态
        saveEquippedItems()
        
        // 如果状态变化，立即保存到keychain确保持久化
        if stateChanged {
            let allEquippedItems = equippedEffects + equippedSounds + equippedBGMs + equippedBackgrounds
            saveEquippedItemsToKeychain(allEquippedItems)
            print("卸载状态已变更，已立即保存到KeyChain，当前装备总数: \(allEquippedItems.count)")
        }
        
        // 通知观察者装备状态已更改
        objectWillChange.send()
    }
    
    // 方便检查商品是否被装备
    func isItemEquipped(itemId: String) -> Bool {
        // 首先检查各个对应类型的装备数组
        if equippedEffects.contains(where: { $0.id == itemId }) {
            return true
        }
        
        if equippedSounds.contains(where: { $0.id == itemId }) {
            return true
        }
        
        if equippedBGMs.contains(where: { $0.id == itemId }) {
            return true
        }
        
        if equippedBackgrounds.contains(where: { $0.id == itemId }) {
            return true
        }
        
        // 最后检查购买商品状态（作为备用）
        if let item = purchasedItems.first(where: { $0.id == itemId }),
           let isEquipped = item.isEquipped, isEquipped {
            return true
        }
        
        return false
    }
    
    func getEquippedItems(ofType type: ShopItem.ItemType) -> [ShopItem] {
        switch type {
        case .effect:
            return equippedEffects
        case .sound:
            return equippedSounds
        case .bgm:
            return equippedBGMs
        case .background:
            return equippedBackgrounds
        case .premium:
            return []
        }
    }
    
    // 验证并修复礼包物品的购买状态
    func verifyAndFixGiftPackageItems() {
        // 获取礼包中包含的物品ID
        let giftPackageItems = GiftPackageManager.shared.starterPackage.includedItems
        
        // 检查礼包状态
        let hasAnyGiftItem = purchasedItems.contains { item in
            giftPackageItems.contains(item.id)
        }
        
        // 如果有任何一个礼包物品，确保所有礼包物品都解锁
        if hasAnyGiftItem {
            var needsSave = false
            
            for itemId in giftPackageItems {
                // 检查商店中是否存在该物品
                if let item = shopItems.first(where: { $0.id == itemId }) {
                    // 检查该物品是否已经设置为购买状态
                    let shopIndex = shopItems.firstIndex(where: { $0.id == itemId })
                    if shopIndex != nil && shopItems[shopIndex!].isPurchased != true {
                        shopItems[shopIndex!].isPurchased = true
                        needsSave = true
                        print("已修复商店物品购买状态: \(itemId)")
                    }
                    
                    // 检查该物品是否存在于已购买列表中
                    if !purchasedItems.contains(where: { $0.id == itemId }) {
                        var purchasedItem = item
                        purchasedItem.isPurchased = true
                        purchasedItems.append(purchasedItem)
                        needsSave = true
                        print("已添加礼包物品到购买列表: \(itemId)")
                    } else {
                        // 如果存在于已购买列表但状态不对，更新状态
                        let purchasedIndex = purchasedItems.firstIndex(where: { $0.id == itemId })
                        if purchasedIndex != nil && purchasedItems[purchasedIndex!].isPurchased != true {
                            purchasedItems[purchasedIndex!].isPurchased = true
                            needsSave = true
                            print("已修复已购物品状态: \(itemId)")
                        }
                    }
                }
            }
            
            // 如果有任何修改，保存并通知UI更新
            if needsSave {
                savePurchasedItems()
                objectWillChange.send()
                print("已修复礼包物品的购买状态")
            }
        }
    }
    
    // 添加一个方法专门处理应用程序恢复时加载和应用已装备的物品
    func loadAndApplyEquippedItems() {
        // 清空当前装备状态
        equippedEffects.removeAll()
        equippedSounds.removeAll()
        equippedBGMs.removeAll()
        equippedBackgrounds.removeAll()
        
        // 优先从Keychain加载
        print("应用恢复: 尝试从Keychain加载装备状态")
        if let data = KeychainHelper.standard.read(service: "com.lazygeng.officerelax", account: "equippedItems") {
            do {
                let items = try JSONDecoder().decode([ShopItem].self, from: data)
                
                // 重新填充装备数组
                equippedEffects = items.filter { $0.type == .effect && ($0.isEquipped ?? false) }
                equippedSounds = items.filter { $0.type == .sound && ($0.isEquipped ?? false) }
                equippedBGMs = items.filter { $0.type == .bgm && ($0.isEquipped ?? false) }
                equippedBackgrounds = items.filter { $0.type == .background && ($0.isEquipped ?? false) }
                
                print("应用恢复: 成功从Keychain加载\(items.count)个装备物品")
                
                // 执行特殊动画的初始化
                initializeSpecialAnimationsAndEffects(items: items)
                
                // 确保BGM播放器状态与装备状态一致
                AudioManager.shared.refreshBGMPlayers()
                
                // 通知其他组件ShopManager已重新加载装备状态
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShopManagerItemsReloaded"),
                    object: nil
                )
                
                return // 如果Keychain加载成功，就直接返回
            } catch {
                print("应用恢复: 从Keychain解码装备物品失败，将尝试UserDefaults: \(error)")
            }
        }
        
        // 如果Keychain加载失败，尝试从UserDefaults加载
        if let data = UserDefaults.standard.data(forKey: "equippedItems"),
           let items = try? JSONDecoder().decode([ShopItem].self, from: data) {
            
            // 重新填充装备数组
            equippedEffects = items.filter { $0.type == .effect && ($0.isEquipped ?? false) }
            equippedSounds = items.filter { $0.type == .sound && ($0.isEquipped ?? false) }
            equippedBGMs = items.filter { $0.type == .bgm && ($0.isEquipped ?? false) }
            equippedBackgrounds = items.filter { $0.type == .background && ($0.isEquipped ?? false) }
            
            // 确保特殊物品的效果被正确应用
            for item in items {
                if item.isEquipped ?? false {
                    // 检查effect_3装备状态
                    if item.id == "effect_3" {
                        // 发送通知以刷新UI状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("Effect3StatusChanged"),
                            object: nil,
                            userInfo: ["isEquipped": true]
                        )
                        
                        // 确保预加载hammer girl动画
                        _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                        _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                        
                        print("重新装备effect_3特效，启用hammer girl动画")
                    }
                    
                    // 检查effect_6装备状态
                    else if item.id == "effect_6" {
                        // 发送通知以刷新UI状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("Effect6StatusChanged"),
                            object: nil,
                            userInfo: ["isEquipped": true]
                        )
                        
                        // 预加载cat动画
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                        
                        print("重新装备effect_6特效，启用cat动画")
                    }
                    
                    // 检查sound_2装备状态(攻击音效)
                    else if item.id == "sound_2" {
                        // 发送通知以刷新攻击音效状态
                        NotificationCenter.default.post(
                            name: NSNotification.Name("EquipmentStatusChanged"),
                            object: nil
                        )
                        
                        print("重新装备sound_2，启用攻击音效")
                    }
                }
            }
            
            // 确保BGM播放器状态与装备状态一致
            AudioManager.shared.refreshBGMPlayers()
            
            print("已重新加载\(items.count)个装备物品")
            
            // 同时保存到Keychain，确保下次能从Keychain加载
            saveEquippedItemsToKeychain(items)
            
            // 通知其他组件ShopManager已重新加载装备状态
            NotificationCenter.default.post(
                name: NSNotification.Name("ShopManagerItemsReloaded"),
                object: nil
            )
        } else {
            print("没有找到已装备的物品数据")
        }
    }
} 