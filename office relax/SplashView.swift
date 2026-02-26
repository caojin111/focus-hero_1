//
//  SplashView.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI
import AVFoundation

struct SplashView: View {
    @State private var isActive = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var titleOpacity = 0.0
    @State private var titleScale = 0.8
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        ZStack {
            // 先设底色，避免图片未加载时白屏
            Color(red: 0.95, green: 0.95, blue: 0.97)
                .ignoresSafeArea()
            // 背景图
            Image("Splash_bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .scaleEffect(1.2)
                .clipped()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                // 标题
                Image("Splash_title")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .opacity(titleOpacity)
                    .scaleEffect(titleScale)
                    .offset(x: -8)
                Spacer()
                // 作者署名
                Image("Splash_text")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .padding(.bottom, 32)
                    .offset(y: -30)
            }
            .padding()
        }
        .onAppear {
            // 播放音效
            playStingerSound()
            
            // 标题动画效果
            withAnimation(.easeOut(duration: 1.0)) {
                titleOpacity = 1.0
                titleScale = 1.5
            }
            
            // 延迟2秒后跳转到主界面
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isActive) {
            if onboardingCompleted {
                MainView()
            } else {
                OnboardingView()
            }
        }
        #else
        .sheet(isPresented: $isActive) {
            if onboardingCompleted {
                MainView()
            } else {
                OnboardingView()
            }
        }
        #endif
    }
    
    // 播放stinger音效
    private func playStingerSound() {
        guard let path = Bundle.main.path(forResource: "stinger", ofType: "mp3") else {
            print("无法找到stinger音效文件")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.8 // 设置音量
            audioPlayer?.play()
        } catch {
            print("播放stinger音效时出错: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SplashView()
} 