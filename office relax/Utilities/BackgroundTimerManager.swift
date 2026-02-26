//
//  BackgroundTimerManager.swift
//  office relax
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import UserNotifications
import BackgroundTasks
import UIKit
import AVFoundation

class BackgroundTimerManager: ObservableObject {
    static let shared = BackgroundTimerManager()
    
    /// 是否已注册过 BGTaskScheduler，避免重复注册导致崩溃
    private static var hasRegisteredBackgroundTasks = false
    /// 使用 NSRecursiveLock，避免 setupBackgroundTasks 内调用 registerBackgroundTask 时同线程再次加锁死锁
    private static let registrationLock = NSRecursiveLock()
    
    // 后台任务标识符
    private let backgroundTaskIdentifier = "com.focusbuddy.timer"
    
    // 计时器状态
    @Published var isTimerRunning = false
    @Published var remainingSeconds: Int = 0
    @Published var isWorkMode = true
    
    // 时间记录
    private var timerStartDate: Date?
    private var backgroundTime: Date?
    private var totalBackgroundTime: TimeInterval = 0
    
    // 后台任务相关
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // 音频保活相关
    private var silentAudioPlayer: AVAudioPlayer?
    private var audioSessionMonitor: Timer?
    
    private init() {
        print("BackgroundTimerManager: 初始化后台计时管理器")
        setupBackgroundTasks()
        requestNotificationPermission()
        setupAudioSession()
        startAudioSessionMonitoring()
        
        // 检查是否有未完成的计时器状态
        checkForUnfinishedTimer()
    }
    
    // 公共方法：设置后台任务（供AppDelegate调用）
    func setupBackgroundTasksIfNeeded() {
        print("BackgroundTimerManager: 检查并设置后台任务")
        setupBackgroundTasks()
    }
    
    // 检查是否有未完成的计时器
    private func checkForUnfinishedTimer() {
        let defaults = UserDefaults.standard
        let wasRunning = defaults.bool(forKey: "timer_is_running")
        let savedRemainingSeconds = defaults.integer(forKey: "timer_remaining_seconds")
        
        if wasRunning && savedRemainingSeconds <= 0 {
            print("BackgroundTimerManager: 发现未完成的计时器（剩余时间为0），清理状态")
            // 清理无效状态
            defaults.removeObject(forKey: "timer_is_running")
            defaults.removeObject(forKey: "timer_remaining_seconds")
            defaults.removeObject(forKey: "timer_is_work_mode")
            defaults.removeObject(forKey: "timer_start_date")
            defaults.removeObject(forKey: "timer_total_background_time")
            defaults.removeObject(forKey: "timer_last_save_time")
        }
    }
    
