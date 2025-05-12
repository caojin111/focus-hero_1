import UIKit
import SwiftUI

// 设备类型枚举 - 移除iPad相关
enum DeviceType {
    case iPhone
    case unknown
}

// 设备方向枚举
enum DeviceOrientation {
    case portrait
    case landscape
}

// 设备屏幕尺寸辅助类
class DeviceHelper {
    // 单例模式
    static let shared = DeviceHelper()
    
    // 私有初始化，防止外部创建实例
    private init() {}
    
    // 判断当前设备类型
    var deviceType: DeviceType {
        let device = UIDevice.current
        
        if device.userInterfaceIdiom == .phone {
            return .iPhone
        }
        
        return .unknown
    }
    
    // 获取当前设备方向
    var orientation: DeviceOrientation {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let orientation = windowScene?.interfaceOrientation else {
            return .portrait
        }
        
        return orientation.isPortrait ? .portrait : .landscape
    }
    
    // 根据设备类型调整大小
    func adjustedSize(baseSize: CGFloat) -> CGFloat {
        return baseSize
    }
    
    // 根据设备类型获取内容边距
    var contentPadding: CGFloat {
        return 20
    }
    
    // 获取屏幕宽度
    var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    // 获取屏幕高度
    var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    // 获取UI元素垂直安全区域 - 用于适配全面屏设备
    var verticalSafeArea: (top: CGFloat, bottom: CGFloat) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return (0, 0)
        }
        let safeArea = window.safeAreaInsets
        return (safeArea.top, safeArea.bottom)
    }
    
    // 获取顶部状态栏高度
    var topInset: CGFloat {
        return verticalSafeArea.top
    }
    
    // 获取底部安全区域高度
    var bottomInset: CGFloat {
        return verticalSafeArea.bottom
    }
    
    // 添加调试功能 - 返回设备类型描述
    var debugIdentifier: String {
        switch deviceType {
        case .iPhone:
            return "iPhone"
        case .unknown:
            return "Unknown Device"
        }
    }
    
    // 打印当前设备信息用于调试
    func printDeviceInfo() {
        let screenSize = UIScreen.main.bounds
        print("设备类型: \(debugIdentifier)")
        print("屏幕尺寸: \(screenSize.width) x \(screenSize.height)")
        print("安全区域: 顶部=\(topInset), 底部=\(bottomInset)")
    }
}

// 扩展View以提供适配方法
extension View {
    // 自适应字体大小
    func adaptiveFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        return self.font(.system(size: size, weight: weight))
    }
    
    // 添加自适应顶部安全区域边距
    func adaptiveTopSafeArea() -> some View {
        let topInset = DeviceHelper.shared.topInset
        return self.padding(.top, topInset)
    }
    
    // 添加自适应底部安全区域边距
    func adaptiveBottomSafeArea() -> some View {
        let bottomInset = DeviceHelper.shared.bottomInset
        return self.padding(.bottom, bottomInset)
    }
    
    // 自适应最大宽度
    func adaptiveMaxWidth() -> some View {
        return self.frame(maxWidth: .infinity)
            .frame(maxWidth: .infinity, alignment: .center) // 确保在屏幕中居中
    }
} 