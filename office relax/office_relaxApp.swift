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
