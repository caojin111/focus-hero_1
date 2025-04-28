//
//  OnboardingView.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @StateObject private var userDataManager = UserDataManager.shared
    @State private var currentPage = 0
    @State private var showCompletionScreen = false
    
    // 转场动画状态
    @State private var isTransitioning = false
    @State private var circleScale: CGFloat = 0.0
    @State private var circleOpacity: Double = 0
    @State private var finalTransition = false
    
    // 音频播放器
    @State private var audioPlayer: AVAudioPlayer?
    @State private var stingerPlayer: AVAudioPlayer?
    
    // 用户信息暂存
    @State private var focusTime: Double = 25
    @State private var breakTime: Double = 5
    @State private var heroName: String = ""
    
    // 第一页动画状态
    @State private var titleOpacity1 = 0.0
    @State private var titleScale1 = 0.8
    @State private var controlsOpacity1 = 0.0
    
    // 第二页动画状态
    @State private var titleOpacity2 = 0.0
    @State private var titleScale2 = 0.8
    @State private var controlsOpacity2 = 0.0
    
    // 完成页动画状态
    @State private var titleOpacity3 = 0.0
    @State private var titleScale3 = 0.8
    @State private var subtitle3Opacity = 0.0
    @State private var subtitle3Scale = 0.8
    @State private var controlsOpacity3 = 0.0
    
    var body: some View {
        ZStack {
            // 背景图放在最底层，覆盖整个屏幕
            if !showCompletionScreen {
                if currentPage == 0 {
                    Image("Splash_bg_1")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .scaleEffect(1.2)
                        .clipped()
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                        .onAppear {
                            playStingerSound()
                        }
                } else {
                    Image("Splash_bg_2")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .scaleEffect(1.2)
                        .clipped()
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                        .onAppear {
                            playStingerSound()
                        }
                }
            } else {
                // 完成页面背景
                Image("Splash_bg_3")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .scaleEffect(1.2)
                    .clipped()
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onAppear {
                        playStingerSound()
                    }
            }
            
            // 内容层
            VStack(spacing: 0) {
                // 导航按钮
                HStack {
                    Button(action: {
                        if currentPage > 0 {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .opacity(currentPage > 0 && !showCompletionScreen ? 1 : 0)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 30)
                
                // 问卷页面
                if showCompletionScreen {
                    completionView
                } else {
                    TabView(selection: $currentPage) {
                        // 专注时间问题
                        focusTimeQuestionView
                            .tag(0)
                        
                        // 英雄名称问题
                        heroNameQuestionView
                            .tag(1)
                    }
                    #if os(iOS)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    #else
                    .tabViewStyle(.automatic)
                    #endif
                    .animation(.easeInOut, value: currentPage)
                }
            }
            .opacity(isTransitioning ? 0 : 1)
            
            // 转场动画层
            if isTransitioning {
                ZStack {
                    // 渐变背景
                    RadialGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple]),
                        center: .center,
                        startRadius: 50,
                        endRadius: UIScreen.main.bounds.width * 1.5
                    )
                    .edgesIgnoringSafeArea(.all)
                    .opacity(circleOpacity)
                    
                    // 缩放圆形
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(circleScale)
                        .opacity(circleScale < 5 ? 1 : 0)
                    
                    // 粒子效果
                    ForEach(0..<20) { i in
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: CGFloat.random(in: 5...15), height: CGFloat.random(in: 5...15))
                            .offset(
                                x: CGFloat.random(in: -150...150) * circleScale,
                                y: CGFloat.random(in: -150...150) * circleScale
                            )
                            .opacity(circleScale > 1 ? Double.random(in: 0.3...0.7) : 0)
                            .animation(
                                Animation.easeOut(duration: 0.8)
                                    .delay(Double.random(in: 0.1...0.3)),
                                value: circleScale
                            )
                    }
                    
                    // 标志性图标
                    Image(systemName: "bolt.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                        .opacity(circleScale > 2 && circleScale < 6 ? 1 : 0)
                        .scaleEffect(circleScale > 2 ? 2 : 0.5)
                        .rotationEffect(.degrees(circleScale * 30))
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // 播放背景音乐
            playBackgroundMusic()
            // 如果是第一个页面，播放stinger音效
            if currentPage == 0 {
                playStingerSound()
            }
        }
        .onDisappear {
            // 停止背景音乐
            stopBackgroundMusic()
        }
        .onChange(of: currentPage) { newValue in
            if newValue == 0 {
                // 当回到第一个页面时播放音效
                playStingerSound()
            }
        }
        // 当动画完成后跳转到主视图
        .fullScreenCover(isPresented: $finalTransition) {
            MainView()
        }
    }
    
    // 开始转场动画
    private func startTransitionAnimation() {
        isTransitioning = true
        
        // 圆形缩放动画
        withAnimation(.easeIn(duration: 1.0)) {
            circleScale = 1.0
            circleOpacity = 0.8
        }
        
        // 圆形继续缩放和背景淡入
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 2.0)) {
                circleScale = 12.0
                circleOpacity = 1.0
            }
            
            // 完成动画后设置标志，进行最终跳转
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                finalTransition = true
            }
        }
    }
    
    // 播放背景音乐
    private func playBackgroundMusic() {
        guard let path = Bundle.main.path(forResource: "onboarding_music", ofType: "mp3") else {
            print("无法找到音乐文件")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // 循环播放
            audioPlayer?.volume = 0.5 // 设置音量
            audioPlayer?.play()
        } catch {
            print("播放音乐时出错: \(error.localizedDescription)")
        }
    }
    
    // 播放stinger音效
    private func playStingerSound() {
        guard let path = Bundle.main.path(forResource: "stinger", ofType: "mp3") else {
            print("无法找到stinger音效文件")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            stingerPlayer = try AVAudioPlayer(contentsOf: url)
            stingerPlayer?.volume = 0.8 // 设置音量
            stingerPlayer?.play()
        } catch {
            print("播放stinger音效时出错: \(error.localizedDescription)")
        }
    }
    
    // 停止背景音乐
    private func stopBackgroundMusic() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // 完成视图
    var completionView: some View {
        VStack(spacing: 40) {
            Spacer(minLength: 60)
            
            // 上方标题
            Image("Splash_text_3")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 250, maxHeight: 80)
                .scaleEffect(1.2)
                .opacity(titleOpacity3)
                .scaleEffect(titleScale3)
                .padding(.bottom, 20)
                .offset(y: -50)
            
            Spacer()
            
            // 中间标题
            Image("Splash_text_4")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300, maxHeight: 120)
                .scaleEffect(1.2)
                .opacity(subtitle3Opacity)
                .scaleEffect(subtitle3Scale)
                .offset(y: -80)
            
            Spacer()
            
            // 开始按钮
            Button(action: {
                // 保存设置
                UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                
                // 停止背景音乐并开始转场动画
                stopBackgroundMusic()
                startTransitionAnimation()
            }) {
                Text("Start focus!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]), 
                                      startPoint: .leading, 
                                      endPoint: .trailing)
                    )
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            }
            .opacity(controlsOpacity3)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .onAppear {
            // 重置动画状态
            titleOpacity3 = 0
            titleScale3 = 0.8
            subtitle3Opacity = 0
            subtitle3Scale = 0.8
            controlsOpacity3 = 0
            
            // 第一个标题动画
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                titleOpacity3 = 1.0
                titleScale3 = 1.0
            }
            
            // 第二个标题动画（延迟稍长）
            withAnimation(.easeOut(duration: 1.0).delay(0.6)) {
                subtitle3Opacity = 1.0
                subtitle3Scale = 1.0
            }
            
            // 按钮淡入
            withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
                controlsOpacity3 = 1.0
            }
        }
        .transition(.opacity)
    }
    
    // 专注时间问题视图
    var focusTimeQuestionView: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 60)
            
            // 标题
            Image("Splash_text_1")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 250, maxHeight: 80)
                .opacity(titleOpacity1)
                .scaleEffect(titleScale1)
                .padding(.bottom, 20)
            
            // 时间设置容器
            VStack(spacing: 30) {
                // 专注时间设置
                timeSettingView(title: "专注时间", value: $focusTime, range: 5...60, step: 5, color: .blue, minLabel: "5分钟", maxLabel: "60分钟")
                
                // 休息时间设置
                timeSettingView(title: "休息时间", value: $breakTime, range: 1...20, step: 1, color: .green, minLabel: "1分钟", maxLabel: "20分钟")
            }
            .opacity(controlsOpacity1)
            .padding(.horizontal)
            
            Spacer()
            
            // 继续按钮
            Button(action: {
                withAnimation {
                    currentPage += 1
                }
            }) {
                Text("继续")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]), 
                                      startPoint: .leading, 
                                      endPoint: .trailing)
                    )
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            }
            .opacity(controlsOpacity1)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .onAppear {
            // 重置动画状态以便重新播放
            titleOpacity1 = 0
            titleScale1 = 0.8
            controlsOpacity1 = 0
            
            // 标题动画
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                titleOpacity1 = 1.0
                titleScale1 = 1.0
            }
            
            // 控件淡入
            withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
                controlsOpacity1 = 1.0
            }
        }
    }
    
    // 时间设置视图组件
    func timeSettingView(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, color: Color, minLabel: String, maxLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            // 标题和时间值
            HStack {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Text("\(Int(value.wrappedValue)) 分钟")
                    .font(.system(size: 22, weight: .bold))
            }
            .foregroundColor(.white)
            
            // 滑块和时间标记
            VStack(spacing: 8) {
                // 滑块控件
                ZStack(alignment: .leading) {
                    // 滑块背景
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 12)
                    
                    // 滑块已选择部分
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color)
                        .frame(width: (CGFloat(value.wrappedValue - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)) * (UIScreen.main.bounds.width - 100), height: 12)
                }
                .overlay(
                    Slider(value: value, in: range, step: step)
                        .accentColor(.clear)
                )
                
                // 刻度标记
                HStack {
                    Text(minLabel)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text(maxLabel)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.5))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
    
    // 英雄名称问题视图
    var heroNameQuestionView: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 60)
            
            // 标题
            Image("Splash_text_2")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 250, maxHeight: 80)
                .opacity(titleOpacity2)
                .scaleEffect(titleScale2)
                .padding(.bottom, 20)
                .offset(y: -30)
            
            // 英雄名称输入区域
            VStack(alignment: .leading, spacing: 15) {
                Text("输入你的英雄名称")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                TextField("", text: $heroName)
                    .font(.system(size: 20))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                    .foregroundColor(.white)
                    .accentColor(.white) // 光标颜色
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .placeholder(when: heroName.isEmpty) {
                        Text("例如：Lazy Cat")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, 16)
                    }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.5))
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .opacity(controlsOpacity2)
            .padding(.horizontal)
            
            Spacer()
            
            // 完成按钮
            Button(action: {
                if !heroName.isEmpty {
                    // 保存用户数据
                    userDataManager.updateUserSettings(
                        focusTime: Int(focusTime),
                        breakTime: Int(breakTime),
                        heroName: heroName
                    )
                    
                    // 显示完成界面
                    withAnimation {
                        showCompletionScreen = true
                    }
                }
            }) {
                Text("完成设置")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: heroName.isEmpty ? 
                                                         [Color.gray.opacity(0.5), Color.gray.opacity(0.5)] : 
                                                         [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]), 
                                      startPoint: .leading, 
                                      endPoint: .trailing)
                    )
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(heroName.isEmpty ? 0 : 0.2), radius: 5, x: 0, y: 3)
            }
            .disabled(heroName.isEmpty)
            .opacity(controlsOpacity2)
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .onAppear {
            // 重置动画状态以便重新播放
            titleOpacity2 = 0
            titleScale2 = 0.8
            controlsOpacity2 = 0
            
            // 标题动画
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                titleOpacity2 = 1.0
                titleScale2 = 1.0
            }
            
            // 控件淡入
            withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
                controlsOpacity2 = 1.0
            }
        }
    }
}

// 用于创建占位符文本的扩展
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    OnboardingView()
} 