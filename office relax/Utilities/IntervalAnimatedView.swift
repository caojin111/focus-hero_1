import SwiftUI
import Combine

/// 带间隔播放功能的动画视图
/// 可以设置每次动画播放后的间隔时间
struct IntervalAnimatedView: View {
    let animationKey: String
    let interval: TimeInterval
    var playbackCompleted: (() -> Void)?
    
    @State private var shouldPlay: Bool = true
    @State private var timer: Timer? = nil
    @State private var animationCompleted: Bool = false
    @State private var isPaused: Bool = false
    @State private var lastAnimationStart: Date = Date()
    @State private var isInWorkMode: Bool = true  // 默认为工作模式
    @State private var isLightningEffectsDisabled: Bool = false
    
    // 添加用于监测是否真正显示的属性
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    init(animationKey: String, interval: TimeInterval = 5.0, playbackCompleted: (() -> Void)? = nil) {
        self.animationKey = animationKey
        self.interval = interval
        self.playbackCompleted = playbackCompleted
    }
    
    var body: some View {
        Group {
            if shouldPlay && !isPaused {
                // 使用ConfigurableAnimatedView播放动画
                ConfigurableAnimatedView(animationKey: animationKey) {
                    // 动画播放完成后，等待间隔时间再重新播放
                    handleAnimationCompleted()
                }
                .onAppear {
                    // 记录动画开始时间
                    lastAnimationStart = Date()
                    print("开始播放动画 \(animationKey) 时间: \(lastAnimationStart)")
                    
                    // 如果是闪电动画且用户装备了闪电音效，同时播放音效
                    if animationKey == "effect.lightning" {
                        // 只有当闪电特效真正装备且显示时才播放
                        if isActuallyDisplayed() {
                            playLightningSoundIfEquipped()
                        }
                    }
                    
                    // 作为备份，设置一个定时器确保在动画完成后触发间隔
                    setupBackupCompletionTimer()
                }
                .background(GeometryReader { geo in
                    // 使用GeometryReader检测视图是否真正可见
                    Color.clear
                        .onAppear {
                            if geo.size.width > 0 && geo.size.height > 0 {
                                // 视图有实际尺寸，可能真正可见
                                print("动画视图 \(animationKey) 有实际尺寸")
                            }
                        }
                })
            } else {
                // 动画间隔期间不显示任何内容
                Color.clear
                    .onAppear {
                        // 如果是首次渲染并且未开始播放动画，手动开始计时器
                        if !animationCompleted && !isPaused {
                            print("初始化动画 \(animationKey) 的首次播放")
                            startAnimation(afterDelay: 0.1)
                        }
                    }
            }
        }
        .onAppear {
            // 确保初始状态是播放
            if !shouldPlay && !animationCompleted && !isPaused {
                startAnimation(afterDelay: 0.1)
            }
            
            // 添加暂停和恢复通知监听
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("PauseAnimations"),
                object: nil,
                queue: .main
            ) { _ in
                print("暂停动画 \(animationKey)")
                pauseAnimation()
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ResumeAnimations"),
                object: nil,
                queue: .main
            ) { _ in
                print("恢复动画 \(animationKey)")
                resumeAnimation()
            }
            
            // 监听工作/休息模式切换
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WorkModeChanged"),
                object: nil,
                queue: .main
            ) { notification in
                if let isWorkMode = notification.userInfo?["isWorkMode"] as? Bool {
                    self.isInWorkMode = isWorkMode
                    print("工作模式变更通知接收: \(isWorkMode ? "工作模式" : "休息模式")")
                    
                    // 如果闪电动画不再显示，立即停止相关音效
                    if animationKey == "effect.lightning" && !isWorkMode {
                        AudioManager.shared.stopAllShopSounds()
                    }
                }
            }
            
