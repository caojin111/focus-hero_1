//
//  MainView.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI
import UserNotifications
import QuartzCore
import UIKit

// 高清晰度动画视图组件
struct HighQualityAnimatedImageView: UIViewRepresentable {
    var images: [UIImage]
    var fps: Double
    var isLooping: Bool
    var playbackCompleted: (() -> Void)?
    var animationKey: String? // 添加动画键以标识动画
    
    init(images: [UIImage], fps: Double, isLooping: Bool = true, playbackCompleted: (() -> Void)? = nil, animationKey: String? = nil) {
        self.images = images
        self.fps = fps
        self.isLooping = isLooping
        self.playbackCompleted = playbackCompleted
        self.animationKey = animationKey
    }
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // 保持比例
        imageView.clipsToBounds = false
        imageView.layer.magnificationFilter = .linear // 提高清晰度
        imageView.layer.shouldRasterize = false // 避免模糊
        context.coordinator.imageView = imageView
        context.coordinator.animationKey = animationKey // 传递动画键
        
        // 添加观察者来监听暂停和恢复通知
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pauseAnimation),
            name: NSNotification.Name("PauseAnimations"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.resumeAnimation),
            name: NSNotification.Name("ResumeAnimations"),
            object: nil
        )
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // 更新animationKey
        context.coordinator.animationKey = animationKey
        
        // 停止任何现有动画
        uiView.stopAnimating()
        
        // 只有当有图片时才设置动画
        if !images.isEmpty {
            // 设置高质量图片
            uiView.animationImages = images
            uiView.animationDuration = Double(images.count) / fps
            uiView.animationRepeatCount = isLooping ? 0 : 1 // 0表示无限循环
            
            // 设置动画完成回调
            if !isLooping && playbackCompleted != nil {
                context.coordinator.playbackCompleted = playbackCompleted
                
                // 移除旧的观察者以避免重复
                NotificationCenter.default.removeObserver(context.coordinator, name: .UIImageViewAnimationDidFinish, object: nil)
                
                // 对于非循环动画，我们需要自己创建定时器来检测动画结束
                // UIImageView 不会自动发送动画完成通知
                context.coordinator.setupAnimationCompletionTimer(duration: Double(images.count) / fps)
            }
            
            // 为循环动画设置帧监控
            if isLooping {
                context.coordinator.setupFrameMonitor(fps: fps, frameCount: images.count)
            }
            
            // 开始动画
            uiView.startAnimating()
        } else {
            uiView.image = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(images: images, animationKey: animationKey)
    }
    
    class Coordinator: NSObject {
        var playbackCompleted: (() -> Void)?
        weak var imageView: UIImageView?
        var currentFrame: Int = 0
        var isPaused: Bool = false
        var images: [UIImage]
        var timer: Timer?
        var completionTimer: Timer?
        var frameMonitorTimer: Timer? // 用于监控帧变化
        var animationKey: String? // 动画的唯一标识符
        
        init(images: [UIImage], animationKey: String? = nil) {
            self.images = images
            self.animationKey = animationKey
            super.init()
        }
        
        @objc func animationDidFinish() {
            DispatchQueue.main.async { [weak self] in
                print("动画播放完成，触发回调")
                self?.playbackCompleted?()
            }
        }
        
        // 为循环动画设置帧监控器
        func setupFrameMonitor(fps: Double, frameCount: Int) {
            // 清理之前的定时器
            frameMonitorTimer?.invalidate()
            frameMonitorTimer = nil
            
            guard frameCount > 0, let animationKey = animationKey else { return }
            
            // 计算每帧持续时间
            let frameDuration = 1.0 / fps
            
            // 创建定时器监控帧变化
            frameMonitorTimer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak self] _ in
                guard let self = self, let imageView = self.imageView, imageView.isAnimating, !self.isPaused else { return }
                
                // 计算当前帧索引
                self.currentFrame = (self.currentFrame + 1) % frameCount
                
                // 获取当前帧的名称（如果可用）
                if self.currentFrame < self.images.count {
                    // 尝试从图像获取名称
                    let frameIndex = self.currentFrame
                    // 发送帧变化通知
                    self.notifyFrameChange(frameIndex: frameIndex, animationKey: animationKey)
                }
            }
            
            if let timer = frameMonitorTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
        
        // 通知帧变化
        private func notifyFrameChange(frameIndex: Int, animationKey: String) {
            // 获取帧名称
            var frameName = "unknown"
            
            // 从动画键中提取类别和名称
            let parts = animationKey.split(separator: ".")
            if parts.count == 2 {
                let category = String(parts[0])
                let name = String(parts[1])
                
                // 根据类别和帧索引构造可能的帧名称
                if category == "hero" && name == "attack" {
                    frameName = "hero_attack_\(frameIndex + 1)"
                } else if category == "hammer" && name == "attack" {
                    frameName = "hammer_attack_\(frameIndex + 1)"
                }
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("AnimationFrameChanged"),
                object: nil,
                userInfo: [
                    "frameIndex": frameIndex,
                    "frameName": frameName,
                    "animationKey": animationKey
                ]
            )
        }
        
        // 为非循环动画设置完成计时器
        func setupAnimationCompletionTimer(duration: TimeInterval) {
            // 清理之前的定时器
            completionTimer?.invalidate()
            
            // 创建新的定时器，时间稍微长于动画时间，确保动画完成
            completionTimer = Timer.scheduledTimer(withTimeInterval: duration + 0.1, repeats: false) { [weak self] _ in
                guard let self = self, let imageView = self.imageView, !imageView.isAnimating, !self.isPaused else { return }
                
                // 动画已经停止且不是因为暂停，触发完成回调
                print("非循环动画计时器触发，动画播放完成")
                DispatchQueue.main.async {
                    self.animationDidFinish()
                }
            }
            
            if let timer = completionTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
        
        @objc func pauseAnimation() {
            guard let imageView = imageView, imageView.isAnimating else { return }
            
            // 暂停定时器
            completionTimer?.invalidate()
            completionTimer = nil
            frameMonitorTimer?.invalidate()
            frameMonitorTimer = nil
            
            // 保存当前帧索引 - 通过随机选择帧停止
            currentFrame = Int.random(in: 0..<(images.count))
            
            // 停止动画
            imageView.stopAnimating()
            
            // 显示随机帧
            if !images.isEmpty && currentFrame < images.count {
                imageView.image = images[currentFrame]
            }
            
            isPaused = true
        }
        
        @objc func resumeAnimation() {
            guard let imageView = imageView, !imageView.isAnimating, isPaused else { return }
            
            // 重新启动动画
            imageView.startAnimating()
            
            // 重新启动帧监控
            if let _ = animationKey, images.count > 0 {
                let fps = Double(images.count) / (imageView.animationDuration > 0 ? imageView.animationDuration : 1.0)
                setupFrameMonitor(fps: fps, frameCount: images.count)
            }
            
            isPaused = false
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            timer?.invalidate()
            timer = nil
            completionTimer?.invalidate()
            completionTimer = nil
            frameMonitorTimer?.invalidate()
            frameMonitorTimer = nil
        }
    }
    
    static func == (lhs: HighQualityAnimatedImageView, rhs: HighQualityAnimatedImageView) -> Bool {
        lhs.images.count == rhs.images.count && lhs.fps == rhs.fps && lhs.isLooping == rhs.isLooping
    }
}

// 添加UIImageView动画完成通知
extension NSNotification.Name {
    static let UIImageViewAnimationDidFinish = NSNotification.Name("UIImageViewAnimationDidFinish")
}

struct MainView: View {
    @StateObject private var userDataManager = UserDataManager.shared
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var backgroundTimerManager = BackgroundTimerManager.shared
    // 初始化AttackSoundManager
    private let attackSoundManager = AttackSoundManager.shared
    @State private var isWorkMode = true
    @State private var remainingSeconds: Int = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer? = nil
    @State private var initialWorkSeconds: Int = 0
    
