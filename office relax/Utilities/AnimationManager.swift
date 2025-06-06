//
//  AnimationManager.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI
import Combine
import AVFoundation

// 动画配置模型
struct AnimationConfig: Codable {
    var version: String
    var animations: [String: [String: AnimationDetails]]
    var scenes: [String: SceneConfig]
    var defaults: DefaultConfig
    
    struct AnimationDetails: Codable {
        var frames: [String]?
        var fps: Double?
        var scale: Double?
        var offset: OffsetConfig
        var flipped: Bool?
        var loop: Bool?
    }
    
    struct SizeConfig: Codable {
        var width: CGFloat
        var height: CGFloat
    }
    
    struct OffsetConfig: Codable {
        var x: CGFloat
        var y: CGFloat
    }
    
    struct SceneConfig: Codable {
        var hero_position: OffsetConfig
        var name_label: NameLabelConfig
        var active_animations: [String]
    }
    
    struct NameLabelConfig: Codable {
        var offset_y: CGFloat
        var spacing: CGFloat
    }
    
    struct DefaultConfig: Codable {
        var placeholder_icon: [String: String]
        var fallback_size: SizeConfig
    }
}

// 单个动画的详细信息
struct AnimationInfo {
    var name: String
    var category: String
    var frames: [UIImage]
    var fps: Double
    var scale: Double
    var offset: CGPoint
    var flipped: Bool
    var loop: Bool
    var placeholder: String
    
    init(name: String, category: String, config: AnimationConfig.AnimationDetails) {
        self.name = name
        self.category = category
        self.frames = []
        self.fps = config.fps ?? 5.0
        self.scale = config.scale ?? 1.0
        self.offset = CGPoint(x: config.offset.x, y: config.offset.y)
        self.flipped = config.flipped ?? false
        self.loop = config.loop ?? true
        self.placeholder = "questionmark" // 默认占位符，将在AnimationManager中设置
    }
}

// 动画管理器
class AnimationManager: ObservableObject {
    static let shared = AnimationManager()
    
    @Published var config: AnimationConfig?
    @Published private(set) var loadedAnimations: [String: AnimationInfo] = [:]
    @Published private(set) var preloadedFrames: [String: [UIImage]] = [:]
    
    private init() {
        loadConfig()
    }
    
    // 加载配置文件
    func loadConfig() {
        if let configURL = Bundle.main.url(forResource: "animation_config", withExtension: "json"),
           let configData = try? Data(contentsOf: configURL) {
            do {
                let decoder = JSONDecoder()
                config = try decoder.decode(AnimationConfig.self, from: configData)
                print("动画配置加载成功，版本: \(config?.version ?? "未知")")
                
                // 预处理所有动画信息
                processAllAnimations()
            } catch {
                print("动画配置解析失败: \(error)")
            }
        } else {
            print("未找到动画配置文件")
        }
    }
    
    // 重新加载配置并刷新所有动画，但保持特定动画的状态
    func reloadConfigurationAndRefresh() {
        // 检查当前是否装备了effect_3和effect_6，以及sound_2
        let hasEffect3 = ShopManager.shared.isItemEquipped(itemId: "effect_3")
        let hasEffect6 = ShopManager.shared.isItemEquipped(itemId: "effect_6")
        let hasSound2 = ShopManager.shared.isItemEquipped(itemId: "sound_2")
        
        // 保存已装备特殊动画的相关信息
        var preservedAnimations: [String: AnimationInfo] = [:]
        if hasEffect3 {
            if let hammerRun = loadedAnimations["hammer.run"] {
                preservedAnimations["hammer.run"] = hammerRun
            }
            if let hammerAttack = loadedAnimations["hammer.attack"] {
                preservedAnimations["hammer.attack"] = hammerAttack
            }
            print("保留hammer girl动画配置")
        }
        
        if hasEffect6 {
            if let catEffect = loadedAnimations["effect.cat"] {
                preservedAnimations["effect.cat"] = catEffect
            }
            print("保留cat动画配置")
        }
        
        // 使用异步队列，避免在视图更新周期中修改@Published属性
        DispatchQueue.main.async {
            // 清空现有缓存
            let oldAnimations = self.loadedAnimations
            self.loadedAnimations.removeAll()
            self.preloadedFrames.removeAll()
            
            // 重新加载配置
            self.loadConfig()
            
            // 恢复保存的特殊动画配置
            for (key, animInfo) in preservedAnimations {
                self.loadedAnimations[key] = animInfo
                if let frames = self.preloadedFrames[key] {
                    print("恢复\(key)动画配置和帧")
                } else {
                    // 如果帧未保存，尝试重新加载
                    self.reloadAnimation(for: key)
                    print("重新加载\(key)动画帧")
                }
            }
            
            // 通知观察者配置已更新
            self.objectWillChange.send()
            
            print("动画配置已重新加载和刷新，保留特殊动画状态")
            
            // 如果装备了effect_3，发送状态更新通知
            if hasEffect3 {
                NotificationCenter.default.post(
                    name: NSNotification.Name("Effect3StatusChanged"),
                    object: nil,
                    userInfo: ["isEquipped": true]
                )
            }
            
            // 如果装备了effect_6，发送状态更新通知
            if hasEffect6 {
                NotificationCenter.default.post(
                    name: NSNotification.Name("Effect6StatusChanged"),
                    object: nil,
                    userInfo: ["isEquipped": true]
                )
            }
            
            // 如果装备了sound_2，发送装备状态更新通知
            if hasSound2 {
                NotificationCenter.default.post(
                    name: NSNotification.Name("EquipmentStatusChanged"),
                    object: nil
                )
            }
        }
    }
    
