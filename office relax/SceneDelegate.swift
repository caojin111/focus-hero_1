import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 设置只支持竖屏方向 - 使用多种方法确保强制竖屏
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        
        // 设置方向掩码，仅允许竖屏
        let orientationMask: UIInterfaceOrientationMask = .portrait
        UIViewController.attemptRotationToDeviceOrientation()
        
        // 创建并应用旋转设置
        if let rootViewController = windowScene.windows.first?.rootViewController {
            // 设置方向掩码
            rootViewController.setOverrideTraitCollection(
                UITraitCollection(traitsFrom: [
                    rootViewController.traitCollection,
                    UITraitCollection(verticalSizeClass: .regular),
                    UITraitCollection(horizontalSizeClass: .compact)
                ]),
                forChild: rootViewController
            )
            
            // 更新支持的方向
            rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        
        // 将相同的限制应用到所有窗口
        for window in windowScene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        
        print("应用启动: 场景初始化，已设置强制竖屏")
        
        // 初始化必要的管理器
        _ = UserDataManager.shared
        _ = ShopManager.shared
        _ = AnimationManager.shared
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("应用退出: 场景断开连接")
        
        // 保存当前装备状态
        ShopManager.shared.saveEquippedItems()
        ShopManager.shared.savePurchasedItems()
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("应用进入前台")
        
        // 通知后台计时管理器应用回到前台
        BackgroundTimerManager.shared.applicationDidBecomeActive()
        
        // 当应用进入前台时，强制刷新ShopManager以确保装备状态正确
        ShopManager.shared.refreshItems()
        
        // 重新加载并立即应用装备的物品状态（优先从Keychain）
        ShopManager.shared.loadAndApplyEquippedItems()
        
        // 确保sound_2状态立即更新
        DispatchQueue.main.async {
            AttackSoundManager.shared.forceUpdateSound2Status()
        }
        
        // 发送通知强制更新视图中的角色动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // 检查装备状态并加载对应动画
            self.checkAndApplyEquippedStatus()
            
            // 强制更新AttackSoundManager中的sound_2装备状态
            AttackSoundManager.shared.forceUpdateSound2Status()
            
            // 发送通知通知ItemsReloaded
            NotificationCenter.default.post(
                name: NSNotification.Name("ShopManagerItemsReloaded"),
                object: nil
            )
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("应用变为活跃")
        
        // 确保effect_3和effect_6的状态在每次应用变为活跃时都得到正确应用
        DispatchQueue.main.async {
            // 重新加载装备状态
            ShopManager.shared.loadAndApplyEquippedItems()
            
            // 检查装备状态并应用
            self.checkAndApplyEquippedStatus()
            
            // 强制更新攻击音效状态
            AttackSoundManager.shared.forceUpdateSound2Status()
            
            // 刷新动画状态
            self.forceRefreshAnimationsBasedOnEquipment()
        }
        
        // 额外延迟通知，确保UI完全加载后能接收到通知
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplicationDidBecomeActive"),
                object: nil
            )
            
            // 再次强制刷新
            self.forceRefreshAnimationsBasedOnEquipment()
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        print("应用即将进入非活跃状态")
        
        // 通知后台计时管理器应用即将进入后台
        BackgroundTimerManager.shared.applicationWillResignActive()
        
        // 应用即将进入非活跃状态
        // 保存当前装备状态到Keychain
        ShopManager.shared.saveEquippedItems()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("应用进入后台")
        
        // 保存当前装备状态到Keychain和UserDefaults
        ShopManager.shared.saveEquippedItems()
        ShopManager.shared.savePurchasedItems()
    }
    
    // 检查并应用当前装备状态
    private func checkAndApplyEquippedStatus() {
        // 特别强制重新应用effect_3和effect_6的装备状态
        let hasEffect3 = ShopManager.shared.isItemEquipped(itemId: "effect_3")
        let hasEffect6 = ShopManager.shared.isItemEquipped(itemId: "effect_6")
        let hasSound2 = ShopManager.shared.isItemEquipped(itemId: "sound_2")
        
        if hasEffect3 {
            // 使用safeReloadAnimation而不是getAnimationInfo，以确保动画正确加载
            AnimationManager.shared.safeReloadAnimation(for: "hammer.run")
            AnimationManager.shared.safeReloadAnimation(for: "hammer.attack")
            
            // 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("Effect3StatusChanged"),
                object: nil,
                userInfo: ["isEquipped": true]
            )
        }
        
        if hasEffect6 {
            // 使用safeReloadAnimation而不是getAnimationInfo，以确保动画正确加载
            AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
            
            // 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("Effect6StatusChanged"),
                object: nil,
                userInfo: ["isEquipped": true]
            )
        }
        
        print("应用状态检查：effect_3状态=\(hasEffect3), effect_6状态=\(hasEffect6), sound_2状态=\(hasSound2)")
        
        // 发送EquipmentStatusChanged通知以强制刷新所有装备状态
        NotificationCenter.default.post(
            name: NSNotification.Name("EquipmentStatusChanged"),
            object: nil
        )
    }
    
    // 强制刷新基于装备的动画
    private func forceRefreshAnimationsBasedOnEquipment() {
        let hasEffect3 = ShopManager.shared.isItemEquipped(itemId: "effect_3")
        let hasEffect6 = ShopManager.shared.isItemEquipped(itemId: "effect_6")
        
        if hasEffect3 {
            // 强制重载hammer girl动画
            AnimationManager.shared.safeReloadAnimation(for: "hammer.run")
            AnimationManager.shared.safeReloadAnimation(for: "hammer.attack")
            
            // 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("Effect3StatusChanged"),
                object: nil,
                userInfo: ["isEquipped": true]
            )
            
            print("应用变为活跃时，强制刷新hammer girl动画")
        }
        
        if hasEffect6 {
            // 强制重载cat动画
            AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
            
            // 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("Effect6StatusChanged"),
                object: nil,
                userInfo: ["isEquipped": true]
            )
            
            print("应用变为活跃时，强制刷新cat动画")
        }
    }
} 