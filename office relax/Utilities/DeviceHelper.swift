import UIKit
import SwiftUI

// 设备类型枚举 - 添加iPad相关类型
enum DeviceType {
    case iPhone
    case iPad
    case iPadPro
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
    private init() {
        // 初始化时计算屏幕适配因子
        calculateAdaptationFactors()
    }
    
    // 屏幕适配因子 - 用于缩放整个UI以适应不同屏幕
    private(set) var verticalAdaptationFactor: CGFloat = 1.0
    private(set) var horizontalAdaptationFactor: CGFloat = 1.0
    
    // 计算屏幕适配因子
    private func calculateAdaptationFactors() {
        let screenSize = UIScreen.main.bounds.size
        
        // 设计基准高度（以iPhone 12为基准）
        let baseHeight: CGFloat = 844
        let baseWidth: CGFloat = 390
        
        // 计算适配因子
        let rawVerticalFactor = screenSize.height / baseHeight
        let rawHorizontalFactor = screenSize.width / baseWidth
        
        // 如果是iPad设备，进一步调整适配因子
        if deviceType != .iPhone {
            // iPad屏幕相对于设计稿较大，适当调整缩放系数
            verticalAdaptationFactor = min(rawVerticalFactor, 1.2)
            horizontalAdaptationFactor = min(rawHorizontalFactor, 1.2)
            
            // 如果屏幕高度比例过低，进一步缩小UI整体以确保全部显示
            if screenSize.height < 1000 {
                verticalAdaptationFactor = min(verticalAdaptationFactor, 0.9)
            }
        } else {
            // iPhone设备保持原比例
            verticalAdaptationFactor = rawVerticalFactor
            horizontalAdaptationFactor = rawHorizontalFactor
        }
        
        print("屏幕适配因子：垂直=\(verticalAdaptationFactor)，水平=\(horizontalAdaptationFactor)")
    }
    
