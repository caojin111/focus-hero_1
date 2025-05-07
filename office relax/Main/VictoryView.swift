//
//  VictoryView.swift
//  office relax
//
//  Created by LazyG on 2025/6/10.
//

import SwiftUI

struct VictoryView: View {
    @ObservedObject private var userDataManager = UserDataManager.shared
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var animationManager = AnimationManager.shared
    
    // 获得的金币
    private let coinsEarned: Int
    
    // 动画状态
    @State private var title1Opacity = 0.0
    @State private var title1Scale = 0.8
    @State private var title2Opacity = 0.0
    @State private var title2Scale = 0.8
    @State private var title3Opacity = 0.0
    @State private var title3Scale = 0.8
    @State private var coinsOpacity = 0.0
    @State private var coinsScale = 0.5
    @State private var bossOpacity = 0.0
    @State private var tipOpacity = 0.0
    @State private var tipFlash = false
    
    // 保存之前的音效播放状态
    @State private var previousSoundPlaybackState: Bool = true
    
    // 拖影效果相关状态
    @State private var trailEffectEnabled = false
    @State private var previousBossFrames: [UIImage?] = [nil, nil, nil]
    @State private var trailOpacities: [Double] = [0.1, 0.2, 0.3]
    @State private var animationFinished = false
    @State private var finalBossFrame: UIImage? = nil
    
    // 定时器引用
    @State private var flashingTimer: Timer? = nil
    @State private var trailEffectTimer: Timer? = nil
    
    // 点击关闭
    var onComplete: () -> Void
    
    init(coinsEarned: Int, onComplete: @escaping () -> Void) {
        self.coinsEarned = coinsEarned
        self.onComplete = onComplete
        
        // 预加载所需动画，但不重置整个配置
        // AnimationManager.shared.reloadConfigurationAndRefresh() - 注释掉
        
        // 只预加载可能需要的动画
        _ = AnimationManager.shared.getAnimationInfo(for: "effect.confetti")
        
        // 通知AttackSoundManager不在MainView
        NotificationCenter.default.post(
            name: NSNotification.Name("ViewStateChanged"),
            object: nil,
            userInfo: ["viewName": "VictoryView"]
        )
        
        // 通知系统在胜利界面 - 禁用闪电特效音效播放
        NotificationCenter.default.post(
            name: NSNotification.Name("WorkModeChanged"),
            object: nil,
            userInfo: ["isWorkMode": false]
        )
        
        // 特殊通知完全禁用闪电音效
        NotificationCenter.default.post(
            name: NSNotification.Name("DisableLightningEffects"),
            object: nil,
            userInfo: ["isDisabled": true]
        )
        
        // 强制停止已有的闪电音效
        DispatchQueue.main.async {
            AudioManager.shared.stopSound("shop_thunder")
        }
    }
    