    // 英雄动画相关状态
    @State private var isHeroEntryCompleted = false // 跟踪入场动画是否完成
    @State private var entryAnimationTimer: Timer? = nil // 用于计时入场动画结束
    
    // 记录开始时间和上次更新时间，用于防止时间修改
    @State private var lastTickDate: Date = Date()
    
    // 场景切换效果相关状态
    @State private var isShowingTransition = true // 初始状态设为true，一开始就显示黑屏
    @State private var isFirstAppear = true // 跟踪是否是首次出现
    
    @State private var showSettings = false
    @State private var showPauseDialog = false  // 控制暂停弹窗的显示
    @State private var showShop = false  // 控制商店弹窗的显示
    @State private var showGiftPackage = false  // 控制礼包弹窗的显示
    @State private var showStartFocus = true  // 控制 StartFocus 视图的显示
    @State private var showPermissionAlert = false  // 控制权限提示弹窗的显示
    
    // 穿帮防护
    @State private var contentLoaded = false // 内容是否已加载完成
    
    // 暂停状态相关
    @State private var isPaused = false // 跟踪是否暂停状态
    @State private var pausedAnimationFrames: [String: Int] = [:] // 储存暂停时的动画帧
    
    // 倒计时区域控制变量
    @State private var timerOffsetX: CGFloat = 0
    @State private var timerOffsetY: CGFloat = 0
    @State private var timerScale: CGFloat = 1.0
    
    // Boss血条相关状态
    @State private var bossHealthProgress: Double = 0.0
    
    // 添加震动生成器
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    // 添加触觉引擎生成器，用于轻量级触觉反馈
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // 增加状态属性
    @State private var showVictoryView = false
    @State private var victoryCoinsEarned = 0
    
    // 添加金币区域点击计数
    @State private var coinClickCount: Int = 0
    // 添加秘密手势已使用标记
    @State private var secretGestureUsed: Bool = false
    
    var body: some View {
        ZStack {
            // 背景
            background
            
            if contentLoaded {
                VStack(spacing: 0) {
                    // 顶部信息栏和计时器区域
                    ZStack {
                        // 金币余额 - 放在左侧
                        HStack {
                            HStack(spacing: 2) {
                                Image("coin")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: DeviceHelper.shared.adjustedSize(baseSize: 20), height: DeviceHelper.shared.adjustedSize(baseSize: 20))
                                Text("\(userDataManager.userProfile.coins)")
                                    .foregroundColor(.black)
                                    .fontWeight(.bold)
                                    .adaptiveFont(size: 16)
                            }
                            .padding(.horizontal, DeviceHelper.shared.adjustedSize(baseSize: 10))
                            .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 5))
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(15)
                            // 添加点击手势以启用秘密金币增加功能
                            .onTapGesture {
                                // 每次点击增加计数
                                handleCoinAreaTap()
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, DeviceHelper.shared.contentPadding)
                        
                        // 设置按钮 - 放在右侧
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                audioManager.playSound("click")
                                showSettings = true
                            }) {
                                Image("settings")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: DeviceHelper.shared.adjustedSize(baseSize: 40), height: DeviceHelper.shared.adjustedSize(baseSize: 40))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, DeviceHelper.shared.contentPadding)
                        
