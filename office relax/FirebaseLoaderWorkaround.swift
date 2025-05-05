import Foundation
import FirebaseCore

class FirebaseLoaderWorkaround {
    static let shared = FirebaseLoaderWorkaround()
    private var configured = false
    
    func configureFirebase() {
        guard !configured else { return }
        
        // 尝试从资源中加载 GoogleService-Info.plist
        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let fileData = FileManager.default.contents(atPath: filePath) {
            
            // 尝试从文件数据解析配置
            do {
                let dictionary = try PropertyListSerialization.propertyList(
                    from: fileData,
                    options: [],
                    format: nil
                ) as? [String: Any]
                
                if let dict = dictionary,
                   let googleAppID = dict["GOOGLE_APP_ID"] as? String,
                   let gcmSenderID = dict["GCM_SENDER_ID"] as? String {
                    
                    let options = FirebaseOptions(googleAppID: googleAppID, gcmSenderID: gcmSenderID)
                    
                    // 设置其他必要属性
                    if let apiKey = dict["API_KEY"] as? String {
                        options.apiKey = apiKey
                    }
                    
                    if let projectID = dict["PROJECT_ID"] as? String {
                        options.projectID = projectID
                    }
                    
                    if let storageBucket = dict["STORAGE_BUCKET"] as? String {
                        options.storageBucket = storageBucket
                    }
                    
                    if let bundleID = dict["BUNDLE_ID"] as? String {
                        options.bundleID = bundleID
                    }
                    
                    FirebaseApp.configure(options: options)
                    print("Firebase已成功配置[从plist字典解析]")
                    configured = true
                    return
                }
            } catch {
                print("解析GoogleService-Info.plist出错: \(error)")
            }
        }
        
        // 如果上面的方法失败，使用完全手动配置
        let options = FirebaseOptions(googleAppID: "1:412096439505:ios:9cd869f4669ac00d0911f0", 
                                     gcmSenderID: "412096439505")
        options.apiKey = "AIzaSyBvzZlXT78qMfSgyOXeXT8meT6esRH8Fvw"
        options.projectID = "focus-hero-ea271"
        options.storageBucket = "focus-hero-ea271.firebasestorage.app"
        options.bundleID = "Lazycat.office-relax"
        
        FirebaseApp.configure(options: options)
        print("Firebase已成功手动配置[绕过plist]")
        
        // 标记为已配置，防止重复初始化
        configured = true
    }
} 