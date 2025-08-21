//
//  office_relaxApp.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI
import UIKit
import Network
import StoreKit
import FirebaseCore
import FirebaseCrashlytics
import BackgroundTasks

// 添加Info.plist描述
/*
 Info.plist 需要添加以下内容:
 <key>NSAppTransportSecurity</key>
 <dict>
     <key>NSAllowsArbitraryLoads</key>
     <true/>
 </dict>
 */

// 应用委托用于初始化和配置
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 诊断 GoogleService-Info.plist 文件
        let googleServiceInfoAvailable = GoogleServiceInfoLoader.shared.ensureGoogleServiceInfoAvailable()
        print("GoogleService-Info.plist 可用性: \(googleServiceInfoAvailable)")
        
        // 使用绕过方案配置 Firebase
        FirebaseLoaderWorkaround.shared.configureFirebase()
        
        // 尝试确认 Firebase 是否已成功配置
        if let app = FirebaseApp.app() {
            print("Firebase 确认已配置成功: \(app.name)")
        } else {
            print("⚠️ 警告: Firebase 似乎未成功配置")
        }
        
        // 配置 Crashlytics
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        
        // 记录一个测试事件到 Crashlytics
        Crashlytics.crashlytics().log("应用启动")
        
        // 添加测试用户信息
        Crashlytics.crashlytics().setCustomValue("测试模式", forKey: "应用状态")
        
        // 注册自定义字体
        FontManager.registerFonts()
        
        // 打印重要的调试信息
        print("===== App启动 =====")
        print("Bundle Identifier: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        
        // 检查Info.plist中的设置
        if let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any] {
            print("网络安全设置已存在：\(ats)")
        } else {
            print("警告：网络安全设置(NSAppTransportSecurity)不存在")
            
            // 手动配置App Transport Security (仅用于调试)
            #if DEBUG
            print("调试模式：尝试手动配置网络安全设置")
            // 注意：这只是一个示范，实际上无法在运行时动态修改Info.plist
            #endif
        }
        
        // 由于手动修改Info.plist不可行，我们为用户提供详细的错误诊断
        let testURLs = [
            "https://raw.githubusercontent.com/caojin111/lazycat-resources/main/images/items/accessory_glasses.png",
            "https://www.apple.com"
        ]
        
        print("测试网络连接...")
        for urlString in testURLs {
            testNetworkConnection(urlString: urlString)
        }
        
        // 在应用启动时立即初始化网络管理器
        _ = NetworkManager.shared
        
        // 加载App内购商品信息
        _ = GiftPackageManager.shared
        
        // 初始化后台计时管理器
        _ = BackgroundTimerManager.shared
        
        // 检查通知权限
        BackgroundTimerManager.shared.checkNotificationPermission()
        
        // 立即启动音频保活（确保后台权限生效）
        BackgroundTimerManager.shared.startAudioKeepAlive()
        
        // 检查后台配置
        _ = BackgroundConfigChecker.shared
        
        // 请求后台刷新权限
        requestBackgroundRefreshPermission()
        
        // 启用后台获取（使用新的 BackgroundTasks 框架）
        // application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum) // 已废弃
        
        // 立即检查权限状态并打印日志
        print("AppDelegate: 应用启动完成，权限状态检查:")
        print("- 后台刷新状态: \(UIApplication.shared.backgroundRefreshStatus.rawValue)")
        print("- 后台模式配置: \(Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") ?? "未配置")")
        
        return true
    }
    
    // 限制应用程序的界面方向
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // 只支持竖屏
        return .portrait
    }
    
    private func testNetworkConnection(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("无效URL: \(urlString)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("网络测试失败(\(urlString)): \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("网络测试失败(\(urlString)): 非HTTP响应")
                return
            }
            
            print("网络测试结果(\(urlString)): HTTP \(httpResponse.statusCode)")
            
            if let data = data {
                print("  - 收到数据大小: \(data.count) bytes")
            } else {
                print("  - 无返回数据")
            }
        }
        task.resume()
    }
    
    // 请求后台刷新权限
    private func requestBackgroundRefreshPermission() {
        print("AppDelegate: 开始请求后台刷新权限")
        
        // 首先检查当前的后台刷新状态
        let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        print("AppDelegate: 当前后台刷新状态: \(backgroundRefreshStatus.rawValue)")
        
        switch backgroundRefreshStatus {
        case .available:
            print("AppDelegate: 后台应用刷新已启用")
            // 设置后台任务
            BackgroundTimerManager.shared.setupBackgroundTasksIfNeeded()
        case .denied:
            print("AppDelegate: 后台应用刷新被拒绝")
        case .restricted:
            print("AppDelegate: 后台应用刷新受限制")
        @unknown default:
            print("AppDelegate: 后台应用刷新状态未知")
        }
        
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("AppDelegate: 通知权限已获取")
                    
                    // 再次检查后台应用刷新权限
                    let currentStatus = UIApplication.shared.backgroundRefreshStatus
                    print("AppDelegate: 通知权限获取后，后台刷新状态: \(currentStatus.rawValue)")
                    
                    if currentStatus == .available {
                        print("AppDelegate: 后台应用刷新权限已可用")
                        // 设置后台任务
                        BackgroundTimerManager.shared.setupBackgroundTasksIfNeeded()
                    } else {
                        print("AppDelegate: 后台应用刷新权限不可用，状态: \(currentStatus.rawValue)")
                        print("AppDelegate: 提示用户手动开启后台应用刷新权限")
                    }
                } else {
                    print("AppDelegate: 通知权限被拒绝: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
}

@main
struct office_relaxApp: App {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    
    // 注册应用委托
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}
