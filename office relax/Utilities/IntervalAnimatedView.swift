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
                    
                    // 作为备份，设置一个定时器确保在动画完成后触发间隔
                    setupBackupCompletionTimer()
                }
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
        }
        .onDisappear {
            // 清理计时器和通知
            cleanupTimers()
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    // 开始播放动画
    private func startAnimation(afterDelay delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            withAnimation {
                print("启动动画 \(animationKey) 播放")
                shouldPlay = true
                lastAnimationStart = Date()
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