    // 判断当前设备类型
    var deviceType: DeviceType {
        let device = UIDevice.current
        
        if device.userInterfaceIdiom == .phone {
            return .iPhone
        } else if device.userInterfaceIdiom == .pad {
            // 区分iPad和iPad Pro
            let screenSize = UIScreen.main.bounds.size
            let maxSide = max(screenSize.width, screenSize.height)
            
            if maxSide >= 1180 { // iPad Pro的大尺寸阈值
                return .iPadPro
            } else {
                return .iPad
            }
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
    
    // 根据设备类型调整大小，应用适配因子
    func adjustedSize(baseSize: CGFloat) -> CGFloat {
        let baseAdjustment: CGFloat
        
        switch deviceType {
        case .iPhone:
            baseAdjustment = baseSize
        case .iPad, .iPadPro:
            // iPad设备上略微放大UI元素以确保可点击
            baseAdjustment = baseSize * 1.2
        case .unknown:
            baseAdjustment = baseSize
        }
        
        // 应用水平适配因子
        return baseAdjustment * horizontalAdaptationFactor
    }
    
    // 根据设备类型获取内容边距
    var contentPadding: CGFloat {
        let basePadding: CGFloat
        
        switch deviceType {
        case .iPhone:
            basePadding = 20
        case .iPad, .iPadPro:
            // iPad上增加内边距，使UI更加美观
            basePadding = 30
        case .unknown:
            basePadding = 20
        }
        
        // 应用水平适配因子
        return basePadding * horizontalAdaptationFactor
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
        case .iPad:
            return "iPad"
        case .iPadPro:
            return "iPad Pro"
        case .unknown:
            return "Unknown Device"
        }
    }
    
    // 获取倒计时器在不同设备上的理想位置
    var timerPosition: (x: CGFloat, y: CGFloat) {
        switch deviceType {
        case .iPhone:
            return (0, 50)  // x轴偏移始终为0，保持在屏幕中心
        case .iPad:
            return (0, 10)  // x轴偏移始终为0，保持在屏幕中心
        case .iPadPro:
            return (0, 5)   // x轴偏移始终为0，保持在屏幕中心
        case .unknown:
            return (0, 50)  // x轴偏移始终为0，保持在屏幕中心
        }
    }
    
    // 获取倒计时器在不同设备上的理想缩放
    var timerScale: CGFloat {
        let baseScale: CGFloat
        
        switch deviceType {
        case .iPhone:
            baseScale = 2.5
        case .iPad, .iPadPro:
            baseScale = 3.0 // iPad上稍微放大
        case .unknown:
            baseScale = 2.5
        }
        
        // 如果是iPad设备并且屏幕较小，适当缩小
        if (deviceType == .iPad || deviceType == .iPadPro) && screenHeight < 1000 {
            return baseScale * 0.8
        }
        
        return baseScale
    }
    
    // 获取适合的垂直间距，用于调整主界面中元素的垂直布局
    var adaptiveVerticalSpacing: CGFloat {
        let baseSpacing: CGFloat = 100 // 基准间距
        
        // 对于iPad设备，根据屏幕高度调整
        if deviceType == .iPad || deviceType == .iPadPro {
            if screenHeight < 1000 {
                // 较小的iPad屏幕，减少间距
                return baseSpacing * 0.5 * verticalAdaptationFactor
            } else {
                // 较大的iPad屏幕，保持足够的间距
                return baseSpacing * 1.2 * verticalAdaptationFactor
            }
        }
        
        // iPhone设备使用基准间距
        return baseSpacing * verticalAdaptationFactor
    }
    
    // 获取底部按钮区域垂直间距
    var bottomButtonsSpacing: CGFloat {
        let baseSpacing: CGFloat = 40 // 基准间距
        
        if deviceType == .iPad || deviceType == .iPadPro {
            if screenHeight < 1000 {
                // 较小的iPad屏幕，减少间距
                return baseSpacing * 0.6 * verticalAdaptationFactor
            } else {
                // 较大的iPad屏幕，保持足够的间距
                return baseSpacing * 1.3 * verticalAdaptationFactor
            }
        }
        
        return baseSpacing * verticalAdaptationFactor
    }
    
    // 获取英雄区域高度
    var heroAreaHeight: CGFloat {
        let baseHeight: CGFloat
        
        switch deviceType {
        case .iPhone:
            baseHeight = 280
        case .iPad, .iPadPro:
            if screenHeight < 1000 {
                // 小屏幕iPad，稍微减小英雄区域
                baseHeight = 280
            } else {
                baseHeight = 320
            }
        case .unknown:
            baseHeight = 280
        }
        
        return baseHeight * verticalAdaptationFactor
    }
    
    // 打印当前设备信息用于调试
    func printDeviceInfo() {
        let screenSize = UIScreen.main.bounds
        print("设备类型: \(debugIdentifier)")
        print("屏幕尺寸: \(screenSize.width) x \(screenSize.height)")
        print("安全区域: 顶部=\(topInset), 底部=\(bottomInset)")
        print("适配因子: 垂直=\(verticalAdaptationFactor), 水平=\(horizontalAdaptationFactor)")
    }
}

// 扩展View以提供适配方法
extension View {
    // 自适应字体大小
    func adaptiveFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        let adjustedSize: CGFloat
        switch DeviceHelper.shared.deviceType {
        case .iPhone:
            adjustedSize = size
        case .iPad, .iPadPro:
            adjustedSize = size * 1.2 // iPad上字体放大
        case .unknown:
            adjustedSize = size
        }
        // 应用水平适配因子
        return self.font(.system(size: adjustedSize * DeviceHelper.shared.horizontalAdaptationFactor, weight: weight))
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
        // 对于iPad设备，限制最大宽度以避免UI过度拉伸
        if DeviceHelper.shared.deviceType == .iPad || DeviceHelper.shared.deviceType == .iPadPro {
            return self.frame(maxWidth: min(600, DeviceHelper.shared.screenWidth * 0.85))
                .frame(maxWidth: .infinity, alignment: .center) // 确保在屏幕中居中
        } else {
            return self.frame(maxWidth: .infinity)
                .frame(maxWidth: .infinity, alignment: .center) // 确保在屏幕中居中
        }
    }
    
    // 整体UI缩放适配函数
    func adaptiveScaling() -> some View {
        return self.scaleEffect(
            x: DeviceHelper.shared.horizontalAdaptationFactor,
            y: DeviceHelper.shared.verticalAdaptationFactor,
            anchor: .center
        )
    }
} 