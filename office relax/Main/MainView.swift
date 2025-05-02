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
    
    init(images: [UIImage], fps: Double, isLooping: Bool = true, playbackCompleted: (() -> Void)? = nil) {
        self.images = images
        self.fps = fps
        self.isLooping = isLooping
        self.playbackCompleted = playbackCompleted
    }
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // 保持比例
        imageView.clipsToBounds = false
        imageView.layer.magnificationFilter = .linear // 提高清晰度
        imageView.layer.shouldRasterize = false // 避免模糊
        context.coordinator.imageView = imageView
        
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
            
            // 开始动画
            uiView.startAnimating()
        } else {
            uiView.image = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(images: images)
    }
    
    class Coordinator: NSObject {
        var playbackCompleted: (() -> Void)?
        weak var imageView: UIImageView?
        var currentFrame: Int = 0
        var isPaused: Bool = false
        var images: [UIImage]
        var timer: Timer?
        var completionTimer: Timer?
        
        init(images: [UIImage]) {
            self.images = images
            super.init()
        }
        
        @objc func animationDidFinish() {
            DispatchQueue.main.async { [weak self] in
                print("动画播放完成，触发回调")
                self?.playbackCompleted?()
            }
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
            
            isPaused = false
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            timer?.invalidate()
            timer = nil
            completionTimer?.invalidate()
            completionTimer = nil
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
    @State private var isWorkMode = true
    @State private var remainingSeconds: Int = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer? = nil
    @State private var initialWorkSeconds: Int = 0
    
    // 英雄动画相关状态
    @State private var isHeroEntryCompleted = false // 跟踪入场动画是否完成
    @State private var entryAnimationTimer: Timer? = nil // 用于计时入场动画结束
    
    // 记录开始时间和上次更新时间，用于防止时间修改
    @State private var timerStartDate: Date = Date()
    @State private var lastTickDate: Date = Date()
    
    // 场景切换效果相关状态
    @State private var isShowingTransition = true // 初始状态设为true，一开始就显示黑屏
    @State private var isFirstAppear = true // 跟踪是否是首次出现
    
    @State private var showSettings = false
    @State private var showPauseDialog = false  // 控制暂停弹窗的显示
    @State private var showShop = false  // 控制商店弹窗的显示
    @State private var showStartFocus = true  // 控制 StartFocus 视图的显示
    
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
    
    // 增加状态属性
    @State private var showVictoryView = false
    @State private var victoryCoinsEarned = 0
    
    var body: some View {
        ZStack {
            // 背景
            background
            
            if contentLoaded {
                VStack(spacing: 0) {
                    // 顶部信息栏和计时器区域
                    HStack {
                        // 金币余额
                        HStack(spacing: 2) {
                            Image("coin")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("\(userDataManager.userProfile.coins)")
                                .foregroundColor(.black)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(15)
                        
                        Spacer()
                        
                        // 计时器显示 - 添加偏移和缩放控制
                        Text(formatTime(seconds: remainingSeconds))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                            .offset(x: timerOffsetX, y: timerOffsetY)
                            .scaleEffect(timerScale)
                        
                        Spacer()
                        
                        // 设置按钮
                        Button(action: {
                            audioManager.playSound("click")
                            showSettings = true
                        }) {
                            Image("settings")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 50)  // 增加顶部间距，避开状态栏
                    .padding(.horizontal)
                    
                    // 状态和奖励显示 - 移到上方
                    HStack(spacing: 20) {
                        // 状态文本
                        Text(isWorkMode ? "Hero is focus on work" : "Enjoy your rest time......")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Image("banner")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 30)
                            )
                            .cornerRadius(6)
                        
                        // 金币奖励预览（仅工作模式显示）
                        if isWorkMode {
                            HStack {
                                Text("You will get:")
                                    .foregroundColor(.black)
                                    .font(.subheadline)
                                Image("coin")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                Text("\(previewCoinsReward())")
                                    .foregroundColor(.black)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.top, 10)
                    
                    // 增加空间推动英雄到中央位置
                    Spacer(minLength: 100)
                    
                    // 英雄动画 - 增大尺寸
                    heroView
                        .frame(height: 280)  // 增加英雄区域高度
                    
                    // 增加空间推动底部按钮
                    Spacer(minLength: 40)  // 减少底部间距，补偿增大的英雄区域
                    
                    // 底部按钮区域
                    bottomButtons
                        .padding(.bottom, 40)
                }
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
                
                VStack(spacing: 20) {
                    Text("What do you want to do?")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            showPauseDialog = false
                            resumeAll() // 点击Back按钮恢复
                        }) {
                            Text("Back")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
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
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(30)
                .background(Color.black.opacity(0.8))
                .cornerRadius(15)
                .transition(.scale)
            }
        }
        .edgesIgnoringSafeArea(.bottom)  // 忽略底部安全区域，让内容延伸到屏幕底部
        .onAppear {
            setTimerPosition(x: -3, y: 50)  // 设置倒计时区域向右偏移100点，向下偏移50点
            setTimerScale(2.5)  // 设置倒计时区域缩放为1.5倍
            
            // 确保配置已加载
            AnimationManager.shared.reloadConfigurationAndRefresh()
            
            // 初始化入场动画状态
            isHeroEntryCompleted = false
            
            // 延迟加载内容，防止穿帮
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 预加载所有动画资源，但保持黑屏
                if isWorkMode {
                    _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                    _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                    _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                    _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                    _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
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
        }
        .onDisappear {
            // 离开页面时停止音乐
            audioManager.stopAllMusic()
            
            // 清理定时器
            entryAnimationTimer?.invalidate()
            entryAnimationTimer = nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showShop) {
            ShopView()
        }
        .fullScreenCover(isPresented: $showStartFocus) {
            StartFocusView(
                focusCount: userDataManager.getFocusCount() + 1,
                onComplete: {
                    // 递增专注计数
                    userDataManager.incrementFocusCount()
                    
                    // 预先设置状态，避免后续动画闪烁
                    if isWorkMode {
                        // 确保入场动画状态正确 - 重要修复
                        isHeroEntryCompleted = false
                        
                        // 预加载工作模式动画
                        _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                        _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                        _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                    }
                    
                    // 延迟一点时间后关闭StartFocusView，让主视图内容先准备好
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Start Focus 完成后的回调
                        showStartFocus = false
                    
                        // 初始化并启动计时器
                        setupTimer()
                        
                        // 启动背景音乐
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
                        startTimer()
                    }
                }
            }
        }
        .onChange(of: isWorkMode) { newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.2)) {
                    isHeroEntryCompleted = false
                }
                entryAnimationTimer?.invalidate()
                entryAnimationTimer = nil
                
                // 预加载所有动画
                AnimationManager.shared.reloadConfigurationAndRefresh()
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                
                // 发送工作模式变更通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkModeChanged"),
                    object: nil,
                    userInfo: ["isWorkMode": true]
                )
            } else {
                // 切换到休息模式，停止所有商店音效，尤其是闪电音效
                AudioManager.shared.stopAllShopSounds()
                
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                _ = AnimationManager.shared.getAnimationInfo(for: "traveller.sit")
                
                // 发送工作模式变更通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("WorkModeChanged"),
                    object: nil,
                    userInfo: ["isWorkMode": false]
                )
            }
        }
    }
    
    var background: some View {
        ZStack {
            if isWorkMode {
                // 工作模式背景：使用bg2图片
                if let _ = UIImage(named: "bg2") {
                    // 如果bg2图片存在，则使用它
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
            } else {
                // 休息模式背景：尝试加载bg1图片，如果失败则使用渐变色
                if let _ = UIImage(named: "bg1") {
                    // 如果bg1图片存在，则使用它
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
    
    var heroView: some View {
        ZStack {
            VStack(spacing: isWorkMode ? 
                  (AnimationManager.shared.getSceneConfig(for: "work")?.name_label.spacing ?? 0) : 
                  (AnimationManager.shared.getSceneConfig(for: "relax")?.name_label.spacing ?? 0)) {
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
                            
                            // 特效动画 - 当装备了effect_1时显示法师攻击效果
                            // 把特效放在英雄动画之前，让英雄显示在特效上面
                            if isWorkMode && isHeroEntryCompleted {
                                ConfigurableAnimatedView(animationKey: "effect.wizard_attack")
                                    .opacity(isEffectEquipped() ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 0.3), value: isEffectEquipped())
                                    .onAppear {
                                        // 预加载wizard_attack动画
                                        _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                                    }
                            }
                            
                            // 入场动画
                            ConfigurableAnimatedView(animationKey: "hero.run") { 
                                print("行走动画完成回调触发")
                                DispatchQueue.main.async {
                                    withAnimation(.easeIn(duration: 0.2)) {
                                        print("入场动画完成，切换到攻击动画")
                                        isHeroEntryCompleted = true
                                        entryAnimationTimer?.invalidate()
                                        entryAnimationTimer = nil
                                    }
                                }
                            }
                            .opacity(isHeroEntryCompleted ? 0.0 : 1.0)
                            .onAppear {
                                startEntryAnimationBackupTimer()
                            }
                            
                            // 攻击动画
                            ConfigurableAnimatedView(animationKey: "hero.attack")
                                .opacity(isHeroEntryCompleted ? 1.0 : 0.0)
                                .animation(.easeIn(duration: 0.2), value: isHeroEntryCompleted)
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
                Text(userDataManager.userProfile.catName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .offset(y: isWorkMode ? 
                          (AnimationManager.shared.getSceneConfig(for: "work")?.name_label.offset_y ?? 0) : 
                          (AnimationManager.shared.getSceneConfig(for: "relax")?.name_label.offset_y ?? 0))
            }
        }
        .padding(.horizontal)
        .offset(
            x: isWorkMode ? 
                (AnimationManager.shared.getSceneConfig(for: "work")?.hero_position.x ?? -90) : 
                (AnimationManager.shared.getSceneConfig(for: "relax")?.hero_position.x ?? -90),
            y: isWorkMode ? 
                (AnimationManager.shared.getSceneConfig(for: "work")?.hero_position.y ?? 50) : 
                (AnimationManager.shared.getSceneConfig(for: "relax")?.hero_position.y ?? 50)
        )
        .onChange(of: isWorkMode) { newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.2)) {
                    isHeroEntryCompleted = false
                }
                entryAnimationTimer?.invalidate()
                entryAnimationTimer = nil
                
                // 预加载所有动画
                AnimationManager.shared.reloadConfigurationAndRefresh()
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
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
        
        // 获取动画信息
        let animInfo = AnimationManager.shared.getAnimationInfo(for: "hero.run")
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
    
    // 检查是否装备了effect_1特效
    private func isEffectEquipped() -> Bool {
        return ShopManager.shared.getEquippedItems(ofType: .effect)
            .contains(where: { $0.id == "effect_1" })
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
    
    var bottomButtons: some View {
        VStack(spacing: 10) {
            // 暂停按钮（原Skip按钮）
            Button(action: { 
                showPauseDialog = true 
                pauseAll() // 暂停所有状态
            }) {
                HStack {
                    Image(systemName: "pause.fill")
                    Text("Pause")
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
            }
            .padding(.horizontal, 32)
            
            // 工作/休息模式下不同的按钮
            if !isWorkMode {
                HStack(spacing: 10) {
                    // 邮件按钮
                    Button(action: { 
                        sendEmail()
                    }) {
                        VStack(spacing: 3) {
                            Image("mail")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                            Text("Contact us")
                                .font(.system(size: 15))
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                    }
                    
                    // 商店按钮
                    Button(action: { showShop = true }) {
                        VStack(spacing: 3) {
                            Image("shop")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                            Text("shop")
                                .font(.system(size: 15))
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
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
        
        // 自动启动计时器
        startTimer()
    }
    
    // 启动计时器
    func startTimer() {
        // 确保之前的计时器已停止
        timer?.invalidate()
        
        // 记录计时器开始时间
        timerStartDate = Date()
        lastTickDate = timerStartDate
        
        // 创建新计时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 获取当前时间
            let currentDate = Date()
            
            // 计算两次计时器触发之间的实际时间差（秒）
            let timeDifference = currentDate.timeIntervalSince(self.lastTickDate)
            
            // 更新上次触发时间
            self.lastTickDate = currentDate
            
            // 检查时间差异是否合理（允许0.5秒的误差）
            if timeDifference < 0 || timeDifference > 1.5 {
                // 时间可能被修改，记录异常
                print("Time manipulation detected: \(timeDifference) seconds")
                
                // 可选：重置计时器或采取其他措施
                // self.resetTimer()
                
                // 最保守的做法：减去实际时间
                if remainingSeconds > 0 {
                    let decrementAmount = max(1, min(Int(timeDifference), 5))
                    remainingSeconds -= decrementAmount
                } else {
                    timerCompleted()
                    return
                }
            } else {
                // 正常减少一秒
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                    
                    // 更新Boss血条进度
                    if isWorkMode {
                        updateBossHealthProgress()
                    }
                } else {
                    // 计时结束
                    timer?.invalidate()
                    timer = nil
                    isTimerRunning = false
                    timerCompleted()
                }
            }
        }
        isTimerRunning = true
    }
    
    // 计时器完成处理
    func timerCompleted() {
        // 触发震动
        feedbackGenerator.notificationOccurred(.success)
        
        if isWorkMode {
            // 获取当前时间，计算自开始以来的总时间
            let currentDate = Date()
            let totalElapsedSeconds = Int(currentDate.timeIntervalSince(timerStartDate))
            
            // 计算实际工作了多少秒，使用初始剩余时间和计时器启动以来的真实经过时间作为上限
            let reportedWorkSeconds = initialWorkSeconds - remainingSeconds
            let actualWorkSeconds = min(reportedWorkSeconds, totalElapsedSeconds)
            
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
                
                // 预加载动画
                AnimationManager.shared.reloadConfigurationAndRefresh()
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.wizard_attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "effect.lightning")
                
                // 先显示 StartFocusView - 保持黑屏，在StartFocusView完成后再淡出
                showStartFocus = true
            }
        }
    }
    
    // 跳过当前计时，直接进入下一阶段
    func skipTimer() {
        // 触发震动
        feedbackGenerator.notificationOccurred(.warning)
        
        if isWorkMode {
            // 获取实际时间流逝
            let currentDate = Date()
            let totalElapsedSeconds = Int(currentDate.timeIntervalSince(timerStartDate))
            
            // 使用报告的工作时间和实际时间流逝的最小值
            let reportedWorkSeconds = initialWorkSeconds - remainingSeconds
            let actualWorkSeconds = min(reportedWorkSeconds, totalElapsedSeconds)
            
            // 确保至少有1秒的工作时间，以免跳过导致没有奖励
            if actualWorkSeconds > 0 {
                let coinsEarned = calculateCoinsReward(actualWorkSeconds)
                userDataManager.addCoins(coinsEarned)
            }
        }
        
        // 停止计时器
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
                        startTimer()
                    }
                }
            } else {
                // 休息模式跳过，调用原始方法处理
                timerCompleted()
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
            // 获取当前实际经过的时间（秒）
            let currentDate = Date()
            let totalElapsedSeconds = Int(currentDate.timeIntervalSince(timerStartDate))
            
            // 根据已工作时间计算，但以实际经过的时间为上限
            let reportedWorkSeconds = initialWorkSeconds - remainingSeconds
            let actualWorkSeconds = min(reportedWorkSeconds, totalElapsedSeconds)
            
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
        
        // 2. 暂停音乐和音效
        audioManager.pauseAllMusic()
        audioManager.pauseAllSounds()
        
        // 3. 暂停动画 - 通过截取当前帧实现
        pauseAnimations()
    }
    
    // 恢复所有音频和动画
    private func resumeAll() {
        if !isPaused { return }
        // 触发震动
        feedbackGenerator.notificationOccurred(.success)
        
        isPaused = false
        
        // 1. 恢复计时器
        startTimer()
        
        // 2. 恢复音乐
        if isWorkMode {
            audioManager.resumeWorkMusic()
        } else {
            audioManager.resumeRelaxMusic()
        }
        
        // 3. 恢复动画
        resumeAnimations()
    }
    
    // 暂停动画 - 通过更新AnimationManager实现
    private func pauseAnimations() {
        let animationKeys = isWorkMode ? 
            ["hero.attack", "boss.idle"] : 
            ["hero.relax", "fireplace.burn"]
        
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
    
    // 重置倒计时区域位置和大小
    func resetTimerPosition() {
        timerOffsetX = 0
        timerOffsetY = 0
        timerScale = 1
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