    // MARK: - 后台任务设置
    private func setupBackgroundTasks() {
        Self.registrationLock.lock()
        defer { Self.registrationLock.unlock() }
        guard !Self.hasRegisteredBackgroundTasks else {
            print("BackgroundTimerManager: 后台任务已注册过，跳过")
            return
        }
        let identifier = backgroundTaskIdentifier
        if Thread.isMainThread {
            registerBackgroundTask(identifier: identifier)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.registerBackgroundTask(identifier: identifier)
            }
        }
    }
    
    /// 在主线程执行一次 BGTaskScheduler 注册（identifier 必须在 Info.plist BGTaskSchedulerPermittedIdentifiers 中）
    private func registerBackgroundTask(identifier: String) {
        Self.registrationLock.lock()
        defer { Self.registrationLock.unlock() }
        guard !Self.hasRegisteredBackgroundTasks else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { [weak self] task in
            self?.handleBackgroundTask(task as! BGProcessingTask)
        }
        Self.hasRegisteredBackgroundTasks = true
        print("BackgroundTimerManager: 后台任务已注册")
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        print("BackgroundTimerManager: 开始处理后台任务")
        
        task.expirationHandler = {
            print("BackgroundTimerManager: 后台任务即将过期")
            self.endBackgroundTask()
        }
        
        // 只扣除「本段后台时间」，避免与前台每秒 -1 重复扣减
        applyBackgroundElapsedTime()
        
        scheduleBackgroundTask()
        task.setTaskCompleted(success: true)
        print("BackgroundTimerManager: 后台任务完成")
    }
    
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30秒后执行
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTimerManager: 后台任务已安排")
        } catch {
            print("BackgroundTimerManager: 安排后台任务失败: \(error)")
        }
    }
    
    // MARK: - 通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("BackgroundTimerManager: 通知权限已获取")
            } else {
                print("BackgroundTimerManager: 通知权限被拒绝: \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    // MARK: - 通知权限检查
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("BackgroundTimerManager: 通知权限检查:")
                print("- 授权状态: \(settings.authorizationStatus.rawValue)")
                print("- 通知中心: \(settings.notificationCenterSetting.rawValue)")
                print("- 锁定屏幕: \(settings.lockScreenSetting.rawValue)")
                print("- 横幅: \(settings.alertSetting.rawValue)")
                print("- 声音: \(settings.soundSetting.rawValue)")
                print("- 角标: \(settings.badgeSetting.rawValue)")
                
                if settings.authorizationStatus == .authorized {
                    print("BackgroundTimerManager: ✅ 通知权限已授权")
                } else {
                    print("BackgroundTimerManager: ❌ 通知权限未授权")
                }
            }
        }
    }
    
    // 测试通知功能
    func testNotification() {
        print("BackgroundTimerManager: 开始测试通知功能")
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from Focus Buddy"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("BackgroundTimerManager: 测试通知发送失败: \(error)")
            } else {
                print("BackgroundTimerManager: ✅ 测试通知已发送")
            }
        }
    }
    
    // MARK: - 计时器控制
    func startTimer(workMode: Bool, duration: Int) {
        print("BackgroundTimerManager: 启动计时器 - 模式: \(workMode ? "工作" : "休息"), 时长: \(duration)秒")
        
        isTimerRunning = true
        isWorkMode = workMode
        remainingSeconds = duration
        timerStartDate = Date()
        totalBackgroundTime = 0
        
        // 启动音频保活
        startAudioKeepAlive()
        
        // 安排后台任务
        scheduleBackgroundTask()
        
        // 设置本地通知
        scheduleTimerNotification()
        
        // 开始后台任务
        beginBackgroundTask()
    }
    
    func stopTimer() {
        print("BackgroundTimerManager: 停止计时器")
        
        isTimerRunning = false
        timerStartDate = nil
        backgroundTime = nil
        totalBackgroundTime = 0
        
        // 停止音频保活
        stopAudioKeepAlive()
        
        // 取消通知
        cancelTimerNotification()
        
        // 结束后台任务
        endBackgroundTask()
    }
    
    func pauseTimer() {
        print("BackgroundTimerManager: 暂停计时器")
        backgroundTime = Date()
        isTimerRunning = false
    }
    
    func resumeTimer() {
        print("BackgroundTimerManager: 恢复计时器")
        
        if let backgroundTime = backgroundTime {
            let timeInBackground = Date().timeIntervalSince(backgroundTime)
            totalBackgroundTime += timeInBackground
            self.backgroundTime = nil
        }
        
        isTimerRunning = true
        scheduleBackgroundTask()
    }
    
    // MARK: - 后台任务管理
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "TimerBackgroundTask") {
            print("BackgroundTimerManager: 后台任务即将过期")
            self.endBackgroundTask()
        }
        print("BackgroundTimerManager: 后台任务已开始，ID: \(backgroundTaskID.rawValue)")
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("BackgroundTimerManager: 后台任务已结束")
        }
    }
    
    // MARK: - 实时计时更新（供UI调用）
    func updateTimerInRealTime() {
        guard isTimerRunning, let startDate = timerStartDate else {
            print("BackgroundTimerManager: 计时器未运行或未初始化，跳过更新")
            return
        }
        
        // 每秒减少1秒，这是最简单可靠的方法
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            print("BackgroundTimerManager: 实时更新计时器，剩余时间: \(remainingSeconds)秒")
        } else {
            remainingSeconds = 0
            print("BackgroundTimerManager: 计时器完成，调用timerCompleted")
            // 调用timerCompleted来发送本地推送通知
            timerCompleted()
        }
        
        // 额外检查：如果剩余时间为0但计时器还在运行，强制停止
        if remainingSeconds <= 0 && isTimerRunning {
            print("BackgroundTimerManager: 强制停止计时器（剩余时间为0），调用timerCompleted")
            timerCompleted()
        }
    }
    
    // MARK: - 本地通知
    private func scheduleTimerNotification() {
        // 专注开始时不再发送通知，只保留完成时的通知
        print("BackgroundTimerManager: 专注开始，不发送开始通知")
    }
    
    private func cancelTimerNotification() {
        // 清理任何可能存在的通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer_completed"])
        print("BackgroundTimerManager: 清理计时器通知")
    }
    
    // MARK: - 计时完成处理
    private func timerCompleted() {
        print("BackgroundTimerManager: 计时器完成")
        
        // 防止重复调用
        if !isTimerRunning && remainingSeconds > 0 {
            print("BackgroundTimerManager: 计时器已完成，跳过重复调用")
            return
        }
        
        // 设置计时器状态为完成
        isTimerRunning = false
        remainingSeconds = 0
        
        // 检查通知权限
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    print("BackgroundTimerManager: ✅ 通知权限已授权，发送完成通知")
                    
                    // 发送完成通知（英文版）
                    let content = UNMutableNotificationContent()
                    content.title = self.isWorkMode ? "Focus Completed!" : "Break Finished!"
                    content.body = self.isWorkMode ? "Great job! You've completed your focus session!" : "Break time is over. Ready for your next focus session!"
                    content.sound = .default
                    
                    let request = UNNotificationRequest(identifier: "timer_completed", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("BackgroundTimerManager: 发送完成通知失败: \(error)")
                        } else {
                            print("BackgroundTimerManager: ✅ 完成通知已发送")
                        }
                    }
                } else {
                    print("BackgroundTimerManager: ❌ 通知权限未授权，无法发送通知")
                    print("BackgroundTimerManager: 授权状态: \(settings.authorizationStatus.rawValue)")
                }
            }
        }
        
        // 结束后台任务
        endBackgroundTask()
        
        // 发送完成通知 - 使用主线程确保安全
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("TimerCompleted"), object: nil)
        }
    }
    
    // MARK: - 应用状态变化处理
    func applicationWillResignActive() {
        print("BackgroundTimerManager: 应用即将进入后台")
        backgroundTime = Date()
        
        // 保存当前状态到UserDefaults，以便锁屏后恢复
        saveTimerState()
    }
    
    func applicationDidBecomeActive() {
        print("BackgroundTimerManager: 应用回到前台")
        
        if let backgroundTime = backgroundTime {
            let timeInBackground = Date().timeIntervalSince(backgroundTime)
            totalBackgroundTime += timeInBackground
            self.backgroundTime = nil
            
            // 只扣除后台经过的时间（前台时间已由 updateTimerInRealTime 每秒扣减，不能再用 updateTimerInBackground 按「总前台时间」扣减，否则会重复）
            let secondsToDecrease = Int(timeInBackground)
            if remainingSeconds > secondsToDecrease {
                remainingSeconds -= secondsToDecrease
                print("BackgroundTimerManager: 后台时间补偿: \(timeInBackground)秒, 剩余: \(remainingSeconds)秒")
            } else {
                remainingSeconds = 0
                print("BackgroundTimerManager: 后台时间补偿后计时器结束: \(timeInBackground)秒")
                timerCompleted()
            }
        } else {
            restoreTimerState()
        }
        
        if isTimerRunning && remainingSeconds <= 0 {
            print("BackgroundTimerManager: 检测到计时器已完成，发送完成通知")
            isTimerRunning = false
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TimerCompleted"), object: nil)
            }
        }
    }
    
    /// 只应用「从进入后台到当前」这段经过的时间到 remainingSeconds（供 BGTask 与恢复逻辑用，避免重复扣减前台时间）
    private func applyBackgroundElapsedTime() {
        guard isTimerRunning, let bgTime = backgroundTime else { return }
        let elapsed = Date().timeIntervalSince(bgTime)
        let seconds = Int(elapsed)
        if seconds <= 0 { return }
        
        totalBackgroundTime += elapsed
        self.backgroundTime = Date()
        
        if remainingSeconds > seconds {
            remainingSeconds -= seconds
            saveTimerState()
            print("BackgroundTimerManager: BGTask 应用后台时间: \(seconds)秒, 剩余: \(remainingSeconds)秒")
        } else {
            remainingSeconds = 0
            saveTimerState()
            timerCompleted()
        }
    }
    
    // MARK: - 状态保存和恢复
    private func saveTimerState() {
        let defaults = UserDefaults.standard
        defaults.set(isTimerRunning, forKey: "timer_is_running")
        defaults.set(remainingSeconds, forKey: "timer_remaining_seconds")
        defaults.set(isWorkMode, forKey: "timer_is_work_mode")
        defaults.set(timerStartDate?.timeIntervalSince1970, forKey: "timer_start_date")
        defaults.set(totalBackgroundTime, forKey: "timer_total_background_time")
        defaults.set(Date().timeIntervalSince1970, forKey: "timer_last_save_time")
        print("BackgroundTimerManager: 保存计时器状态")
    }
    
    private func restoreTimerState() {
        let defaults = UserDefaults.standard
        let wasRunning = defaults.bool(forKey: "timer_is_running")
        let savedRemainingSeconds = defaults.integer(forKey: "timer_remaining_seconds")
        let savedIsWorkMode = defaults.bool(forKey: "timer_is_work_mode")
        let savedStartDate = defaults.double(forKey: "timer_start_date")
        let savedTotalBackgroundTime = defaults.double(forKey: "timer_total_background_time")
        let lastSaveTime = defaults.double(forKey: "timer_last_save_time")
        
        guard wasRunning, savedRemainingSeconds > 0 else { return }
        
        print("BackgroundTimerManager: 恢复计时器状态")
        isTimerRunning = true
        isWorkMode = savedIsWorkMode
        timerStartDate = Date(timeIntervalSince1970: savedStartDate)
        totalBackgroundTime = savedTotalBackgroundTime
        
        let timeSinceLastSave = Date().timeIntervalSince1970 - lastSaveTime
        if timeSinceLastSave > 0 {
            totalBackgroundTime += timeSinceLastSave
            let decrease = Int(timeSinceLastSave)
            if savedRemainingSeconds > decrease {
                remainingSeconds = savedRemainingSeconds - decrease
                print("BackgroundTimerManager: 恢复状态 - 离开 \(Int(timeSinceLastSave)) 秒, 剩余: \(remainingSeconds)秒")
            } else {
                remainingSeconds = 0
                print("BackgroundTimerManager: 恢复时已超时，触发完成")
                timerCompleted()
                return
            }
        } else {
            remainingSeconds = savedRemainingSeconds
            print("BackgroundTimerManager: 恢复状态 - 剩余时间: \(remainingSeconds)秒")
        }
    }
    
    // MARK: - 音频保活
    private func setupAudioSession() {
        do {
            // 设置音频会话为播放模式，支持后台运行
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            print("BackgroundTimerManager: 音频会话保活已设置")
        } catch {
            print("BackgroundTimerManager: 设置音频会话失败: \(error)")
        }
    }
    
    // 创建静音音频播放器用于保活（在后台线程执行，避免阻塞主线程导致闪屏卡住）
    private func createSilentAudioPlayer() {
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let frameCount = Int(sampleRate * duration)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var audioData = Data()
            audioData.reserveCapacity(frameCount * 2)
            for _ in 0..<frameCount {
                let sample: Int16 = 0
                audioData.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Data($0) })
            }
            
            do {
                let player = try AVAudioPlayer(data: audioData)
                player.volume = 0.0
                player.numberOfLoops = -1
                player.prepareToPlay()
                DispatchQueue.main.async {
                    self?.silentAudioPlayer = player
                    print("BackgroundTimerManager: 静音音频播放器已创建")
                    self?.silentAudioPlayer?.play()
                }
            } catch {
                DispatchQueue.main.async {
                    print("BackgroundTimerManager: 创建静音音频播放器失败: \(error)")
                }
            }
        }
    }
    
    func startAudioKeepAlive() {
        if silentAudioPlayer == nil {
            createSilentAudioPlayer()
        } else {
            silentAudioPlayer?.play()
        }
        
        print("BackgroundTimerManager: 音频保活已启动")
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("BackgroundTimerManager: 音频会话已重新激活")
        } catch {
            print("BackgroundTimerManager: 重新激活音频会话失败: \(error)")
        }
    }
    
    private func stopAudioKeepAlive() {
        silentAudioPlayer?.stop()
        print("BackgroundTimerManager: 音频保活已停止")
    }
    
    // 开始音频会话监控
    private func startAudioSessionMonitoring() {
        audioSessionMonitor = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkAudioSessionStatus()
        }
        print("BackgroundTimerManager: 音频会话监控已启动")
    }
    
    // 检查音频会话状态
    private func checkAudioSessionStatus() {
        let audioSession = AVAudioSession.sharedInstance()
        let isOtherAudioPlaying = audioSession.isOtherAudioPlaying
        let category = audioSession.category
        let options = audioSession.categoryOptions
        
        print("BackgroundTimerManager: 音频会话状态检查:")
        print("- 其他音频播放中: \(isOtherAudioPlaying)")
        print("- 音频类别: \(category.rawValue)")
        print("- 音频选项: \(options.rawValue)")
        print("- 音频会话活跃: \(audioSession.isInputAvailable)")
        
        // 验证音频保活状态
        if isTimerRunning {
            verifyAudioKeepAliveStatus()
        }
    }
    
    // 验证音频保活状态
    private func verifyAudioKeepAliveStatus() {
        guard let player = silentAudioPlayer else {
            print("BackgroundTimerManager: ⚠️ 静音音频播放器不存在")
            return
        }
        
        let isPlaying = player.isPlaying
        let currentTime = player.currentTime
        let duration = player.duration
        
        print("BackgroundTimerManager: 音频保活状态验证:")
        print("- 播放器状态: \(isPlaying ? "播放中" : "已停止")")
        print("- 当前播放时间: \(currentTime)")
        print("- 音频时长: \(duration)")
        
        if !isPlaying {
            print("BackgroundTimerManager: ⚠️ 音频保活可能已失效，尝试重新启动")
            startAudioKeepAlive()
        }
    }
    
    // MARK: - 获取当前状态
    func getCurrentStatus() -> (isRunning: Bool, remainingSeconds: Int, isWorkMode: Bool) {
        return (isTimerRunning, remainingSeconds, isWorkMode)
    }
}
