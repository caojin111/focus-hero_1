//
//  StartFocusView.swift
//  office relax
//
//  Created by LazyG on 2025/5/9.
//

import SwiftUI

struct StartFocusView: View {
    @ObservedObject private var userDataManager = UserDataManager.shared
    @ObservedObject private var audioManager = AudioManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showMainView = false
    @State private var animationCompleted = false
    @State private var startClosing = false
    
    // 当前专注次数 - 完全由外部传入，而不是在视图内部递增
    private let currentFocusCount: Int
    
    // 动画状态
    @State private var textOpacity = 0.0
    @State private var textScale = 0.8
    @State private var numberOpacity = 0.0
    @State private var numberScale = 0.5
    @State private var closeScale = 1.0
    @State private var closeOpacity = 1.0

    @State private var breatheEffect = false // 呼吸效果状态
    @State private var numberBreatheScale = 1.0 // 数字呼吸效果缩放
    
    // 传入当前计数作为参数，只负责显示，不负责递增
    var onComplete: () -> Void
    
    init(focusCount: Int, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        // 直接使用传入的值，而非内部获取
        self.currentFocusCount = focusCount
    }
    
    var body: some View {
        ZStack {
            // 背景 - 使用深色背景
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // "Take a deep breath" 文本 - 添加呼吸效果
                Image("start_focus_1")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                    .opacity(textOpacity * (breatheEffect ? 0.8 : 1.0)) // 添加闪烁效果
                    .scaleEffect(textScale)
                    .padding(.top, 50)
                
                // 数字部分 (现在放在 start_focus_2 的位置)
                HStack(alignment: .bottom, spacing: 5) {
                    // 放置在原 "No." 位置的图像
                    Image("start_focus_3")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60)
                        .opacity(numberOpacity)
                    
                    Text("\(currentFocusCount)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
                        .opacity(numberOpacity)
                        .scaleEffect(numberScale * numberBreatheScale) // 添加数字呼吸效果
                        .padding(.leading, 5)
                        .offset(y: 15) // 向下偏移15像素
                }
                .padding(.vertical, 20)
                
                // "click anywhere to start your" 文本 (现在放在数字部分的位置，进一步缩小并偏移)
                HStack {
                    Spacer()
                    
                    Image("start_focus_2")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.3) // 缩小两倍
                        .opacity(textOpacity)
                        .scaleEffect(textScale)
                        .padding(.trailing, 50) // 向右偏移50像素
                    
                    Spacer(minLength: 5)
                }
                
                Spacer()
            }
            .padding()
            .scaleEffect(closeScale)
            .opacity(closeOpacity)
        }
        .onAppear {
            // 停止所有音频（音乐和音效）
            audioManager.stopAllAudio()
            
            // 禁用所有音效播放
            audioManager.isSoundPlaybackEnabled = false
            print("focus_start页面：已禁用所有音效播放")
            
            // 开始动画序列
            startAnimations()
        }
        .onDisappear {
            // 恢复音效播放功能
            audioManager.isSoundPlaybackEnabled = true
            print("focus_start页面：已恢复音效播放功能")
        }
        .onTapGesture {
            if animationCompleted && !startClosing {
                // 标记开始关闭
                startClosing = true
                
                // 播放退场动画
                playExitAnimation()
            }
        }
    }
    
    // 启动进场动画
    private func startAnimations() {
        // "Take a deep breath" 动画
        withAnimation(.easeOut(duration: 0.8)) {
            textOpacity = 1.0
            textScale = 1.0
        }
        
        // 启动文字呼吸效果
        startBreathingEffect()
        
        // 数字动画 - 适当延迟后以弹性效果显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6, blendDuration: 0.8)) {
                numberOpacity = 1.0
                numberScale = 1.0
            }
            
            // 启动数字呼吸效果
            startNumberBreathingEffect()
        }
        
        // 所有动画完成，可以接受点击
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            animationCompleted = true
        }
    }
    
    // 退场动画
    private func playExitAnimation() {
        // 使用弹性缩小和淡出效果
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            closeScale = 0.85
            closeOpacity = 0.0
        }
        
        // 动画完成后回调
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // 恢复音效播放功能 (在回调前恢复，确保退出视图后音效可正常播放)
            audioManager.isSoundPlaybackEnabled = true
            print("focus_start页面退出：已恢复音效播放功能")
            
            onComplete()
        }
    }
    
    // 标题呼吸效果
    private func startBreathingEffect() {
        // 每2秒变化一次透明度，创造低频闪烁效果
        let breathingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                breatheEffect.toggle()
            }
        }
        
        // 将计时器加入 RunLoop
        RunLoop.main.add(breathingTimer, forMode: .common)
        
        // 退出时取消计时器
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            breathingTimer.invalidate()
        }
    }
    
    // 数字呼吸效果
    private func startNumberBreathingEffect() {
        // 以更高的频率为数字创建呼吸效果
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.75)) {
                // 在1.0和1.1之间缓慢脉动
                self.numberBreatheScale = self.numberBreatheScale == 1.0 ? 1.1 : 1.0
            }
        }
        
        // 立即开始第一次动画
        withAnimation(.easeInOut(duration: 0.75)) {
            self.numberBreatheScale = 1.1
        }
        
        // 将计时器加入 RunLoop
        RunLoop.main.add(timer, forMode: .common)
        
        // 退出时取消计时器
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            timer.invalidate()
        }
    }
}

#Preview {
    StartFocusView(focusCount: 1, onComplete: {})
} 