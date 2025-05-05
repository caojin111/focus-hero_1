import Foundation

class GoogleServiceInfoLoader {
    static let shared = GoogleServiceInfoLoader()
    
    func ensureGoogleServiceInfoAvailable() -> Bool {
        // 1. 检查 GoogleService-Info.plist 是否存在
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("⚠️ 未找到 GoogleService-Info.plist 文件")
            return false
        }
        
        // 2. 尝试读取文件内容
        guard let plistData = FileManager.default.contents(atPath: plistPath) else {
            print("⚠️ 无法读取 GoogleService-Info.plist 内容")
            return false
        }
        
        // 3. 将 plist 数据解析为字典
        guard let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            print("⚠️ 无法解析 GoogleService-Info.plist 内容")
            return false
        }
        
        // 4. 确认关键字段是否存在
        guard let appID = plistDict["GOOGLE_APP_ID"] as? String, !appID.isEmpty else {
            print("⚠️ GOOGLE_APP_ID 字段不存在或为空")
            return false
        }
        
        guard let gcmSenderID = plistDict["GCM_SENDER_ID"] as? String, !gcmSenderID.isEmpty else {
            print("⚠️ GCM_SENDER_ID 字段不存在或为空")
            return false
        }
        
        // 5. 将关键信息写入到 Info.plist 作为备份
        // 只在开发阶段调用此方法，作为紧急修复
        setInfoPlistValue(appID, forKey: "GOOGLE_APP_ID")
        
        if let apiKey = plistDict["API_KEY"] as? String, !apiKey.isEmpty {
            setInfoPlistValue(apiKey, forKey: "FIREBASE_API_KEY")
        }
        
        if let projectID = plistDict["PROJECT_ID"] as? String, !projectID.isEmpty {
            setInfoPlistValue(projectID, forKey: "FIREBASE_PROJECT_ID")
        }
        
        if let bundleID = plistDict["BUNDLE_ID"] as? String, !bundleID.isEmpty {
            setInfoPlistValue(bundleID, forKey: "FIREBASE_BUNDLE_ID")
        }
        
        print("✅ GoogleService-Info.plist 已校验成功：GOOGLE_APP_ID=\(appID), GCM_SENDER_ID=\(gcmSenderID)")
        return true
    }
    
    // 这只是一个诊断方法，不会真正修改 Info.plist
    private func setInfoPlistValue(_ value: String, forKey key: String) {
        // 在运行时无法修改 Info.plist，但可以诊断是否已包含这些值
        if let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            if infoPlistValue == value {
                print("✓ Info.plist 已包含正确的 \(key): \(value)")
            } else {
                print("⚠️ Info.plist 中 \(key) 值不匹配: 当前=\(infoPlistValue), 需要=\(value)")
            }
        } else {
            print("ℹ️ Info.plist 中未找到 \(key)，应为: \(value)")
        }
    }
} 