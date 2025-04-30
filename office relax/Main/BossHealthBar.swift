//
//  BossHealthBar.swift
//  office relax
//
//  Created by LazyG on 2025/4/25.
//

import SwiftUI

struct BossHealthBar: View {
    var progress: Double // 0.0 表示满血，1.0 表示没血
    var isVisible: Bool
    
    // 动画状态
    @State private var isAnimating = false
    @State private var isWarningPulse = false
    @State private var isDamageFlash = false
    @State private var lastProgress: Double = 0.0
    
    // 血条颜色基于血量变化
    private var healthColor: Color {
        if progress >= 0.8 {
            // 血量低于20%，显示红色
            return Color.red
        } else if progress >= 0.5 {
            // 血量低于50%，显示橙色
            return Color.orange
        } else {
            // 血量充足，显示绿色
            return Color.green
        }
    }
    
    // 是否显示警告效果
    private var showWarning: Bool {
        return progress >= 0.8
    }
    
    // 计算血量百分比
    private var healthPercentage: Int {
        return Int(round((1.0 - progress) * 100))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 血条背景
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: geometry.size.width, height: 12)
                
                // 血条内容 - 从满到空的渐变
                HStack(spacing: 0) {
                    // 彩色实际血量
                    LinearGradient(
                        gradient: Gradient(colors: [healthColor.opacity(0.7), healthColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * (1 - progress), height: 8)
                    .cornerRadius(2)
                    // 低血量时添加闪烁效果
                    .opacity(showWarning && isWarningPulse ? 0.7 : 1.0)
                    
                    // 空白部分（已损失血量）
                    Spacer(minLength: 0)
                }
                .padding(2)
                .frame(width: geometry.size.width, height: 12, alignment: .leading)
                
                // 伤害闪光效果
                if isDamageFlash {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width, height: 12)
                        .opacity(isDamageFlash ? 0.6 : 0)
                        .cornerRadius(4)
                }
                
                // 血条边框
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black, lineWidth: 1.5)
                    .frame(width: geometry.size.width, height: 12)
                
                // 添加血条刻度线
                ForEach(0..<5) { i in
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 1, height: 10)
                        .offset(x: CGFloat(i) * geometry.size.width / 5 + geometry.size.width / 10 - 0.5)
                }
                
                // 显示百分比文字
                if geometry.size.width > 100 {
                    Text("\(healthPercentage)%")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1)
                        .frame(width: geometry.size.width, alignment: .center)
                }
            }
            .frame(width: 140, height: 12)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.3), value: isVisible)
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                // 初始化上次进度
                lastProgress = progress
                
                // 添加轻微的脉动效果
                isAnimating = true
                
                // 添加低血量时的警告闪烁效果
                if showWarning {
                    withAnimation(Animation.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                        isWarningPulse = true
                    }
                }
            }
            .onChange(of: progress) { newValue in
                // 当血量低于20%时开始闪烁
                if newValue >= 0.8 && !isWarningPulse {
                    withAnimation(Animation.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                        isWarningPulse = true
                    }
                }
                
                // 检测血量减少，显示伤害效果
                if newValue > lastProgress && !isDamageFlash {
                    // 触发伤害闪光效果
                    withAnimation(.easeOut(duration: 0.1)) {
                        isDamageFlash = true
                    }
                    
                    // 0.15秒后恢复
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeIn(duration: 0.1)) {
                            isDamageFlash = false
                        }
                    }
                }
                
                // 更新上次进度
                lastProgress = newValue
            }
        }
        .frame(width: 140, height: 12) // 使血条略宽一些
    }
}

#Preview {
    VStack(spacing: 20) {
        BossHealthBar(progress: 0.1, isVisible: true) // 满血状态
        BossHealthBar(progress: 0.4, isVisible: true) // 中等血量
        BossHealthBar(progress: 0.7, isVisible: true) // 偏低血量
        BossHealthBar(progress: 0.9, isVisible: true) // 危险血量
    }
    .padding()
    .background(Color.gray)
} 