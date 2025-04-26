//
//  AnimationManager.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI
import Combine

// 动画配置模型
struct AnimationConfig: Codable {
    var version: String
    var animations: [String: [String: AnimationDetails]]
    var scenes: [String: SceneConfig]
    var defaults: DefaultConfig
    
    struct AnimationDetails: Codable {
        var frames: [String]?
        var fps: Double?
        var scale: Double?
        var offset: OffsetConfig
        var flipped: Bool?
        var loop: Bool?
    }
    
    struct SizeConfig: Codable {
        var width: CGFloat
        var height: CGFloat
    }
    
    struct OffsetConfig: Codable {
        var x: CGFloat
        var y: CGFloat
    }
    
    struct SceneConfig: Codable {
        var hero_position: OffsetConfig
        var name_label: NameLabelConfig
        var active_animations: [String]
    }
    
    struct NameLabelConfig: Codable {
        var offset_y: CGFloat
        var spacing: CGFloat
    }
    
    struct DefaultConfig: Codable {
        var placeholder_icon: [String: String]
        var fallback_size: SizeConfig
    }
}

// 单个动画的详细信息
struct AnimationInfo {
    var name: String
    var category: String
    var frames: [UIImage]
    var fps: Double
    var scale: Double
    var offset: CGPoint
    var flipped: Bool
    var loop: Bool
    var placeholder: String
    
    init(name: String, category: String, config: AnimationConfig.AnimationDetails) {
        self.name = name
        self.category = category
        self.frames = []
        self.fps = config.fps ?? 5.0
        self.scale = config.scale ?? 1.0
        self.offset = CGPoint(x: config.offset.x, y: config.offset.y)
        self.flipped = config.flipped ?? false
        self.loop = config.loop ?? true
        self.placeholder = "questionmark" // 默认占位符，将在AnimationManager中设置
    }
}

// 动画管理器
class AnimationManager: ObservableObject {
    static let shared = AnimationManager()
    
    @Published var config: AnimationConfig?
    @Published private(set) var loadedAnimations: [String: AnimationInfo] = [:]
    @Published private(set) var preloadedFrames: [String: [UIImage]] = [:]
    
    private init() {
        loadConfig()
    }
    
    // 加载配置文件
    func loadConfig() {
        if let configURL = Bundle.main.url(forResource: "animation_config", withExtension: "json"),
           let configData = try? Data(contentsOf: configURL) {
            do {
                let decoder = JSONDecoder()
                config = try decoder.decode(AnimationConfig.self, from: configData)
                print("动画配置加载成功，版本: \(config?.version ?? "未知")")
                
                // 预处理所有动画信息
                processAllAnimations()
            } catch {
                print("动画配置解析失败: \(error)")
            }
        } else {
            print("未找到动画配置文件")
        }
    }
    
    // 重新加载配置并刷新所有动画
    func reloadConfigurationAndRefresh() {
        // 清空现有缓存
        loadedAnimations.removeAll()
        preloadedFrames.removeAll()
        
        // 重新加载配置
        loadConfig()
        
        // 通知观察者配置已更新
        objectWillChange.send()
        
        print("动画配置已重新加载和刷新")
    }
    
    // 处理所有动画信息
    private func processAllAnimations() {
        guard let config = config else { return }
        
        // 遍历所有动画分类
        for (category, animations) in config.animations {
            for (name, details) in animations {
                // 创建动画信息对象
                var animInfo = AnimationInfo(name: name, category: category, config: details)
                
                // 设置占位符
                animInfo.placeholder = config.defaults.placeholder_icon[category] ?? "questionmark"
                
                // 添加到已加载动画字典
                let animKey = "\(category).\(name)"
                loadedAnimations[animKey] = animInfo
                
                // 预加载动画帧
                if let frameNames = details.frames {
                    preloadFrames(for: animKey, frameNames: frameNames)
                }
            }
        }
    }
    
    // 预加载动画帧
    func preloadFrames(for animKey: String, frameNames: [String]) {
        var frames: [UIImage] = []
        
        for frameName in frameNames {
            if let image = UIImage(named: frameName) {
                // 高质量处理
                let size = image.size
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                image.draw(in: CGRect(origin: .zero, size: size))
                if let processedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    frames.append(processedImage)
                } else {
                    frames.append(image)
                }
                UIGraphicsEndImageContext()
            }
        }
        
        if !frames.isEmpty {
            preloadedFrames[animKey] = frames
            
            // 更新动画信息中的帧数组
            if var animInfo = loadedAnimations[animKey] {
                animInfo.frames = frames
                loadedAnimations[animKey] = animInfo
            }
        }
    }
    
    // 获取动画信息
    func getAnimationInfo(for key: String) -> AnimationInfo? {
        return loadedAnimations[key]
    }
    
    // 获取预加载的帧
    func getPreloadedFrames(for key: String) -> [UIImage] {
        return preloadedFrames[key] ?? []
    }
    
    // 获取场景配置
    func getSceneConfig(for scene: String) -> AnimationConfig.SceneConfig? {
        return config?.scenes[scene]
    }
    
    // 获取活动动画
    func getActiveAnimations(for scene: String) -> [AnimationInfo] {
        guard let sceneConfig = config?.scenes[scene],
              let activeKeys = sceneConfig.active_animations as? [String] else {
            return []
        }
        
        return activeKeys.compactMap { getAnimationInfo(for: $0) }
    }
    
    // 重新加载指定动画
    func reloadAnimation(for key: String) {
        let parts = key.split(separator: ".")
        guard parts.count == 2,
              let category = parts.first,
              let name = parts.last,
              let details = config?.animations[String(category)]?[String(name)],
              let frameNames = details.frames else {
            return
        }
        
        preloadFrames(for: key, frameNames: frameNames)
    }
}

// 高质量动画视图，从配置加载
struct ConfigurableAnimatedView: View {
    let animationKey: String
    let completionHandler: (() -> Void)?
    
    @StateObject private var manager = AnimationManager.shared
    @State private var hasStartedAnimation = false
    
    init(animationKey: String, completionHandler: (() -> Void)? = nil) {
        self.animationKey = animationKey
        self.completionHandler = completionHandler
    }
    
    var body: some View {
        Group {
            if let animInfo = manager.getAnimationInfo(for: animationKey),
               !animInfo.frames.isEmpty {
                HighQualityAnimatedImageView(
                    images: animInfo.frames,
                    fps: animInfo.fps,
                    isLooping: animInfo.loop,
                    playbackCompleted: completionHandler
                )
                .scaleEffect(x: animInfo.flipped ? -animInfo.scale : animInfo.scale, 
                             y: animInfo.scale)
                .offset(x: animInfo.offset.x, y: animInfo.offset.y)
                .animation(.easeInOut(duration: 0.2), value: animInfo.scale)
                .animation(.easeInOut(duration: 0.2), value: animInfo.offset)
            } else {
                // 占位符
                let placeholder = manager.getAnimationInfo(for: animationKey)?.placeholder ?? "questionmark"
                Image(systemName: placeholder)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundColor(.white)
                    .onAppear {
                        // 如果显示了占位符，尝试立即加载动画
                        manager.reloadAnimation(for: animationKey)
                    }
            }
        }
        .onAppear {
            // 预加载动画帧
            if manager.getPreloadedFrames(for: animationKey).isEmpty {
                manager.reloadAnimation(for: animationKey)
            }
            
            // 确保第一次出现时立即触发动画
            hasStartedAnimation = true
        }
        .onChange(of: animationKey) { _ in
            // 当动画Key变化时重新加载
            manager.reloadAnimation(for: animationKey)
        }
    }
} 