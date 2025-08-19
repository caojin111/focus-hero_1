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

class BackgroundTimerManager: ObservableObject {
    static let shared = BackgroundTimerManager()
    
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
    
    // 本地通知相关
    private var timerNotification: UNMutableNotificationContent?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        print("BackgroundTimerManager: 初始化后台计时管理器")
        setupBackgroundTasks()
        requestNotificationPermission()
        
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
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundTask(task as! BGProcessingTask)
        }
        print("BackgroundTimerManager: 后台任务已注册")
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        print("BackgroundTimerManager: 开始处理后台任务")
        
        // 设置任务过期处理
        task.expirationHandler = {
            print("BackgroundTimerManager: 后台任务即将过期")
            self.endBackgroundTask()
        }
        
        // 执行计时更新
        updateTimerInBackground()
        
        // 安排下次后台任务
        scheduleBackgroundTask()
        
        // 标记任务完成
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
    
    // MARK: - 计时器控制
    func startTimer(workMode: Bool, duration: Int) {
        print("BackgroundTimerManager: 启动计时器 - 模式: \(workMode ? "工作" : "休息"), 时长: \(duration)秒")
        
        isTimerRunning = true
        isWorkMode = workMode
        remainingSeconds = duration
        timerStartDate = Date()
        totalBackgroundTime = 0
        
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
    
    // MARK: - 后台计时更新
    private func updateTimerInBackground() {
        guard isTimerRunning, let startDate = timerStartDate else {
            print("BackgroundTimerManager: 计时器未运行，跳过更新")
            return
        }
        
        let currentDate = Date()
        let totalElapsedTime = currentDate.timeIntervalSince(startDate)
        let actualElapsedTime = totalElapsedTime - totalBackgroundTime
        
        // 计算应该减少的秒数
        let secondsToDecrease = Int(actualElapsedTime)
        
        if remainingSeconds > secondsToDecrease {
            remainingSeconds -= secondsToDecrease
            print("BackgroundTimerManager: 后台更新计时器，剩余时间: \(remainingSeconds)秒")
        } else {
            remainingSeconds = 0
            print("BackgroundTimerManager: 计时器在后台完成")
            timerCompleted()
        }
    }
    
    // MARK: - 实时计时更新（供UI调用）
    func updateTimerInRealTime() {
        guard isTimerRunning, let startDate = timerStartDate else {
            return
        }
        
        // 每秒减少1秒，这是最简单可靠的方法
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            print("BackgroundTimerManager: 实时更新计时器，剩余时间: \(remainingSeconds)秒")
        } else {
            remainingSeconds = 0
            isTimerRunning = false
            print("BackgroundTimerManager: 计时器完成")
            // 只在后台计时管理器中发送通知，不直接调用timerCompleted
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TimerCompleted"), object: nil)
            }
        }
        
        // 额外检查：如果剩余时间为0但计时器还在运行，强制停止
        if remainingSeconds <= 0 && isTimerRunning {
            print("BackgroundTimerManager: 强制停止计时器（剩余时间为0）")
            isTimerRunning = false
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TimerCompleted"), object: nil)
            }
        }
    }
    
    // MARK: - 本地通知
    private func scheduleTimerNotification() {
        guard remainingSeconds > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = isWorkMode ? "专注时间" : "休息时间"
        content.body = "计时器正在运行中..."
        content.sound = .default
        
        // 设置通知在计时结束时触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(remainingSeconds), repeats: false)
        let request = UNNotificationRequest(identifier: "timer_notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("BackgroundTimerManager: 设置通知失败: \(error)")
            } else {
                print("BackgroundTimerManager: 计时器通知已设置，剩余时间: \(self.remainingSeconds)秒")
            }
        }
        
        timerNotification = content
    }
    
    private func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer_notification"])
        timerNotification = nil
        print("BackgroundTimerManager: 计时器通知已取消")
    }
    
    // MARK: - 计时完成处理
    private func timerCompleted() {
        print("BackgroundTimerManager: 计时器完成")
        
        // 防止重复调用
        if !isTimerRunning {
            print("BackgroundTimerManager: 计时器已完成，跳过重复调用")
            return
        }
        
        isTimerRunning = false
        
        // 发送通知
        let content = UNMutableNotificationContent()
        content.title = isWorkMode ? "专注完成！" : "休息结束"
        content.body = isWorkMode ? "恭喜你完成了专注时间！" : "休息时间结束，准备开始新的专注吧！"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "timer_completed", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
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
            
            // 更新计时器
            updateTimerInBackground()
            
            print("BackgroundTimerManager: 后台时间补偿: \(timeInBackground)秒")
        } else {
            // 如果没有backgroundTime，可能是从锁屏恢复，尝试从UserDefaults恢复状态
            restoreTimerState()
        }
        
        // 检查计时器是否已经完成
        if isTimerRunning && remainingSeconds <= 0 {
            print("BackgroundTimerManager: 检测到计时器已完成，发送完成通知")
            isTimerRunning = false
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TimerCompleted"), object: nil)
            }
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
        
        if wasRunning && savedRemainingSeconds > 0 {
            print("BackgroundTimerManager: 恢复计时器状态")
            
            isTimerRunning = true
            remainingSeconds = savedRemainingSeconds
            isWorkMode = savedIsWorkMode
            timerStartDate = Date(timeIntervalSince1970: savedStartDate)
            totalBackgroundTime = savedTotalBackgroundTime
            
            // 计算从上次保存到现在的时间
            let timeSinceLastSave = Date().timeIntervalSince1970 - lastSaveTime
            if timeSinceLastSave > 0 {
                totalBackgroundTime += timeSinceLastSave
                updateTimerInBackground()
            }
            
            print("BackgroundTimerManager: 恢复状态 - 剩余时间: \(remainingSeconds)秒")
        }
    }
    
    // MARK: - 获取当前状态
    func getCurrentStatus() -> (isRunning: Bool, remainingSeconds: Int, isWorkMode: Bool) {
        return (isTimerRunning, remainingSeconds, isWorkMode)
    }
}
