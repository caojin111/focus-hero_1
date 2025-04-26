import Foundation
import Network

class NetworkManager {
    static let shared = NetworkManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private(set) var isConnected: Bool = false
    private(set) var hasRequestedPermission: Bool = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    // 检查网络连接
    func checkNetworkConnection() -> Bool {
        return isConnected
    }
    
    // 请求网络权限（通过进行一个简单的网络请求）
    func requestNetworkPermission(completion: @escaping (Bool) -> Void) {
        // 设置一个超时定时器，避免长时间等待
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.hasRequestedPermission {
                self.hasRequestedPermission = true
                DispatchQueue.main.async {
                    completion(false)
                }
                print("网络权限请求超时")
            }
        }
        
        // 构建一个简单的网络请求来触发网络权限提示
        guard let url = URL(string: "https://www.apple.com") else {
            timeoutTimer.invalidate()
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            timeoutTimer.invalidate()
            guard let self = self else { return }
            
            self.hasRequestedPermission = true
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    completion(true)
                }
            } else {
                print("网络请求失败: \(error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
        task.resume()
    }
} 