    var body: some View {
        ZStack {
            // 背景 - 使用深色背景
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // 第一行 Victory! 文本
                Image("victory_1")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                    .opacity(title1Opacity)
                    .scaleEffect(title1Scale)
                    .padding(.top, 50)
                
                // 第二行 You defeated boss! 文本
                Image("victory_2")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                    .opacity(title2Opacity)
                    .scaleEffect(title2Scale)
                
                // 第三行 Earned xxx coins 文本
                ZStack {
                    // 底层"Earned coins"图片
                    Image("victory_3")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                    
                    // 金币数字，放在中间位置
                    Text("\(coinsEarned)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.6, blue: 0.2))
                        .opacity(coinsOpacity)
                        .scaleEffect(coinsScale)
                        .offset(x: 10, y: -3) // 向右偏移10像素，向上偏移3像素
                }
                .opacity(title3Opacity)
                .scaleEffect(title3Scale)
                
                Spacer(minLength: 40)
                
                // Boss倒地动画区域
                ZStack {
                    // 拖影效果 - 使用白色半透明效果
                    if trailEffectEnabled {
                        ForEach(0..<3) { i in
                            if let frameImage = previousBossFrames[i] {
                                Image(uiImage: frameImage)
                                    .resizable()
                                    .scaledToFit()
                                    .colorMultiply(.white) // 使拖影呈现白色
                                    .blur(radius: 2.0)
                                    .opacity(trailOpacities[i] * bossOpacity)
                                    .offset(x: CGFloat(i+1) * -3, y: CGFloat(i+1) * 3)
                            }
                        }
                    }
                    
                    // 如果动画已完成，显示最后一帧
                    if animationFinished, let finalFrame = finalBossFrame {
                        Image(uiImage: finalFrame)
                            .resizable()
                            .scaledToFit()
                            .opacity(bossOpacity)
                    }
                    // 否则显示动画
                    else {
                        // 使用ConfigurableAnimatedView加载Boss倒地动画
                        ConfigurableAnimatedView(animationKey: "boss.death") {
                            // 动画完成回调
                            handleAnimationCompleted()
                        }
                        .opacity(bossOpacity)
                    }
                }
                .frame(height: 150)
                
                Spacer()
                
                // 点击提示文本
                Text("Tap anywhere to rest")
                    .font(.system(size: 18))
                    .foregroundColor(tipFlash ? .white : .gray)
                    .opacity(tipOpacity)
                    .padding(.bottom, 50)
            }
            .padding()
        }
        .onAppear {
            // 保存当前音效播放状态
            previousSoundPlaybackState = AudioManager.shared.isSoundPlaybackEnabled
            
            // 临时禁用全局音效播放
            AudioManager.shared.isSoundPlaybackEnabled = false
            
            // 停止相关音效
            stopAllRelevantSounds()
            
            // 禁用AttackSoundManager的音效触发
            NotificationCenter.default.post(
                name: NSNotification.Name("ViewStateChanged"),
                object: nil,
                userInfo: ["viewName": "VictoryView"]
            )
            
            // 通知AttackSoundManager不完成英雄入场动画
            NotificationCenter.default.post(
                name: NSNotification.Name("HeroEntryAnimationCompleted"),
                object: nil,
                userInfo: ["completed": false]
            )
            
            // 临时设置为休息模式，禁用闪电动画的音效播放
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkModeChanged"),
                object: nil,
                userInfo: ["isWorkMode": false]
            )
            
            // 开始动画序列
            startAnimations()
            
            // 延迟0.5秒后再次停止所有音效，以防新的音效开始播放
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                stopAllRelevantSounds()
                AudioManager.shared.stopAllShopSounds()
            }
        }
        .onTapGesture {
            if tipOpacity > 0 {
                // 停止所有定时器
                stopAllTimers()
                
                // 停止所有相关音效
                stopAllRelevantSounds()
                
                // 临时启用全局音效，仅用于播放点击音效
                AudioManager.shared.isSoundPlaybackEnabled = true
                
                // 播放点击音效
                AudioManager.shared.playSound("click")
                
                // 调用完成回调前，通知系统重置
                DispatchQueue.main.async {
                    // 恢复之前的音效播放状态
                    AudioManager.shared.isSoundPlaybackEnabled = self.previousSoundPlaybackState
                    
                    // 通知AttackSoundManager状态即将切换回MainView
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ViewStateChanged"),
                        object: nil,
                        userInfo: ["viewName": "MainView"]
                    )
                    
                    // 通知系统恢复工作模式（如果需要）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("WorkModeChanged"),
                        object: nil,
                        userInfo: ["isWorkMode": true]
                    )
                    
                    // 重新启用闪电音效（如果需要）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DisableLightningEffects"),
                        object: nil,
                        userInfo: ["isDisabled": false]
                    )
                    
                    // 调用完成回调
                    self.onComplete()
                }
            }
        }
        .onDisappear {
            // 确保离开页面时停止所有定时器
            stopAllTimers()
            
            // 停止所有相关音效
            stopAllRelevantSounds()
            
            // 恢复之前的音效播放状态
            AudioManager.shared.isSoundPlaybackEnabled = previousSoundPlaybackState
        }
    }
    
    // 处理动画完成
    private func handleAnimationCompleted() {
        print("Boss倒地动画播放完成")
        animationFinished = true
        
        // 尝试加载最后一帧作为静止图像
        if let lastFrameImage = UIImage(named: "boss_death_5") {
            finalBossFrame = lastFrameImage
            print("成功加载最后一帧图像")
        } else {
            print("无法加载最后一帧图像")
        }
        
        // 停止拖影定时器
        trailEffectTimer?.invalidate()
        trailEffectTimer = nil
    }
    
    // 停止所有定时器的辅助方法
    private func stopAllTimers() {
        // 停止闪烁定时器
        flashingTimer?.invalidate()
        flashingTimer = nil
        
        // 停止拖影效果定时器
        trailEffectTimer?.invalidate()
        trailEffectTimer = nil
    }
    
    // 停止所有相关音效的辅助方法
    private func stopAllRelevantSounds() {
        // 停止攻击音效和闪电音效
        AudioManager.shared.stopSound("attack")
        AudioManager.shared.stopSound("shop_thunder")
        
        // 停止所有商店音效，确保没有残留的音效
        AudioManager.shared.stopAllShopSounds()
        
        // 临时设置为休息模式，确保闪电动画不会自动播放音效
        NotificationCenter.default.post(
            name: NSNotification.Name("WorkModeChanged"),
            object: nil,
            userInfo: ["isWorkMode": false]
        )
        
        // 特殊通知完全禁用闪电音效
        NotificationCenter.default.post(
            name: NSNotification.Name("DisableLightningEffects"),
            object: nil,
            userInfo: ["isDisabled": true]
        )
        
        print("胜利界面: 已停止所有相关音效播放")
    }
    
    // 启动动画序列
    private func startAnimations() {
        // 第一行文字动画
        withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
            title1Opacity = 1.0
            title1Scale = 1.0
        }
        
        // 第二行文字动画
        withAnimation(.easeOut(duration: 0.7).delay(0.8)) {
            title2Opacity = 1.0
            title2Scale = 1.0
        }
        
        // 第三行文字动画
        withAnimation(.easeOut(duration: 0.7).delay(1.3)) {
            title3Opacity = 1.0
            title3Scale = 1.0
        }
        
        // 金币数字动画
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.6)) {
            coinsOpacity = 1.0
            coinsScale = 1.0
        }
        
        // Boss倒地动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.5)) {
                bossOpacity = 1.0
            }
            
            // 预加载帧图像用于拖影效果
            self.preloadBossFrames()
            
            // 启用拖影效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.trailEffectEnabled = true
            }
        }
        
        // 提示文本动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeIn(duration: 0.6)) {
                tipOpacity = 1.0
            }
            
            // 启动提示文本闪烁效果
            startTipFlashing()
        }
    }
    
    // 预加载Boss动画帧用于拖影效果
    private func preloadBossFrames() {
        var frames: [UIImage] = []
        for i in 1...5 {
            if let frameImage = UIImage(named: "boss_death_\(i)") {
                frames.append(frameImage)
            }
        }
        
        // 如果成功加载了帧图像，创建简单的拖影效果
        if !frames.isEmpty {
            // 初始化拖影
            previousBossFrames[0] = frames[0]
            previousBossFrames[1] = frames[0]
            previousBossFrames[2] = frames[0]
            
            // 初始化最后一帧图像以备用
            finalBossFrame = frames.last
            
            // 创建帧索引跟踪变量
            var currentFrameIndex = 0
            
            // 设置拖影效果更新计时器 - 时间间隔应该与动画帧率匹配
            // boss.death的fps为1.5，意味着每0.67秒一帧
            trailEffectTimer = Timer.scheduledTimer(withTimeInterval: 0.67, repeats: true) { timer in
                // 因为VictoryView是struct，不能使用weak self，
                // 但我们在struct上计时器生命周期有良好控制，不会造成循环引用
                
                // 如果动画未完成才更新拖影
                if !self.animationFinished {
                    // 移动拖影
                    self.previousBossFrames[0] = self.previousBossFrames[1]
                    self.previousBossFrames[1] = self.previousBossFrames[2]
                    
                    // 更新拖影为当前帧
                    if currentFrameIndex < frames.count {
                        self.previousBossFrames[2] = frames[currentFrameIndex]
                        currentFrameIndex += 1
                        
                        // 如果已经到达最后一帧，停止计时器
                        if currentFrameIndex >= frames.count {
                            timer.invalidate()
                            self.trailEffectTimer = nil
                            
                            // 确保最终状态正确
                            self.finalBossFrame = frames.last
                            self.animationFinished = true
                        }
                    }
                } else {
                    // 如果动画已完成，停止计时器
                    timer.invalidate()
                    self.trailEffectTimer = nil
                }
            }
            
            if let timer = trailEffectTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    // 提示文本闪烁效果
    private func startTipFlashing() {
        // 停止任何现有的定时器
        flashingTimer?.invalidate()
        
        // 每0.8秒闪烁一次
        flashingTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                tipFlash.toggle()
            }
        }
        
        // 将计时器加入 RunLoop
        if let timer = flashingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}

#Preview {
    VictoryView(coinsEarned: 9999, onComplete: {})
} 