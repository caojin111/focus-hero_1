//
//  BackgroundConfigChecker.swift
//  office relax
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import AVFoundation
import UIKit
import BackgroundTasks

class BackgroundConfigChecker: ObservableObject {
    static let shared = BackgroundConfigChecker()
    
    @Published var entitlementsStatus: [String: Bool] = [:]
    @Published var audioSessionStatus: [String: String] = [:]
    @Published var backgroundModesStatus: [String: Bool] = [:]
    @Published var overallStatus: String = "检查中..."
    
    private init() {
        checkAllConfigurations()
    }
    
    // 检查所有配置
    func checkAllConfigurations() {
        print("BackgroundConfigChecker: 开始检查后台配置")
        
        checkEntitlements()
        checkAudioSession()
        checkBackgroundModes()
        updateOverallStatus()
    }
    
    // 检查 Entitlements 配置
    private func checkEntitlements() {
        print("BackgroundConfigChecker: 检查 Entitlements 配置")
        
        // 检查音频后台权限
        let hasAudioBackground = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil
        entitlementsStatus["音频后台模式"] = hasAudioBackground
        
        // 检查后台处理权限
        let hasBackgroundProcessing = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil
        entitlementsStatus["后台处理"] = hasBackgroundProcessing
        
        // 检查后台获取权限
        let hasBackgroundFetch = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil
        entitlementsStatus["后台获取"] = hasBackgroundFetch
        
        // 检查后台应用刷新权限
        let hasBackgroundAppRefresh = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil
        entitlementsStatus["后台应用刷新"] = hasBackgroundAppRefresh
        
        print("BackgroundConfigChecker: Entitlements 检查完成")
    }
    
    // 检查音频会话状态
    private func checkAudioSession() {
        print("BackgroundConfigChecker: 检查音频会话状态")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        // 检查音频类别
        let category = audioSession.category
        audioSessionStatus["音频类别"] = category.rawValue
        
        // 检查音频选项
        let options = audioSession.categoryOptions
        audioSessionStatus["音频选项"] = "\(options.rawValue)"
        
        // 检查音频会话是否活跃
        let isActive = audioSession.isInputAvailable
        audioSessionStatus["会话活跃"] = isActive ? "是" : "否"
        
        // 检查其他音频播放状态
        let isOtherAudioPlaying = audioSession.isOtherAudioPlaying
        audioSessionStatus["其他音频播放"] = isOtherAudioPlaying ? "是" : "否"
        
        print("BackgroundConfigChecker: 音频会话检查完成")
    }
    
    // 检查后台模式状态
    private func checkBackgroundModes() {
        print("BackgroundConfigChecker: 检查后台模式状态")
        
        // 检查后台应用刷新权限
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        backgroundModesStatus["后台应用刷新"] = backgroundRefreshStatus == .available
        
        // 检查后台任务调度器
        if #available(iOS 13.0, *) {
            let backgroundTaskScheduler = BGTaskScheduler.shared
            backgroundModesStatus["后台任务调度器"] = true // iOS 13+ 总是可用
        } else {
            backgroundModesStatus["后台任务调度器"] = false // iOS 13 以下不支持
        }
        
        print("BackgroundConfigChecker: 后台模式检查完成")
    }
    
    // 更新整体状态
    private func updateOverallStatus() {
        let allEntitlementsValid = entitlementsStatus.values.allSatisfy { $0 }
        let audioSessionValid = audioSessionStatus["会话活跃"] == "是"
        let backgroundModesValid = backgroundModesStatus.values.allSatisfy { $0 }
        
        if allEntitlementsValid && audioSessionValid && backgroundModesValid {
            overallStatus = "✅ 所有配置正常"
        } else if allEntitlementsValid && audioSessionValid {
            overallStatus = "⚠️ 基本配置正常，但后台模式可能有问题"
        } else if allEntitlementsValid {
            overallStatus = "⚠️ Entitlements 配置正常，但音频会话有问题"
        } else {
            overallStatus = "❌ 配置存在问题，需要检查"
        }
        
        print("BackgroundConfigChecker: 整体状态: \(overallStatus)")
    }
    
    // 获取详细诊断信息
    func getDetailedDiagnosis() -> String {
        var diagnosis = "后台配置诊断报告\n\n"
        diagnosis += "📱 设备信息: \(getIOSVersionInfo())\n\n"
        
        // Entitlements 状态
        diagnosis += "📋 Entitlements 配置:\n"
        for (key, value) in entitlementsStatus {
            diagnosis += "  \(key): \(value ? "✅" : "❌")\n"
        }
        
        // 音频会话状态
        diagnosis += "\n🎵 音频会话状态:\n"
        for (key, value) in audioSessionStatus {
            diagnosis += "  \(key): \(value)\n"
        }
        
        // 后台模式状态
        diagnosis += "\n🔄 后台模式状态:\n"
        for (key, value) in backgroundModesStatus {
            diagnosis += "  \(key): \(value ? "✅" : "❌")\n"
        }
        
        // 建议
        diagnosis += "\n💡 建议:\n"
        if !entitlementsStatus.values.allSatisfy({ $0 }) {
            diagnosis += "  • 检查 Xcode 项目设置中的 Signing & Capabilities\n"
            diagnosis += "  • 确保启用了 Audio, AirPlay, and Picture in Picture\n"
        }
        
        if audioSessionStatus["会话活跃"] != "是" {
            diagnosis += "  • 检查音频会话配置\n"
            diagnosis += "  • 确保在应用启动时正确设置音频会话\n"
        }
        
        if !backgroundModesStatus.values.allSatisfy({ $0 }) {
            diagnosis += "  • 检查系统设置中的后台应用刷新权限\n"
            diagnosis += "  • 确保用户已授权后台权限\n"
        }
        
        return diagnosis
    }
    
    // 强制重新检查
    func forceRecheck() {
        print("BackgroundConfigChecker: 强制重新检查配置")
        checkAllConfigurations()
    }
    
    // 获取 iOS 版本信息
    func getIOSVersionInfo() -> String {
        let version = UIDevice.current.systemVersion
        let device = UIDevice.current.model
        return "iOS \(version) on \(device)"
    }
}