    // 处理所有动画信息
    private func processAllAnimations() {
        guard let config = config else { return }
        
        // 遍历所有动画分类
        for (category, animations) in config.animations {
            for (name, details) in animations {
                // 创建动画信息对象
                var animInfo = AnimationInfo(name: name, category: category, config: details)
                
                // 设置占位符
                animInfo.placeholder = config.defaults.placeholder_icon[category] ?? "questionmark"
                
                // 添加到已加载动画字典
                let animKey = "\(category).\(name)"
                loadedAnimations[animKey] = animInfo
                
                // 预加载动画帧
                if let frameNames = details.frames {
                    preloadFrames(for: animKey, frameNames: frameNames)
                }
            }
        }
    }
    
    // 预加载动画帧
    func preloadFrames(for animKey: String, frameNames: [String]) {
        var frames: [UIImage] = []
        
        for frameName in frameNames {
            if let image = UIImage(named: frameName) {
                // 高质量处理
                let size = image.size
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: size))
                if let processedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    frames.append(processedImage)
                } else {
                    frames.append(image)
                }
                UIGraphicsEndImageContext()
            }
        }
        
        if !frames.isEmpty {
            // 使用异步队列更新，避免在视图更新周期中修改@Published属性
            DispatchQueue.main.async {
                self.preloadedFrames[animKey] = frames
                
                // 更新动画信息中的帧数组
                if var animInfo = self.loadedAnimations[animKey] {
                    animInfo.frames = frames
                    self.loadedAnimations[animKey] = animInfo
                }
            }
        }
    }
    
    // 获取动画信息
    func getAnimationInfo(for key: String) -> AnimationInfo? {
        return loadedAnimations[key]
    }
    
    // 获取预加载的帧
    func getPreloadedFrames(for key: String) -> [UIImage] {
        return preloadedFrames[key] ?? []
    }
    
    // 获取场景配置
    func getSceneConfig(for scene: String) -> AnimationConfig.SceneConfig? {
        return config?.scenes[scene]
    }
    
    // 获取活动动画
    func getActiveAnimations(for scene: String) -> [AnimationInfo] {
        guard let sceneConfig = config?.scenes[scene],
              let activeKeys = sceneConfig.active_animations as? [String] else {
            return []
        }
        
        return activeKeys.compactMap { getAnimationInfo(for: $0) }
    }
    
    // 重新加载指定动画
    func reloadAnimation(for key: String) {
        let parts = key.split(separator: ".")
        guard parts.count == 2,
              let category = parts.first,
              let name = parts.last,
              let details = config?.animations[String(category)]?[String(name)],
              let frameNames = details.frames else {
            return
        }
        
        // 使用异步队列加载帧，避免在视图更新周期中修改@Published属性
        DispatchQueue.main.async {
            self.preloadFrames(for: key, frameNames: frameNames)
        }
    }
    
    // 仅重新加载指定动画，不影响其他动画
    func safeReloadAnimation(for key: String) {
        let parts = key.split(separator: ".")
        guard parts.count == 2,
              let category = parts.first,
              let name = parts.last,
              let details = config?.animations[String(category)]?[String(name)],
              let frameNames = details.frames else {
            return
        }
        
        // 只加载这个特定动画的帧，不清空其他缓存
        var frames: [UIImage] = []
        
        for frameName in frameNames {
            if let image = UIImage(named: frameName) {
                // 高质量处理
                let size = image.size
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: size))
                if let processedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    frames.append(processedImage)
                } else {
                    frames.append(image)
                }
                UIGraphicsEndImageContext()
            }
        }
        
        if !frames.isEmpty {
            // 使用异步队列更新这个特定动画
            DispatchQueue.main.async {
                self.preloadedFrames[key] = frames
                
                // 更新动画信息中的帧数组
                if var animInfo = self.loadedAnimations[key] {
                    animInfo.frames = frames
                    self.loadedAnimations[key] = animInfo
                    print("已安全重载动画: \(key)")
                } else {
                    // 如果动画信息不存在，创建新的
                    var animInfo = AnimationInfo(name: String(name), category: String(category), config: details)
                    animInfo.frames = frames
                    
                    // 设置占位符
                    animInfo.placeholder = self.config?.defaults.placeholder_icon[String(category)] ?? "questionmark"
                    
                    self.loadedAnimations[key] = animInfo
                    print("已创建新动画: \(key)")
                }
                
                // 通知更新
                self.objectWillChange.send()
            }
        }
    }
}

