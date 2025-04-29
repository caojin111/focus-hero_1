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
                NotificationCenter.default.removeObserver(context.coordinator, name: .UIImageViewAnimationDidFinish, object: nil)
                NotificationCenter.default.addObserver(
                    context.coordinator,
                    selector: #selector(Coordinator.animationDidFinish),
                    name: .UIImageViewAnimationDidFinish,
                    object: uiView
                )
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
        
        init(images: [UIImage]) {
            self.images = images
            super.init()
        }
        
        @objc func animationDidFinish() {
            DispatchQueue.main.async { [weak self] in
                self?.playbackCompleted?()
            }
        }
        
        @objc func pauseAnimation() {
            guard let imageView = imageView, imageView.isAnimating else { return }
            
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
    @State private var isShowingTransition = false // 控制黑屏淡入淡出
    @State private var isFirstAppear = true // 跟踪是否是首次出现
    
    @State private var showSettings = false
    @State private var showPauseDialog = false  // 控制暂停弹窗的显示
    @State private var showShop = false  // 控制商店弹窗的显示
    
    // 暂停状态相关
    @State private var isPaused = false // 跟踪是否暂停状态
    @State private var pausedAnimationFrames: [String: Int] = [:] // 储存暂停时的动画帧
    
    // 倒计时区域控制变量
    @State private var timerOffsetX: CGFloat = 0
    @State private var timerOffsetY: CGFloat = 0
    @State private var timerScale: CGFloat = 1.0
    
    // 添加震动生成器
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        ZStack {
            // 背景
            background
            
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
                    Text(isWorkMode ? "Hero is focus on work" : "Rest time......")
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
            setupTimer()
            // 初始化入场动画状态
            isHeroEntryCompleted = false
            
            // 启动背景音乐
            if isWorkMode {
                audioManager.playWorkMusic()
            } else {
                audioManager.playRelaxMusic()
            }
            
            // 如果是首次出现，显示黑屏过渡
            if isFirstAppear {
                // 开始时显示黑屏
                isShowingTransition = true
                
                // 短暂延迟后淡出黑屏
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isShowingTransition = false
                    }
                    isFirstAppear = false
                }
            }
            
            // 确保配置已加载
            AnimationManager.shared.reloadConfigurationAndRefresh()
            
            // 预加载所有动画以确保无缝衔接
            if isWorkMode {
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
            } else {
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
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
                            ConfigurableAnimatedView(animationKey: "boss.idle")
                                .opacity(isHeroEntryCompleted ? 1.0 : 0.0)
                                .animation(.easeIn(duration: 0.2), value: isHeroEntryCompleted)
                            
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
            } else {
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
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
                                .frame(width: 20, height: 20)
                            Text("Contact us")
                                .font(.caption)
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
                                .frame(width: 20, height: 20)
                            Text("shop")
                                .font(.caption)
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
            
            // 开始场景切换：先显示黑屏
            withAnimation(.easeInOut(duration: 0.15)) {
                isShowingTransition = true
            }
            
            // 等待黑屏完全显示后，切换场景并准备后续操作
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 切换到休息模式
                isWorkMode = false
                remainingSeconds = userDataManager.getRelaxDuration() * 60
                
                // 切换背景音乐到休息模式
                audioManager.playRelaxMusic()
                
                // 预加载休息场景中的动画
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.relax")
                _ = AnimationManager.shared.getAnimationInfo(for: "fireplace.burn")
                
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
                
                // 切换背景音乐到工作模式
                audioManager.playWorkMusic()
                
                // 重置入场动画状态
                isHeroEntryCompleted = false
                
                // 预加载工作场景中的动画
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                _ = AnimationManager.shared.getAnimationInfo(for: "boss.idle")
                
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
            // 调用计时器完成方法来处理后续逻辑
            timerCompleted()
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