            // 监听胜利界面特殊通知 - 完全禁用闪电音效
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("DisableLightningEffects"),
                object: nil,
                queue: .main
            ) { notification in
                if let isDisabled = notification.userInfo?["isDisabled"] as? Bool {
                    self.isLightningEffectsDisabled = isDisabled
                    print("闪电音效\(isDisabled ? "已禁用" : "已启用") (通过特殊通知)")
                    
                    // 如果禁用闪电音效，立即停止相关音效
                    if isDisabled && animationKey == "effect.lightning" {
                        AudioManager.shared.stopSound("shop_thunder")
                    }
                }
            }
        }
        .onDisappear {
            // 清理计时器和通知
            cleanupTimers()
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // 检查这个动画是否真正被显示（对于闪电动画特别处理）
    private func isActuallyDisplayed() -> Bool {
        if animationKey == "effect.lightning" {
            // 1. 首先检查是否是工作模式，只有在工作模式才显示闪电特效
            guard isInWorkMode else {
                return false
            }
            
            // 2. 检查是否装备了闪电特效（effect_2）
            return ShopManager.shared.isItemEquipped(itemId: "effect_2")
        }
        return true
    }
    
    // 检查用户是否装备了闪电音效并播放
    private func playLightningSoundIfEquipped() {
        // 确保只有当前视图是闪电动画时才播放音效
        guard animationKey == "effect.lightning" else { return }
        
        // 检查是否通过特殊通知禁用了闪电音效
        guard !isLightningEffectsDisabled else {
            print("闪电音效通过特殊通知禁用，跳过播放")
            return
        }
        
        // 确保全局音效播放功能已启用
        guard AudioManager.shared.isSoundPlaybackEnabled else {
            print("全局音效播放已禁用，不播放闪电音效")
            return
        }
        
        // 确保闪电特效(effect_2)真正显示时才考虑播放
        guard isActuallyDisplayed() else { return }
        
        // 检查用户是否已装备sound_1音效
        let shopManager = ShopManager.shared
        
        // 注意：不需要在这里检查系统音效设置和音效冷却时间
        // AudioManager.playSound方法中已经包含对系统音效设置和冷却时间的检查
        // 所有以shop_开头的音效文件都会受到系统音效开关和音量控制
        // 同时也会遵循3秒冷却规则
        
        // 1. 检查是否通过正常方式装备
        if shopManager.isItemEquipped(itemId: "sound_1") {
            // 播放闪电音效
            AudioManager.shared.playSound("shop_thunder")
            print("播放闪电音效 (通过normal方式)")
            return
        }
        
        // 2. 如果正常方式失败，尝试备用方式检查
        // 检查商品是否已购买
        if let soundItem = shopManager.purchasedItems.first(where: { $0.id == "sound_1" }),
           let isEquipped = soundItem.isEquipped, isEquipped {
            // 商品已购买且标记为已装备
            AudioManager.shared.playSound("shop_thunder")
            print("播放闪电音效 (通过purchasedItems检查)")
            return
        }
        
        // 3. 直接检查equippedSounds数组
        if shopManager.equippedSounds.contains(where: { $0.id == "sound_1" }) {
            AudioManager.shared.playSound("shop_thunder")
            print("播放闪电音效 (通过equippedSounds检查)")
            return
        }
        
        // 移除备用方案，确保只有在sound_1真正装备时才播放音效
        print("闪电音效未播放：sound_1未装备")
    }
    
    // 开始播放动画
    private func startAnimation(afterDelay delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            withAnimation {
                print("启动动画 \(animationKey) 播放")
                shouldPlay = true
                lastAnimationStart = Date()
                
                // 只有当闪电特效真正显示时才播放音效
                if animationKey == "effect.lightning" && shouldPlay && isActuallyDisplayed() {
                    playLightningSoundIfEquipped()
                }
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // 设置备用完成计时器（防止回调失败）
    private func setupBackupCompletionTimer() {
        // 获取动画信息以计算持续时间
        if let animInfo = AnimationManager.shared.getAnimationInfo(for: animationKey) {
            let frames = Double(animInfo.frames.count)
            let fps = animInfo.fps
            let duration = frames / fps + 0.5 // 添加0.5秒缓冲
            
            print("为 \(animationKey) 设置备用完成计时器，预计持续时间: \(duration)秒")
            
            // 清理旧计时器
            timer?.invalidate()
            
            // 创建新计时器
            timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                // 检查动画是否已经足够长的时间（防止过早触发）
                let timeElapsed = Date().timeIntervalSince(lastAnimationStart)
                if timeElapsed >= duration - 1.0 {
                    print("备用计时器触发，动画播放时间: \(timeElapsed)秒")
                    handleAnimationCompleted()
                } else {
                    print("备用计时器触发太早，忽略。时间: \(timeElapsed)秒")
                    setupBackupCompletionTimer() // 重新设置计时器
                }
            }
            
            if let timer = timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    // 处理动画完成
    private func handleAnimationCompleted() {
        print("动画 \(animationKey) 播放完成，等待 \(interval) 秒后重新播放")
        animationCompleted = true
        shouldPlay = false
        
        // 重置当前计时器
        cleanupTimers()
        
        // 创建新的计时器
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            withAnimation {
                print("间隔结束，重新播放动画 \(animationKey)")
                shouldPlay = true
                lastAnimationStart = Date()
                
                // 只有当闪电特效真正显示时才播放音效
                if animationKey == "effect.lightning" && shouldPlay && isActuallyDisplayed() {
                    playLightningSoundIfEquipped()
                }
                
                // 立即设置备用计时器
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    setupBackupCompletionTimer()
                }
            }
        }
        
        // 确保在主线程运行
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // 调用完成回调
        playbackCompleted?()
    }
    
    // 暂停动画
    private func pauseAnimation() {
        isPaused = true
        cleanupTimers()
    }
    
    // 恢复动画
    private func resumeAnimation() {
        isPaused = false
        
        // 如果之前正在播放动画，则立即恢复播放
        if shouldPlay {
            // 保持当前状态
            lastAnimationStart = Date()
            setupBackupCompletionTimer()
        } else {
            // 如果之前在等待间隔，创建新的计时器继续等待
            startAnimation(afterDelay: interval / 2)
        }
    }
    
    // 清理所有计时器
    private func cleanupTimers() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    IntervalAnimatedView(animationKey: "effect.lightning", interval: 3.0)
        .frame(width: 300, height: 300)
        .background(Color.gray.opacity(0.3))
} 