// 高质量动画视图，从配置加载
struct ConfigurableAnimatedView: View {
    let animationKey: String
    let completionHandler: (() -> Void)?
    
    @StateObject private var manager = AnimationManager.shared
    @State private var hasStartedAnimation = false
    
    init(animationKey: String, completionHandler: (() -> Void)? = nil) {
        self.animationKey = animationKey
        self.completionHandler = completionHandler
    }
    
    var body: some View {
        Group {
            if let animInfo = manager.getAnimationInfo(for: animationKey),
               !animInfo.frames.isEmpty {
                HighQualityAnimatedImageView(
                    images: animInfo.frames,
                    fps: animInfo.fps,
                    isLooping: animInfo.loop,
                    playbackCompleted: completionHandler,
                    animationKey: animationKey
                )
                .scaleEffect(x: animInfo.flipped ? -animInfo.scale : animInfo.scale, 
                             y: animInfo.scale)
                .offset(x: animInfo.offset.x, y: animInfo.offset.y)
                .animation(.easeInOut(duration: 0.2), value: animInfo.scale)
                .animation(.easeInOut(duration: 0.2), value: animInfo.offset)
            } else {
                // 占位符
                let placeholder = manager.getAnimationInfo(for: animationKey)?.placeholder ?? "questionmark"
                Image(systemName: placeholder)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundColor(.white)
                    .onAppear {
                        // 如果显示了占位符，尝试立即加载动画，使用异步加载
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            manager.reloadAnimation(for: animationKey)
                        }
                    }
            }
        }
        .onAppear {
            // 预加载动画帧，使用异步加载避免视图更新周期内修改@Published属性
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if manager.getPreloadedFrames(for: animationKey).isEmpty {
                    manager.reloadAnimation(for: animationKey)
                }
            
                // 确保第一次出现时立即触发动画
                hasStartedAnimation = true
            }
        }
        .onChange(of: animationKey) { _ in
            // 当动画Key变化时重新加载，使用异步加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                manager.reloadAnimation(for: animationKey)
            }
        }
    }
}

class AttackSoundManager {
    static let shared = AttackSoundManager()
    
    // 标记是否装备了sound_2
    private var isSound2Equipped: Bool = false
    
    // 上次播放音效的时间
    private var lastSoundPlayTimes: [String: Date] = [:]
    
    // 音效播放最小间隔时间(秒)
    private let soundCooldown: TimeInterval = 0.8
    
    // 当前动画状态，用于检测是否应该播放音效
    private var currentAnimationStates: [String: Int] = [:]
    
    // 触发音效的帧索引
    private let heroSoundFrame: Int = 5
    private let hammerSoundFrame: Int = 7
    
    // 当前应用状态
    private var isInMainView: Bool = false
    private var isHeroEntryCompleted: Bool = false
    
    private init() {
        print("AttackSoundManager初始化")
        
        // 异步立即检查sound_2装备状态
        DispatchQueue.main.async { [weak self] in
            self?.isSound2Equipped = ShopManager.shared.isItemEquipped(itemId: "sound_2")
            print("初始sound_2装备状态: \(self?.isSound2Equipped == true ? "已装备" : "未装备")")
        }
        
        // 监听动画帧变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFrameChange),
            name: NSNotification.Name("AnimationFrameChanged"),
            object: nil
        )
        