                        // 计时器显示 - 完全独立，不受其他元素影响
                        Text(formatTime(seconds: remainingSeconds))
                            .adaptiveFont(size: 24, weight: .bold)
                            .foregroundColor(.white)
                            .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 5))
                            .padding(.horizontal, DeviceHelper.shared.adjustedSize(baseSize: 12))
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .offset(x: timerOffsetX, y: timerOffsetY)
                            .scaleEffect(timerScale)
                            // 添加点击手势，使点击倒计时区域也能触发暂停弹窗
                            .onTapGesture {
                                // 触发轻微的触觉反馈
                                impactFeedback.impactOccurred()
                                
                                showPauseDialog = true
                                pauseAll() // 暂停所有状态
                            }
                    }
                    .adaptiveTopSafeArea()
                    
                    // 顶部右侧的礼包按钮 - 只在休息模式下显示
                    if !isWorkMode {
                        HStack {
                            Spacer()
                            Button(action: {
                                audioManager.playSound("click")
                                showGiftPackage = true
                            }) {
                                Image("gift")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: DeviceHelper.shared.adjustedSize(baseSize: 40), height: DeviceHelper.shared.adjustedSize(baseSize: 40))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, DeviceHelper.shared.contentPadding)
                        .padding(.top, DeviceHelper.shared.adjustedSize(baseSize: 10)) // 调小间距
                    }
                    
                    // 状态和奖励显示 - 移到上方
                    HStack(spacing: DeviceHelper.shared.adjustedSize(baseSize: 20)) {
                        // 状态文本
                        Text(isWorkMode ? "Hero is focusing..." : "Enjoy your rest time...")
                            .foregroundColor(.white)
                            .adaptiveFont(size: 14)
                            .padding(.horizontal, DeviceHelper.shared.adjustedSize(baseSize: 12))
                            .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 4))
                            .background(
                                Image("banner")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: DeviceHelper.shared.adjustedSize(baseSize: 30))
                            )
                            .cornerRadius(6)
                            .offset(x: isWorkMode ? 0 : 8, y: isWorkMode ? 0 : -10) // 调整休息模式下的偏移
                        
                        // 金币奖励预览（仅工作模式显示）
                        if isWorkMode {
                            HStack {
                                Text("You will get:")
                                    .foregroundColor(.black)
                                    .adaptiveFont(size: 14)
                                Image("coin")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: DeviceHelper.shared.adjustedSize(baseSize: 16), height: DeviceHelper.shared.adjustedSize(baseSize: 16))
                                Text("\(previewCoinsReward())")
                                    .foregroundColor(.black)
                                    .adaptiveFont(size: 14, weight: .bold)
                            }
                            .padding(.horizontal, DeviceHelper.shared.adjustedSize(baseSize: 12))
                            .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 4))
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.top, DeviceHelper.shared.adjustedSize(baseSize: 5))
                    
                    // 使用自适应垂直间距
                    Spacer(minLength: DeviceHelper.shared.adaptiveVerticalSpacing)
                    
                    // 英雄动画 - 使用自适应高度
                    heroView
                        .frame(height: DeviceHelper.shared.heroAreaHeight)
                    
                    // 使用自适应底部间距
                    Spacer(minLength: DeviceHelper.shared.bottomButtonsSpacing)
                    
                    // 底部按钮区域 - 确保在所有设备上都能看到
                    bottomButtons
                        .adaptiveBottomSafeArea() // 使用新增的自适应方法
                }
                // 应用整体UI缩放
                .adaptiveScaling()
            }
            
            // 黑屏过渡层
            Color.black
                .edgesIgnoringSafeArea(.all)
                .opacity(isShowingTransition ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.1), value: isShowingTransition)
            
            // 暂停弹窗
            if showPauseDialog {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showPauseDialog = false
                        resumeAll() // 点击空白处恢复
                    }
                
                VStack(spacing: DeviceHelper.shared.adjustedSize(baseSize: 20)) {
                    Text("What do you want to do?")
                        .adaptiveFont(size: 18, weight: .semibold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: DeviceHelper.shared.adjustedSize(baseSize: 20)) {
                        Button(action: {
                            showPauseDialog = false
                            resumeAll() // 点击Back按钮恢复
                        }) {
                            Text("Back")
                                .foregroundColor(.white)
                                .adaptiveFont(size: 16)
                                .padding(.horizontal, DeviceHelper.shared.adjustedSize(baseSize: 30))
                                .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 10))
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showPauseDialog = false
                            resumeAll() // 恢复所有状态
                            skipTimer() // 然后跳过当前计时
                        }) {
                            Text("Skip")
                                .foregroundColor(.white)
                                .adaptiveFont(size: 16)
                                .padding(.horizontal, DeviceHelper.shared.adjustedSize(baseSize: 30))
                                .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 10))
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(DeviceHelper.shared.adjustedSize(baseSize: 30))
                .background(Color.black.opacity(0.8))
                .cornerRadius(15)
                .transition(.scale)
                .adaptiveMaxWidth() // 确保使用我们改进的adaptiveMaxWidth方法
                .frame(width: DeviceHelper.shared.deviceType == .iPhone ? 300 : 350) // 适配不同设备
            }
        }
        .edgesIgnoringSafeArea(.bottom)  // 忽略底部安全区域，让内容延伸到屏幕底部
        .onAppear {
            print("MainView 出现")
            
            // 打印设备信息，帮助调试适配问题
            DeviceHelper.shared.printDeviceInfo()
            
            // 从UserDefaults加载秘密手势使用状态
            secretGestureUsed = UserDefaults.standard.bool(forKey: "secretGestureUsed")
            
            // 验证礼包商品状态
            ShopManager.shared.verifyAndFixGiftPackageItems()
            
            // 通知AttackSoundManager当前在MainView
            notifyViewState(viewName: "MainView")
            
            // 初始化AttackSoundManager以监听攻击帧
            _ = AttackSoundManager.shared
            
            // 根据设备类型设置倒计时位置和缩放
            let timerPos = DeviceHelper.shared.timerPosition
            setTimerPosition(x: timerPos.x, y: timerPos.y)
            setTimerScale(DeviceHelper.shared.timerScale)
            
            // 初始化入场动画状态 - 如果已装备effect_3，避免显示入场动画
            if isWorkMode && isEffect3Equipped() {
                // 已装备hammer girl，直接设置入场完成状态为true，跳过入场动画
                isHeroEntryCompleted = true
                // 通知AttackSoundManager英雄入场动画已完成
                notifyHeroEntryState(completed: true)
                print("检测到已装备hammer girl，跳过入场动画直接显示攻击动画")
                
                // 强制加载hammer girl动画
                AnimationManager.shared.safeReloadAnimation(for: "hammer.run")
                AnimationManager.shared.safeReloadAnimation(for: "hammer.attack")
            } else {
                isHeroEntryCompleted = false
                
                // 确保英雄动画已加载
                if isWorkMode {
                    AnimationManager.shared.safeReloadAnimation(for: "hero.run")
                    AnimationManager.shared.safeReloadAnimation(for: "hero.attack")
                }
            }
            
            // 监听effect_3状态变更通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("Effect3StatusChanged"),
                object: nil,
                queue: .main
            ) { _ in
                // 使用强制刷新View的方式来更新UI
                DispatchQueue.main.async {
                    // 这里只是触发视图刷新，不需要更改任何状态
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // 由于我们在opacity中使用了isEffect3Equipped()，
                        // 触发一次动画就会重新评估这个表达式，从而刷新UI
                        if self.isWorkMode {
                            // 触发短暂的动画，促使视图重新渲染
                            self.isHeroEntryCompleted = self.isHeroEntryCompleted
                        }
                    }
                }
            }
            
            // 监听effect_6状态变更通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("Effect6StatusChanged"),
                object: nil,
                queue: .main
            ) { _ in
                // 使用强制刷新View的方式来更新UI
                DispatchQueue.main.async {
                    // 触发视图刷新
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if self.isWorkMode {
                            // 触发短暂的动画，促使视图重新渲染
                            self.isHeroEntryCompleted = self.isHeroEntryCompleted
                        }
                    }
                    
                    // 强制加载cat动画
                    if ShopManager.shared.isItemEquipped(itemId: "effect_6") {
                        AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
                    }
                }
            }
            
            // 监听OpenGiftPackage通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenGiftPackage"),
                object: nil,
                queue: .main
            ) { _ in
                // 收到通知后打开礼包页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showGiftPackage = true
                }
            }
            
            // 监听ShopManager重新加载装备状态的通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShopManagerItemsReloaded"),
                object: nil,
                queue: .main
            ) { _ in
                // 强制刷新UI状态
                DispatchQueue.main.async {
                    print("MainView接收到ShopManagerItemsReloaded通知")
                    
                    // 强制更新AttackSoundManager中的sound_2装备状态
                    AttackSoundManager.shared.forceUpdateSound2Status()
                    
                    // 根据当前装备状态，强制加载对应动画
                    if self.isWorkMode {
                        // 检查是否已装备effect_3
                        if self.isEffect3Equipped() {
                            // 已装备effect_3，设置入场完成状态并加载hammer girl动画
                            self.isHeroEntryCompleted = true
                            self.notifyHeroEntryState(completed: true)
                            
                            // 强制加载hammer girl动画
                            AnimationManager.shared.safeReloadAnimation(for: "hammer.run")
                            AnimationManager.shared.safeReloadAnimation(for: "hammer.attack")
                            print("ShopManager重载后应用hammer girl状态")
                        } else {
                            // 没有装备effect_3，仍然使用原始英雄动画
                            AnimationManager.shared.safeReloadAnimation(for: "hero.run")
                            AnimationManager.shared.safeReloadAnimation(for: "hero.attack")
                        }
                        
                        // 检查是否已装备effect_6
                        if self.isEffect6Equipped() {
                            // 强制加载cat动画
                            AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
                            print("ShopManager重载后应用cat动画状态")
                        }
                        
                        // 检查是否已装备effect_1
                        if self.isEffect1Equipped() {
                            // 强制加载wizard动画
                            AnimationManager.shared.safeReloadAnimation(for: "effect.wizard_attack")
                            print("ShopManager重载后应用wizard动画状态")
                        }
                    }
                    
                    // 触发视图刷新
                    withAnimation(.easeInOut(duration: 0.1)) {
                        // 这个空动画会触发视图重新计算
                        self.timerScale = self.timerScale * 1.0001
                    }
                    
                    print("响应ShopManagerItemsReloaded通知: 更新UI和音效状态")
                }
            }
            
            // 主动触发初始装备状态加载 - 这是关键
            DispatchQueue.main.async {
                // 主动从Keychain加载装备状态
                ShopManager.shared.loadAndApplyEquippedItems()
                
                // 强制更新所有状态
                forceUpdateAllStates()
                
                // 检查和应用effect_3状态
                if self.isWorkMode && self.isEffect3Equipped() {
                    // 强制重新加载hammer girl动画
                    AnimationManager.shared.safeReloadAnimation(for: "hammer.run")
                    AnimationManager.shared.safeReloadAnimation(for: "hammer.attack")
                    
                    // 设置hammer girl状态立即生效
                    self.isHeroEntryCompleted = true
                    self.notifyHeroEntryState(completed: true)
                    
                    print("应用启动: 主动加载并应用hammer girl装备状态")
                    
                    // 发送通知让其他组件也知道
                    NotificationCenter.default.post(
                        name: NSNotification.Name("Effect3StatusChanged"),
                        object: nil,
                        userInfo: ["isEquipped": true]
                    )
                }
                
                // 同样检查并应用effect_6状态
                if self.isWorkMode && self.isEffect6Equipped() {
                    // 强制重新加载cat动画
                    AnimationManager.shared.safeReloadAnimation(for: "effect.cat")
                    
                    print("应用启动: 主动加载并应用cat装备状态")
                    
                    // 发送通知让其他组件也知道
                    NotificationCenter.default.post(
                        name: NSNotification.Name("Effect6StatusChanged"),
                        object: nil,
                        userInfo: ["isEquipped": true]
                    )
                }
                
                // 强制更新AttackSoundManager中的sound_2装备状态
                AttackSoundManager.shared.forceUpdateSound2Status()
            }
            
            // 延迟加载内容，防止穿帮
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 预加载所有动画资源，但保持黑屏
                if isWorkMode {
                    _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                    _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                    _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                    _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                    _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                    _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                    
                    // 如果装备了effect_3，预加载hammer girl动画
                    if isEffect3Equipped() {
                        _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                        _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                    }
                } else {
                    _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                    _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                    _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
                }
                
                // 设置内容已加载标记
                contentLoaded = true
                
                // 初始状态为显示 StartFocusView
                showStartFocus = true
            }
            
            // 添加计时器完成通知观察者
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("TimerCompleted"),
                object: nil,
                queue: .main
            ) { _ in
                // 计时器在后台完成，触发完成处理
                print("MainView: 收到计时器完成通知")
                self.timerCompleted()
            }
            
            // 添加工作时长更新通知观察者
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("WorkDurationUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                // 工作时长更新，如果当前是工作模式且计时器正在运行，则重置计时器
                print("MainView: 收到工作时长更新通知")
                self.handleWorkDurationUpdate(notification)
            }
            
            // 添加休息时长更新通知观察者
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RelaxDurationUpdated"),
                object: nil,
                queue: .main
            ) { notification in
                // 休息时长更新，如果当前是休息模式且计时器正在运行，则重置计时器
                print("MainView: 收到休息时长更新通知")
                self.handleRelaxDurationUpdate(notification)
            }
            
            // 检查后台权限
            checkBackgroundPermissions()
            
            // 检查计时器状态
            checkTimerStateOnAppear()
        }
        .edgesIgnoringSafeArea(.bottom)  // 忽略底部安全区域，让内容延伸到屏幕底部
        .onDisappear {
            // 离开页面时停止音乐
            audioManager.stopAllMusic()
            
            // 清理定时器
            entryAnimationTimer?.invalidate()
            entryAnimationTimer = nil
            
            // 移除通知监听者
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("Effect3StatusChanged"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("Effect6StatusChanged"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("OpenGiftPackage"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShopManagerItemsReloaded"), object: nil)
            
            // 通知AttackSoundManager已离开MainView
            notifyViewState(viewName: "OtherView")
            
            // 移除通知观察者
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TimerCompleted"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("WorkDurationUpdated"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RelaxDurationUpdated"), object: nil)
        }
        .alert("后台权限设置", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("稍后设置", role: .cancel) { }
        } message: {
            Text("为了确保计时器在后台正常运行，请在设置中开启\"后台应用刷新\"权限。\n\n设置路径：设置 → 通用 → 后台应用刷新 → Focus Buddy")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showShop) {
            ShopView()
        }
        .fullScreenCover(isPresented: $showGiftPackage) {
            GiftPackageView()
                .background(Color.clear)
                .edgesIgnoringSafeArea(.all)
        }
        .fullScreenCover(isPresented: $showStartFocus) {
            StartFocusView(
                focusCount: userDataManager.getFocusCount() + 1,
                onComplete: {
                    // 递增专注计数
                    userDataManager.incrementFocusCount()
                    
                    // 预先设置状态，避免后续动画闪烁
                    if isWorkMode {
                        // 确保入场动画状态正确 - 当已装备effect_3时，直接完成入场
                        if isEffect3Equipped() {
                            // 已装备hammer girl，直接设置入场完成状态为true，跳过入场动画
                            isHeroEntryCompleted = true
                            // 通知AttackSoundManager英雄入场动画已完成
                            notifyHeroEntryState(completed: true)
                            print("检测到已装备hammer girl，跳过入场动画直接显示攻击动画")
                        } else {
                            isHeroEntryCompleted = false
                            // 通知AttackSoundManager英雄入场动画未完成
                            notifyHeroEntryState(completed: false)
                        }
                        
                        // 直接预加载工作模式动画，不重置配置
                        _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                        _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                        _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                        
                        // 如果装备了effect_3，预加载hammer girl动画
                        if isEffect3Equipped() {
                            _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                            _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                        }
                    }
                    
                    // 延迟一点时间后关闭StartFocusView，让主视图内容先准备好
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // 确保音效播放功能被启用
                        audioManager.isSoundPlaybackEnabled = true
                        print("MainView: 确保音效播放功能已启用")
                        
                        // Start Focus 完成后的回调
                        showStartFocus = false
                    
                        // 初始化并启动计时器
                        setupTimer()
                        
                        // 启动背景音乐 - focus_start完成后恢复音乐播放
                        if isWorkMode {
                            audioManager.playWorkMusic()
                        } else {
                            audioManager.playRelaxMusic()
                        }
                        
                        // 处理动画逻辑
                        if isWorkMode {
                            // 延迟启动入场动画定时器，确保渲染已就绪
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                // 启动入场动画定时器
                                startEntryAnimationBackupTimer()
                                
                                // 淡出黑屏 - 延迟执行以避免闪烁
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isShowingTransition = false
                                    }
                                }
                            }
                        } else {
                            // 预加载休息模式动画
                            _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                            _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                            _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
                            
                            // 淡出黑屏
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isShowingTransition = false
                            }
                        }
                    }
                }
            )
        }
        // 添加胜利界面的 sheet 视图
        .fullScreenCover(isPresented: $showVictoryView) {
            VictoryView(coinsEarned: victoryCoinsEarned) {
                // 胜利界面完成后的回调
                showVictoryView = false
                
                // 切换到休息模式
                isWorkMode = false
                remainingSeconds = userDataManager.getRelaxDuration() * 60
                
                // 停止所有商店音效（尤其是闪电音效）
                AudioManager.shared.stopAllShopSounds()
                
                // 发送工作模式变更通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkModeChanged"),
                    object: nil,
                    userInfo: ["isWorkMode": false]
                )
                
                // 切换背景音乐到休息模式
                audioManager.playRelaxMusic()
                
                // 预加载休息场景中的动画
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
                
                // 短暂延迟后淡出黑屏，显示新场景
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isShowingTransition = false
                    }
                    
                    // 黑屏消失后启动计时器
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        // 重新设置计时器
                        setupTimer()
                    }
                }
            }
        }
        .onChange(of: isWorkMode) { newValue in
            if newValue {
                if isEffect3Equipped() {
                    // 已装备hammer girl，直接设置入场完成状态为true，跳过入场动画
                    isHeroEntryCompleted = true
                    // 通知AttackSoundManager英雄入场动画已完成
                    notifyHeroEntryState(completed: true)
                    print("检测到场景切换时已装备hammer girl，跳过入场动画直接显示攻击动画")
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isHeroEntryCompleted = false
                        // 通知AttackSoundManager英雄入场动画未完成
                        notifyHeroEntryState(completed: false)
                    }
                }
                entryAnimationTimer?.invalidate()
                entryAnimationTimer = nil
                
                // 直接预加载所需动画
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                
                // 如果装备了effect_3，预加载hammer girl动画
                if isEffect3Equipped() {
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                }
            } else {
                // 切换到休息模式，停止所有商店音效，尤其是闪电音效
                AudioManager.shared.stopAllShopSounds()
                
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
            }
        }
    }
    
    var background: some View {
        ZStack {
            if isWorkMode {
                // 工作模式背景：检查是否装备了bg_1，如果装备了则使用bg3.png，否则使用默认的bg2
                if isBg1Equipped() {
                    // 使用新的bg3背景图片
                    if let _ = UIImage(named: "bg3") {
                        Image("bg3")
                            .resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(0.9)
                    } else {
                        // 如果bg3图片不存在，使用默认bg2
                        Image("bg2")
                            .resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(0.9)
                    }
                } else {
                    // 没有装备bg_1时使用默认的bg2图片
                    if let _ = UIImage(named: "bg2") {
                        Image("bg2")
                            .resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(0.9)
                    } else {
                        // 如果bg2图片不存在，使用原来的深色背景作为备用
                        Color(red: 0.1, green: 0.1, blue: 0.2)
                            .edgesIgnoringSafeArea(.all)
                    }
                }
            } else {
                // 休息模式背景：检查是否装备了bg_2，如果装备了则使用bg4.png，否则使用默认的bg1
                if isBg2Equipped() {
                    // 使用新的bg4背景图片
                    if let _ = UIImage(named: "bg4") {
                        Image("bg4")
                            .resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(0.8)
                    } else {
                        // 如果bg4图片不存在，使用默认bg1
                        Image("bg1")
                            .resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(0.8)
                    }
                } else {
                    // 没有装备bg_2时使用默认的bg1图片
                    if let _ = UIImage(named: "bg1") {
                        Image("bg1")
                            .resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .opacity(0.8)
                    } else {
                        // 如果bg1图片不存在，使用渐变色作为替代
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.6, blue: 0.4),
                                Color(red: 0.4, green: 0.7, blue: 0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .edgesIgnoringSafeArea(.all)
                    }
                }
            }
        }
    }
    
    var heroView: some View {
        ZStack {
            let workSpacing = AnimationManager.shared.getSceneConfig(for: "work")?.name_label.spacing ?? 0
            let relaxSpacing = AnimationManager.shared.getSceneConfig(for: "relax")?.name_label.spacing ?? 0
            let spacing = isWorkMode ? workSpacing : relaxSpacing
            
            VStack(spacing: spacing) {
                ZStack {
                    if isWorkMode {
                        ZStack {
                            // Boss动画
                            VStack(spacing: 5) {
                                // 添加Boss血条
                                BossHealthBar(
                                    progress: calculateBossHealthProgress(),
                                    isVisible: isHeroEntryCompleted && isEffect4Equipped()
                                )
                                .offset(x: 180, y: -60) // 向右180像素，向上60像素，对齐Boss头部上方
                                
                                ConfigurableAnimatedView(animationKey: "boss.idle")
                                    .opacity(isHeroEntryCompleted ? 1.0 : 0.0)
                                    .animation(.easeIn(duration: 0.2), value: isHeroEntryCompleted)
                            }
                            
                            // 闪电特效 - 当装备了effect_2时显示，放在boss之上
                            if isWorkMode && isHeroEntryCompleted {
                                IntervalAnimatedView(animationKey: "effect.lightning", interval: 5.0)
                                    .opacity(isEffect2Equipped() ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 0.3), value: isEffect2Equipped())
                                    .onAppear {
                                        // 预加载lightning动画
                                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                                    }
                            }
                            
                            // 特效动画 - 当装备了effect_1或effect_6时显示法师或猫咪动画
                            // 把特效放在英雄动画之前，让英雄显示在特效上面
                            if isWorkMode && isHeroEntryCompleted {
                                ZStack {
                                    // wizard动画 - 当装备了effect_1时显示
                                    let isWizardVisible = isEffect1Equipped()
                                    ConfigurableAnimatedView(animationKey: "effect.wizard_attack")
                                        .opacity(isWizardVisible ? 1.0 : 0.0)
                                        .animation(.easeInOut(duration: 0.3), value: isWizardVisible)
                                        .onAppear {
                                            // 预加载wizard_attack动画
                                            _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                                        }
                                    
                                    // cat动画 - 当装备了effect_6时显示
                                    let isCatVisible = isEffect6Equipped()
                                    ConfigurableAnimatedView(animationKey: "effect.cat")
                                        .opacity(isCatVisible ? 1.0 : 0.0)
                                        .animation(.easeInOut(duration: 0.3), value: isCatVisible)
                                        .onAppear {
                                            // 预加载cat动画
                                            _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                                        }
                                }
                            }
                            
                            // 入场动画 - 当装备effect_3时显示hammer girl，否则显示普通hero
                            Group {
                                // 普通英雄入场动画
                                ConfigurableAnimatedView(animationKey: "hero.run") { 
                                    print("普通英雄行走动画完成回调触发")
                                    DispatchQueue.main.async {
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            print("入场动画完成，切换到攻击动画")
                                            isHeroEntryCompleted = true
                                            // 通知AttackSoundManager英雄入场动画已完成
                                            notifyHeroEntryState(completed: true)
                                            entryAnimationTimer?.invalidate()
                                            entryAnimationTimer = nil
                                        }
                                    }
                                }
                                .opacity(isHeroEntryCompleted || isEffect3Equipped() ? 0.0 : 1.0)
                                
                                // hammer girl入场动画（当装备effect_3时显示）
                                ConfigurableAnimatedView(animationKey: "hammer.run") { 
                                    print("Hammer girl行走动画完成回调触发")
                                    DispatchQueue.main.async {
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            print("Hammer girl入场动画完成，切换到攻击动画")
                                            isHeroEntryCompleted = true
                                            // 通知AttackSoundManager英雄入场动画已完成
                                            notifyHeroEntryState(completed: true)
                                            entryAnimationTimer?.invalidate()
                                            entryAnimationTimer = nil
                                        }
                                    }
                                }
                                .opacity(!isHeroEntryCompleted && isEffect3Equipped() ? 1.0 : 0.0)
                                .onAppear {
                                    if isEffect3Equipped() {
                                        // 预加载hammer动画
                                        _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                                        _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                                    }
                                }
                            }
                            .onAppear {
                                startEntryAnimationBackupTimer()
                            }
                            
                            // 攻击动画 - 同样根据effect_3装备状态显示不同的攻击动画
                            Group {
                                // 普通英雄攻击动画
                                ConfigurableAnimatedView(animationKey: "hero.attack")
                                    .opacity(isHeroEntryCompleted && !isEffect3Equipped() ? 1.0 : 0.0)
                                    .animation(.easeIn(duration: 0.2), value: isHeroEntryCompleted)
                                
                                // hammer girl攻击动画
                                ConfigurableAnimatedView(animationKey: "hammer.attack")
                                    .opacity(isHeroEntryCompleted && isEffect3Equipped() ? 1.0 : 0.0)
                                    .animation(.easeIn(duration: 0.2), value: isHeroEntryCompleted)
                            }
                        }
                    } else {
                        // 休息模式区域 - 所有动画预加载
                        ZStack {
                            // 休息模式英雄动画 - 使用ConfigurableAnimatedView从配置加载
                            ConfigurableAnimatedView(animationKey: "hero.relax")
                            
                            // 火炉动画 - 使用ConfigurableAnimatedView从配置加载
                            ConfigurableAnimatedView(animationKey: "fireplace.burn")
                            
                            // 旅人动画 - 只有在装备了effect_5时才显示
                            if !isWorkMode {
                                ConfigurableAnimatedView(animationKey: "traveller.sit")
                                    .opacity(isEffect5Equipped() ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 0.3), value: isEffect5Equipped())
                                    .onAppear {
                                        // 预加载traveller动画
                                        _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
                                    }
                            }
                        }
                    }
                }
                
                // 英雄名字 - 可配置位置
                let workOffsetY = AnimationManager.shared.getSceneConfig(for: "work")?.name_label.offset_y ?? 0
                let relaxOffsetY = AnimationManager.shared.getSceneConfig(for: "relax")?.name_label.offset_y ?? 0
                let nameOffsetY = isWorkMode ? workOffsetY : relaxOffsetY
                
                Text(userDataManager.userProfile.catName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .offset(y: nameOffsetY)
            }
        }
        .padding(.horizontal)
        .offset(x: getHeroPositionX(), y: getHeroPositionY())
        .onChange(of: isWorkMode) { newValue in
            if newValue {
                if isEffect3Equipped() {
                    // 已装备hammer girl，直接设置入场完成状态为true，跳过入场动画
                    isHeroEntryCompleted = true
                    // 通知AttackSoundManager英雄入场动画已完成
                    notifyHeroEntryState(completed: true)
                    print("检测到场景切换时已装备hammer girl，跳过入场动画直接显示攻击动画")
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isHeroEntryCompleted = false
                        // 通知AttackSoundManager英雄入场动画未完成
                        notifyHeroEntryState(completed: false)
                    }
                }
                entryAnimationTimer?.invalidate()
                entryAnimationTimer = nil
                
                // 直接预加载所需动画
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                
                // 如果装备了effect_3，预加载hammer girl动画
                if isEffect3Equipped() {
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                }
            } else {
                // 切换到休息模式，停止所有商店音效，尤其是闪电音效
                AudioManager.shared.stopAllShopSounds()
                
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
            }
        }
    }
    
    // 创建备用入场动画定时器（以防动画回调失败）
    private func startEntryAnimationBackupTimer() {
        // 确保之前的定时器被取消
        entryAnimationTimer?.invalidate()
        
        // 根据effect_3装备状态选择不同的动画
        let animationKey = isEffect3Equipped() ? "hammer.run" : "hero.run"
        
        // 获取动画信息
        let animInfo = AnimationManager.shared.getAnimationInfo(for: animationKey)
        // 根据帧数和fps计算动画持续时间，只加一点缓冲
        let framesCount = Double(animInfo?.frames.count ?? 4)
        let fps = animInfo?.fps ?? 5.0
        let animationDuration = (framesCount / fps) + 0.1  // 只加0.1秒的缓冲，使过渡更紧凑
        
        print("设置备用定时器: \(animationDuration)秒后切换到攻击动画 (帧数: \(framesCount), FPS: \(fps))")
        
        // 创建新的定时器，在动画结束后切换到攻击动画
        entryAnimationTimer = Timer.scheduledTimer(withTimeInterval: animationDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                if !isHeroEntryCompleted {
                    // 使用动画使切换更平滑
                    withAnimation(.easeIn(duration: 0.15)) {  // 减少过渡动画时间
                        isHeroEntryCompleted = true
                        // 通知AttackSoundManager英雄入场动画已完成
                        notifyHeroEntryState(completed: true)
                        print("入场动画备用定时器触发，切换到攻击动画")
                    }
                }
            }
        }
        
        // 确保定时器在主RunLoop中运行
        if let timer = entryAnimationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // 检查是否装备了effect_2特效
    private func isEffect2Equipped() -> Bool {
        return ShopManager.shared.getEquippedItems(ofType: .effect)
            .contains(where: { $0.id == "effect_2" })
    }
    
    // 检查是否装备了effect_4特效
    private func isEffect4Equipped() -> Bool {
        return ShopManager.shared.getEquippedItems(ofType: .effect)
            .contains(where: { $0.id == "effect_4" })
    }
    
    // 检查是否装备了effect_5特效
    private func isEffect5Equipped() -> Bool {
        return ShopManager.shared.getEquippedItems(ofType: .effect)
            .contains(where: { $0.id == "effect_5" })
    }
    
    // 检查是否装备了effect_3特效
    private func isEffect3Equipped() -> Bool {
        // 先检查ShopManager的直接方法，这是最可靠的
        if ShopManager.shared.isItemEquipped(itemId: "effect_3") {
            return true
        }
        
        // 然后检查装备数组
        return ShopManager.shared.getEquippedItems(ofType: .effect)
            .contains(where: { $0.id == "effect_3" })
    }
    
    // 检查是否装备了effect_6特效
    private func isEffect6Equipped() -> Bool {
        // 先检查ShopManager的直接方法，这是最可靠的
        if ShopManager.shared.isItemEquipped(itemId: "effect_6") {
            return true
        }
        
        // 然后检查装备数组
        return ShopManager.shared.getEquippedItems(ofType: .effect)
            .contains(where: { $0.id == "effect_6" })
    }
    
    // 检查是否装备了effect_1特效
    private func isEffect1Equipped() -> Bool {
        return ShopManager.shared.getEquippedItems(ofType: .effect)
            .contains(where: { $0.id == "effect_1" })
    }
    
    // 检查是否装备了bg_1背景
    private func isBg1Equipped() -> Bool {
        return ShopManager.shared.getEquippedItems(ofType: .background)
            .contains(where: { $0.id == "bg_1" })
    }
    
    // 检查是否装备了bg_2背景
    private func isBg2Equipped() -> Bool {
        return ShopManager.shared.getEquippedItems(ofType: .background)
            .contains(where: { $0.id == "bg_2" })
    }
    
    var bottomButtons: some View {
        VStack(spacing: DeviceHelper.shared.adjustedSize(baseSize: 15)) {
            // 暂停按钮 - 放大并增强显示
            Button(action: { 
                showPauseDialog = true 
                pauseAll() // 暂停所有状态
            }) {
                HStack {
                    Image(systemName: "pause.fill")
                        .font(.system(size: DeviceHelper.shared.adjustedSize(baseSize: 18)))
                    Text("Pause")
                        .adaptiveFont(size: 16, weight: .medium)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 14))
                .background(
                    // 恢复原来的透明度设计
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .padding(.horizontal, DeviceHelper.shared.deviceType == .iPhone ? 32 : 60)
            
            // 工作/休息模式下不同的按钮
            if !isWorkMode {
                HStack(spacing: DeviceHelper.shared.adjustedSize(baseSize: 15)) {
                    // 邮件按钮
                    Button(action: { 
                        sendEmail()
                    }) {
                        VStack(spacing: DeviceHelper.shared.adjustedSize(baseSize: 5)) {
                            Image("mail")
                                .resizable()
                                .scaledToFit()
                                .frame(width: DeviceHelper.shared.adjustedSize(baseSize: 30), height: DeviceHelper.shared.adjustedSize(baseSize: 30))
                            Text("Contact us")
                                .adaptiveFont(size: 15)
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 14))
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    
                    // 商店按钮
                    Button(action: { showShop = true }) {
                        VStack(spacing: DeviceHelper.shared.adjustedSize(baseSize: 5)) {
                            Image("shop")
                                .resizable()
                                .scaledToFit()
                                .frame(width: DeviceHelper.shared.adjustedSize(baseSize: 30), height: DeviceHelper.shared.adjustedSize(baseSize: 30))
                            Text("shop")
                                .adaptiveFont(size: 15)
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, DeviceHelper.shared.adjustedSize(baseSize: 14))
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, DeviceHelper.shared.deviceType == .iPhone ? 32 : 60)
            }
        }
        .padding(.bottom, DeviceHelper.shared.deviceType == .iPad || DeviceHelper.shared.deviceType == .iPadPro ? 25 : 12)
        .adaptiveMaxWidth() // 使用改进的adaptiveMaxWidth方法
    }
    
    // 发送邮件
    private func sendEmail() {
        let email = "dxycj250@gmail.com"
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
    
    // 设置计时器
    func setupTimer() {
        if isWorkMode {
            remainingSeconds = userDataManager.getWorkDuration() * 60
            initialWorkSeconds = userDataManager.getWorkDuration() * 60
            // 更新初始血条状态
            updateBossHealthProgress()
        } else {
            remainingSeconds = userDataManager.getRelaxDuration() * 60
        }
        
        // 使用后台计时管理器启动计时器
        backgroundTimerManager.startTimer(workMode: isWorkMode, duration: remainingSeconds)
        
        // 同步状态
        isTimerRunning = backgroundTimerManager.isTimerRunning
        remainingSeconds = backgroundTimerManager.remainingSeconds
        
        // 启动UI更新定时器
        startUITimer()
        
        print("MainView: 计时器已启动 - 模式: \(isWorkMode ? "工作" : "休息"), 剩余时间: \(remainingSeconds)秒")
    }
    
    // 启动UI更新定时器
    func startUITimer() {
        // 确保之前的计时器已停止
        timer?.invalidate()
        
        // 创建UI更新定时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 更新后台计时管理器的实时状态
            self.backgroundTimerManager.updateTimerInRealTime()
            
            // 从后台计时管理器获取最新状态
            let status = self.backgroundTimerManager.getCurrentStatus()
            
            // 更新UI状态
            self.isTimerRunning = status.isRunning
            self.remainingSeconds = status.remainingSeconds
            
            // 打印调试信息
            print("MainView: UI更新 - 剩余时间: \(self.remainingSeconds)秒, 运行状态: \(self.isTimerRunning)")
            
            // 更新Boss血条进度
            if self.isWorkMode {
                self.updateBossHealthProgress()
            }
            
            // 检查计时是否完成
            if !status.isRunning && self.remainingSeconds <= 0 && self.isTimerRunning {
                print("MainView: UI检测到计时器完成")
                self.timer?.invalidate()
                self.timer = nil
                self.isTimerRunning = false
                self.timerCompleted()
            } else if self.remainingSeconds <= 0 && self.isTimerRunning {
                // 如果剩余时间为0但计时器还在运行，强制停止
                print("MainView: 强制停止计时器（剩余时间为0）")
                self.timer?.invalidate()
                self.timer = nil
                self.isTimerRunning = false
                self.backgroundTimerManager.stopTimer()
                self.timerCompleted()
            }
        }
        
        // 确保计时器在后台也能运行
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    // 计时器完成处理
    func timerCompleted() {
        print("MainView: 开始处理计时器完成")
        
        // 防止重复调用 - 但允许从后台恢复时的处理
        if !isTimerRunning && remainingSeconds > 0 {
            print("MainView: 计时器已完成且剩余时间大于0，跳过重复调用")
            return
        }
        
        // 确保计时器状态正确
        isTimerRunning = false
        remainingSeconds = 0
        
        // 触发震动
        feedbackGenerator.notificationOccurred(.success)
        
        if isWorkMode {
            // 从后台计时管理器获取状态
            let status = backgroundTimerManager.getCurrentStatus()
            
            // 计算实际工作了多少秒 - 如果剩余时间为0，使用初始时间
            let actualWorkSeconds = status.remainingSeconds <= 0 ? initialWorkSeconds : (initialWorkSeconds - status.remainingSeconds)
            
            // 工作模式完成，添加金币奖励 (每秒2个金币)
            let coinsEarned = calculateCoinsReward(actualWorkSeconds)
            userDataManager.addCoins(coinsEarned)
            
            // 保存获得的金币数量，用于胜利界面显示
            victoryCoinsEarned = coinsEarned
            
            // 开始场景切换：先显示黑屏
            withAnimation(.easeInOut(duration: 0.15)) {
                isShowingTransition = true
            }
            
            // 等待黑屏完全显示后，预加载胜利界面所需资源
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 预加载Boss倒地动画
                AnimationManager.shared.reloadAnimation(for: "boss.death")
                
                // 等待资源加载完成后显示胜利界面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 显示胜利界面
                    showVictoryView = true
                }
            }
        } else {
            // 开始场景切换：先显示黑屏
            withAnimation(.easeInOut(duration: 0.15)) {
                isShowingTransition = true
            }
            
            // 等待黑屏完全显示后，切换场景并准备后续操作
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 休息模式完成，切换回工作模式
                isWorkMode = true
                remainingSeconds = userDataManager.getWorkDuration() * 60
                initialWorkSeconds = userDataManager.getWorkDuration() * 60
                
                // 停止音乐
                audioManager.stopAllMusic()
                
                // 重置入场动画状态（StartFocusView完成后会自动启动入场动画定时器）
                isHeroEntryCompleted = false
                
                // 直接预加载动画，不重置配置
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                
                // 如果装备了effect_3，预加载hammer girl动画
                if isEffect3Equipped() {
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                }
                
                // 先显示 StartFocusView - 保持黑屏，在StartFocusView完成后再淡出
                showStartFocus = true
            }
        }
        
        // 清理计时器状态
        cleanupTimerState()
    }
    
    // 清理计时器状态
    private func cleanupTimerState() {
        // 停止所有计时器
        timer?.invalidate()
        timer = nil
        
        // 停止后台计时器
        backgroundTimerManager.stopTimer()
        
        // 清理UserDefaults中的状态
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "timer_is_running")
        defaults.removeObject(forKey: "timer_remaining_seconds")
        defaults.removeObject(forKey: "timer_is_work_mode")
        defaults.removeObject(forKey: "timer_start_date")
        defaults.removeObject(forKey: "timer_total_background_time")
        defaults.removeObject(forKey: "timer_last_save_time")
        
        print("MainView: 计时器状态已清理")
    }
    
    // 处理工作时长更新
    private func handleWorkDurationUpdate(_ notification: Notification) {
        guard let duration = notification.userInfo?["duration"] as? Int else { return }
        
        print("MainView: 处理工作时长更新 - 新时长: \(duration)分钟")
        
        // 如果当前是工作模式且计时器正在运行，则重置计时器
        if isWorkMode && isTimerRunning {
            print("MainView: 重置工作模式计时器")
            
            // 停止当前计时器
            timer?.invalidate()
            timer = nil
            backgroundTimerManager.stopTimer()
            
            // 更新剩余时间和初始时间
            remainingSeconds = duration * 60
            initialWorkSeconds = duration * 60
            
            // 更新Boss血条进度
            updateBossHealthProgress()
            
            // 重新启动计时器
            backgroundTimerManager.startTimer(workMode: isWorkMode, duration: remainingSeconds)
            startUITimer()
            
            print("MainView: 工作模式计时器已重置 - 新剩余时间: \(remainingSeconds)秒")
        }
    }
    
    // 处理休息时长更新
    private func handleRelaxDurationUpdate(_ notification: Notification) {
        guard let duration = notification.userInfo?["duration"] as? Int else { return }
        
        print("MainView: 处理休息时长更新 - 新时长: \(duration)分钟")
        
        // 如果当前是休息模式且计时器正在运行，则重置计时器
        if !isWorkMode && isTimerRunning {
            print("MainView: 重置休息模式计时器")
            
            // 停止当前计时器
            timer?.invalidate()
            timer = nil
            backgroundTimerManager.stopTimer()
            
            // 更新剩余时间
            remainingSeconds = duration * 60
            
            // 重新启动计时器
            backgroundTimerManager.startTimer(workMode: isWorkMode, duration: remainingSeconds)
            startUITimer()
            
            print("MainView: 休息模式计时器已重置 - 新剩余时间: \(remainingSeconds)秒")
        }
    }
    
    // 跳过当前计时，直接进入下一阶段
    func skipTimer() {
        // 触发震动
        feedbackGenerator.notificationOccurred(.warning)
        
        if isWorkMode {
            // 从后台计时管理器获取状态
            let status = backgroundTimerManager.getCurrentStatus()
            
            // 计算实际工作时间
            let actualWorkSeconds = initialWorkSeconds - status.remainingSeconds
            
            // 确保至少有1秒的工作时间，以免跳过导致没有奖励
            if actualWorkSeconds > 0 {
                let coinsEarned = calculateCoinsReward(actualWorkSeconds)
                userDataManager.addCoins(coinsEarned)
            }
        }
        
        // 停止后台计时器
        backgroundTimerManager.stopTimer()
        
        // 停止UI更新定时器
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        
        // 启动场景切换效果
        withAnimation(.easeInOut(duration: 0.1)) {
            isShowingTransition = true
        }
        
        // 等待黑屏显示后完成场景切换
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if isWorkMode {
                // 工作模式跳过，直接切换到休息模式，不显示胜利界面
                // 切换到休息模式
                isWorkMode = false
                remainingSeconds = userDataManager.getRelaxDuration() * 60
                
                // 停止所有商店音效（尤其是闪电音效）
                AudioManager.shared.stopAllShopSounds()
                
                // 发送工作模式变更通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkModeChanged"),
                    object: nil,
                    userInfo: ["isWorkMode": false]
                )
                
                // 切换背景音乐到休息模式
                audioManager.playRelaxMusic()
                
                // 预加载休息场景中的动画
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
                
                // 短暂延迟后淡出黑屏，显示新场景
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isShowingTransition = false
                    }
                    
                    // 黑屏消失后启动计时器
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        // 重新设置计时器
                        setupTimer()
                    }
                }
            } else {
                // 休息模式跳过，切换到工作模式
                isWorkMode = true
                remainingSeconds = userDataManager.getWorkDuration() * 60
                initialWorkSeconds = userDataManager.getWorkDuration() * 60
                
                // 停止音乐
                audioManager.stopAllMusic()
                
                // 重置入场动画状态
                isHeroEntryCompleted = false
                
                // 预加载工作模式动画
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.cat")
                
                // 如果装备了effect_3，预加载hammer girl动画
                if isEffect3Equipped() {
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                    _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                }
                
                // 先显示 StartFocusView - 保持黑屏，在StartFocusView完成后再淡出
                showStartFocus = true
                
                // 发送工作模式变更通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkModeChanged"),
                    object: nil,
                    userInfo: ["isWorkMode": true]
                )
                
                // 短暂延迟后淡出黑屏，显示新场景
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isShowingTransition = false
                    }
                    
                    // 黑屏消失后启动计时器
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        // 重新设置计时器
                        setupTimer()
                    }
                }
            }
        }
    }
    
    // 计算金币奖励
    func calculateCoinsReward(_ seconds: Int) -> Int {
        // 每秒获得2个金币
        return seconds * 2
    }
    
    // 预览即将获得的金币奖励
    func previewCoinsReward() -> Int {
        if isWorkMode {
            // 从后台计时管理器获取状态
            let status = backgroundTimerManager.getCurrentStatus()
            
            // 计算实际工作时间
            let actualWorkSeconds = initialWorkSeconds - status.remainingSeconds
            
            return calculateCoinsReward(actualWorkSeconds)
        } else {
            return 0
        }
    }
    
    // 暂停所有音频和动画
    private func pauseAll() {
        // 触发震动
        feedbackGenerator.notificationOccurred(.warning)
        
        isPaused = true
        
        // 1. 暂停计时器
        timer?.invalidate()
        timer = nil
        
        // 2. 暂停后台计时器
        backgroundTimerManager.pauseTimer()
        
        // 3. 暂停音乐和音效
        audioManager.pauseAllMusic()
        audioManager.pauseAllSounds()
        
        // 4. 暂停动画 - 通过截取当前帧实现
        pauseAnimations()
    }
    
    // 恢复所有音频和动画
    private func resumeAll() {
        if !isPaused { return }
        // 触发震动
        feedbackGenerator.notificationOccurred(.success)
        
        isPaused = false
        
        // 1. 恢复后台计时器
        backgroundTimerManager.resumeTimer()
        
        // 2. 恢复UI更新定时器
        startUITimer()
        
        // 3. 恢复音乐
        if isWorkMode {
            audioManager.resumeWorkMusic()
        } else {
            audioManager.resumeRelaxMusic()
        }
        
        // 4. 恢复动画
        resumeAnimations()
    }
    
    // 暂停动画 - 通过更新AnimationManager实现
    private func pauseAnimations() {
        // 通知每个动画视图暂停
        NotificationCenter.default.post(
            name: NSNotification.Name("PauseAnimations"),
            object: nil, 
            userInfo: nil
        )
    }
    
    // 恢复动画
    private func resumeAnimations() {
        // 通知每个动画视图恢复
        NotificationCenter.default.post(
            name: NSNotification.Name("ResumeAnimations"),
            object: nil, 
            userInfo: nil
        )
    }
    
    // 格式化时间
    func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    // 计算Boss血量进度
    func calculateBossHealthProgress() -> Double {
        if initialWorkSeconds <= 0 {
            return 0.0 // 防止除以零
        }
        
        let remainingPercentage = Double(remainingSeconds) / Double(initialWorkSeconds)
        return 1.0 - remainingPercentage // 从满到空
    }
    
    // 更新Boss血量进度状态 - 在计时器中调用
    func updateBossHealthProgress() {
        bossHealthProgress = calculateBossHealthProgress()
    }
    
    // 设置倒计时区域位置
    func setTimerPosition(x: CGFloat, y: CGFloat) {
        timerOffsetX = x
        timerOffsetY = y
    }
    
    // 设置倒计时区域缩放
    func setTimerScale(_ scale: CGFloat) {
        timerScale = scale
    }
    
    // 检查后台权限
    private func checkBackgroundPermissions() {
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        print("MainView: 检查后台权限状态: \(backgroundRefreshStatus.rawValue)")
        
        // 延迟检查，确保UI已经完全加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let currentStatus = UIApplication.shared.backgroundRefreshStatus
            print("MainView: 延迟检查后台权限状态: \(currentStatus.rawValue)")
            
            if currentStatus != .available {
                print("MainView: 后台权限不可用，显示权限提示")
                self.showPermissionAlert = true
            }
        }
    }
    
    // 检查计时器状态
    private func checkTimerStateOnAppear() {
        // 延迟检查，确保后台计时管理器已初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let status = self.backgroundTimerManager.getCurrentStatus()
            print("MainView: 检查计时器状态 - 运行: \(status.isRunning), 剩余时间: \(status.remainingSeconds)")
            
            // 如果计时器已完成但还在运行状态，强制触发完成处理
            if status.isRunning && status.remainingSeconds <= 0 {
                print("MainView: 检测到计时器已完成，触发完成处理")
                self.timerCompleted()
            }
        }
    }
    
    // 重置倒计时区域位置和大小
    func resetTimerPosition() {
        timerOffsetX = 0
        timerOffsetY = 0
        timerScale = 1
    }
    
    // 计算英雄位置X坐标
    private func getHeroPositionX() -> CGFloat {
        return isWorkMode ? 
            (AnimationManager.shared.getSceneConfig(for: "work")?.hero_position.x ?? -90) : 
            (AnimationManager.shared.getSceneConfig(for: "relax")?.hero_position.x ?? -90)
    }
    
    // 计算英雄位置Y坐标
    private func getHeroPositionY() -> CGFloat {
        return isWorkMode ? 
            (AnimationManager.shared.getSceneConfig(for: "work")?.hero_position.y ?? 50) : 
            (AnimationManager.shared.getSceneConfig(for: "relax")?.hero_position.y ?? 50)
    }
    
    // 通知视图状态变化
    private func notifyViewState(viewName: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("ViewStateChanged"),
            object: nil,
            userInfo: ["viewName": viewName]
        )
    }
    
    // 通知英雄入场动画状态
    private func notifyHeroEntryState(completed: Bool) {
        NotificationCenter.default.post(
            name: NSNotification.Name("HeroEntryAnimationCompleted"),
            object: nil,
            userInfo: ["completed": completed]
        )
    }
    
    // 处理金币区域点击
    private func handleCoinAreaTap() {
        // 检查秘密手势是否已被使用
        if secretGestureUsed {
            // 已经使用过了，只播放点击音效
            audioManager.playSound("click")
            return
        }
        
        // 递增点击计数
        coinClickCount += 1
        
        // 播放点击音效
        audioManager.playSound("click")
        
        // 检查是否达到8次点击
        if coinClickCount >= 8 {
            // 重置计数
            coinClickCount = 0
            
            // 标记秘密手势已使用
            secretGestureUsed = true
            
            // 将秘密手势使用状态保存到UserDefaults
            UserDefaults.standard.set(true, forKey: "secretGestureUsed")
            UserDefaults.standard.synchronize()
            
            // 增加99999金币
            userDataManager.addCoins(99999)
            
            // 播放特殊音效，表示触发了秘密功能
            audioManager.playSound("stinger")
            
            // 触发成功振动反馈
            feedbackGenerator.notificationOccurred(.success)
        }
    }
    
    // 强制更新所有状态
    private func forceUpdateAllStates() {
        // 强制更新AttackSoundManager中的sound_2装备状态
        AttackSoundManager.shared.forceUpdateSound2Status()
        
        // 检查是否已装备effect_3
        if isEffect3Equipped() {
            // 已装备effect_3，设置入场完成状态并加载hammer girl动画
            isHeroEntryCompleted = true
            notifyHeroEntryState(completed: true)
            
            // 强制加载hammer girl动画
            AnimationManager.shared.safeReloadAnimation(for: "hammer.run")
            AnimationManager.shared.safeReloadAnimation(for: "hammer.attack")
        }
        
        // 通知AttackSoundManager当前在MainView中
        NotificationCenter.default.post(
            name: NSNotification.Name("ViewStateChanged"),
            object: nil,
            userInfo: ["viewName": "MainView"]
        )
        
        // 通知AttackSoundManager英雄入场动画状态
        notifyHeroEntryState(completed: isHeroEntryCompleted)
    }
}

// 从Bundle加载图片的扩展
extension UIImage {
    static func loadFrom(fileName: String, fileExtension: String = "png") -> UIImage? {
        if let path = Bundle.main.path(forResource: fileName, ofType: fileExtension) {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}

#Preview {
    MainView()
} 
