//
//  SplashView.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var titleOpacity = 0.0
    @State private var titleScale = 0.8
    
    var body: some View {
        ZStack {
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
            // 标题动画效果
            withAnimation(.easeOut(duration: 1.0)) {
                titleOpacity = 1.0
                titleScale = 1.0
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
}

#Preview {
    SplashView()
} 