        // 每次向系统请求更新sound_2状态
        updateSound2Status()
        
        // 监听装备状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSound2Status),
            name: NSNotification.Name("EquipmentStatusChanged"),
            object: nil
        )
        
        // 监听ShopManager初始化完成的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shopManagerReady),
            name: NSNotification.Name("ShopManagerReady"),
            object: nil
        )
        
        // 监听ShopManager物品重新加载的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shopManagerItemsReloaded),
            name: NSNotification.Name("ShopManagerItemsReloaded"),
            object: nil
        )
        
        // 监听视图状态变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleViewStateChange),
            name: NSNotification.Name("ViewStateChanged"),
            object: nil
        )
        
        // 监听英雄入场动画完成通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeroEntryAnimationCompleted),
            name: NSNotification.Name("HeroEntryAnimationCompleted"),
            object: nil
        )
        
        // 监听应用变为活跃状态的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // 监听自定义应用变为活跃状态的通知（来自SceneDelegate）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(customApplicationDidBecomeActive),
            name: NSNotification.Name("ApplicationDidBecomeActive"),
            object: nil
        )
        
        // 监听声音效果状态更新通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSoundEffectStatusUpdated),
            name: NSNotification.Name("SoundEffectStatusUpdated"),
            object: nil
        )
    }
    
    // 应用变为活跃时调用
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        print("应用变为活跃，强制更新sound_2装备状态 (系统通知)")
        forceUpdateSound2Status()
    }
    
    // 自定义应用变为活跃通知处理
    @objc func customApplicationDidBecomeActive(_ notification: Notification) {
        print("应用变为活跃，强制更新sound_2装备状态 (自定义通知)")
        forceUpdateSound2Status()
        
        // 延迟后再次更新，防止状态被其他操作覆盖
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.forceUpdateSound2Status()
        }
    }
    
    // 处理声音效果状态更新通知
    @objc func handleSoundEffectStatusUpdated(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let isEquipped = userInfo["isSound2Equipped"] as? Bool {
            if isSound2Equipped != isEquipped {
                isSound2Equipped = isEquipped
                print("通过通知更新sound_2状态: \(isSound2Equipped ? "已装备" : "未装备")")
            }
        }
    }
    
    // ShopManager物品重新加载时调用
    @objc func shopManagerItemsReloaded(_ notification: Notification) {
        print("ShopManager物品已重新加载，更新sound_2装备状态")
        forceUpdateSound2Status()
        
        // 延迟后再次更新，确保状态稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.forceUpdateSound2Status()
        }
    }
    
    // ShopManager准备完成时调用
    @objc func shopManagerReady(_ notification: Notification) {
        // 重新检查sound_2装备状态
        updateSound2Status()
        
        // 强制立即更新一次
        DispatchQueue.main.async { [weak self] in
            self?.forceUpdateSound2Status()
        }
    }
    
    // 更新sound_2装备状态
    @objc func updateSound2Status() {
        let oldStatus = isSound2Equipped
        isSound2Equipped = ShopManager.shared.isItemEquipped(itemId: "sound_2")
        
        if oldStatus != isSound2Equipped {
            print("Sound_2装备状态变更: \(isSound2Equipped ? "已装备" : "未装备")")
            
            // 发送通知确保其他组件能够感知
            NotificationCenter.default.post(
                name: NSNotification.Name("SoundEffectStatusUpdated"),
                object: nil,
                userInfo: ["isSound2Equipped": isSound2Equipped]
            )
        }
    }
    
    // 强制更新sound_2装备状态
    func forceUpdateSound2Status() {
        let oldStatus = isSound2Equipped
        isSound2Equipped = ShopManager.shared.isItemEquipped(itemId: "sound_2")
        
        if oldStatus != isSound2Equipped {
            print("强制更新sound_2装备状态: \(isSound2Equipped ? "已装备" : "未装备")")
        } else {
            print("强制检查sound_2装备状态 (未变化): \(isSound2Equipped ? "已装备" : "未装备")")
        }
        
        // 无论状态是否变化，都发送通知确保其他组件能够感知
        NotificationCenter.default.post(
            name: NSNotification.Name("SoundEffectStatusUpdated"),
            object: nil,
            userInfo: ["isSound2Equipped": isSound2Equipped]
        )
    }
    
    // 处理视图状态变化
    @objc func handleViewStateChange(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let viewName = userInfo["viewName"] as? String {
            // 只有在MainView中才启用音效
            isInMainView = (viewName == "MainView")
            print("视图状态变更: \(viewName) (音效\(isInMainView ? "启用" : "禁用"))")
            
            // 在进入MainView时强制更新sound_2状态
            if isInMainView {
                forceUpdateSound2Status()
            }
        }
    }
    
    // 处理英雄入场动画完成通知
    @objc func handleHeroEntryAnimationCompleted(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let completed = userInfo["completed"] as? Bool {
            isHeroEntryCompleted = completed
            print("英雄入场动画\(completed ? "完成" : "未完成")")
        }
    }
    
    // 检查当前显示的是哪个角色（hero或hammer girl）
    private func isHammerGirlActive() -> Bool {
        return ShopManager.shared.isItemEquipped(itemId: "effect_3")
    }
    
    // 是否可以播放指定动画的音效
    private func canPlaySound(forAnim animKey: String) -> Bool {
        if let lastTime = lastSoundPlayTimes[animKey] {
            let elapsed = Date().timeIntervalSince(lastTime)
            return elapsed >= soundCooldown
        }
        return true
    }
    
    // 处理帧变化通知
    @objc func handleFrameChange(_ notification: Notification) {
        // 多重检查：
        // 1. 确保sound_2已装备
        // 2. 确保当前在MainView中（不在focus_start页面）
        // 3. 确保英雄入场动画已完成（不是run动画）
        // 4. 确保全局音效播放已启用
        guard isSound2Equipped && isInMainView && isHeroEntryCompleted && 
              AudioManager.shared.isSoundPlaybackEnabled else {
            return
        }
        
        // 从通知中提取信息
        guard let userInfo = notification.userInfo,
              let frameIndex = userInfo["frameIndex"] as? Int,
              let animationKey = userInfo["animationKey"] as? String else {
            return
        }
        
        // 检查当前显示的角色类型
        let isHammerMode = isHammerGirlActive()
        
        // 如果当前是hero模式，只处理hero.attack动画
        if !isHammerMode && animationKey == "hero.attack" {
            // 如果到达触发帧，并且满足冷却时间，播放hero攻击音效
            if frameIndex == heroSoundFrame && canPlaySound(forAnim: animationKey) {
                // 播放hero攻击音效
                AudioManager.shared.playSound("shop_attack")
                print("播放hero攻击音效 (触发帧:\(frameIndex))")
                
                // 记录播放时间
                lastSoundPlayTimes[animationKey] = Date()
            }
        }
        // 如果当前是hammer girl模式，只处理hammer.attack动画
        else if isHammerMode && animationKey == "hammer.attack" {
            // 如果到达触发帧，并且满足冷却时间，播放hammer girl攻击音效
            if frameIndex == hammerSoundFrame && canPlaySound(forAnim: animationKey) {
                // 播放hammer girl降速攻击音效
                playSlowerAttackSound()
                print("播放hammer girl攻击音效 (降速版) (触发帧:\(frameIndex))")
                
                // 记录播放时间
                lastSoundPlayTimes[animationKey] = Date()
            }
        }
    }
    
    // 播放较慢的攻击音效 (专为hammer girl设计)
    private func playSlowerAttackSound() {
        // 检查全局音效播放状态
        if !AudioManager.shared.isSoundPlaybackEnabled {
            print("全局音效播放已禁用，不播放hammer girl攻击音效")
            return
        }
        
        // 绕过AudioManager，直接播放降速的攻击音效
        guard let soundURL = Bundle.main.url(forResource: "attack", withExtension: "mp3") else {
            print("未找到音效文件: attack")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.volume = 0.5  // 设置音量为0.5
            player.rate = 0.78   // 降低播放速率 (更慢)
            player.prepareToPlay()
            player.play()
            
            // 播放完成后清理
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.5) {
                player.stop()
            }
        } catch {
            print("播放音效时出错: \(error.localizedDescription)")
        }
    }
    
    // 手动设置当前视图状态（用于在不发送通知的情况下更新）
    func updateViewState(isMainView: Bool) {
        self.isInMainView = isMainView
        print("手动更新视图状态: \(isMainView ? "MainView" : "其他视图")")
    }
    
    // 手动设置英雄入场状态（用于在不发送通知的情况下更新）
    func updateHeroEntryState(completed: Bool) {
        self.isHeroEntryCompleted = completed
        print("手动更新英雄入场状态: \(completed ? "完成" : "未完成")")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 