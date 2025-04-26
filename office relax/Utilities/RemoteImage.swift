//
//  RemoteImage.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI

struct RemoteImage: View {
    let url: String
    let placeholder: String
    
    @State private var image: UIImage? = nil
    @State private var isLoading = true
    @State private var loadError = false
    @State private var retryCount = 0
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else if loadError {
                // 加载失败时显示占位图标和重试按钮
                VStack {
                    Image(systemName: placeholder)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .foregroundColor(.blue)
                    
                    if retryCount < 3 {
                        Button("重试") {
                            retryCount += 1
                            loadImage()
                        }
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    } else {
                        Text("加载失败")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    
                    #if DEBUG
                    // 仅在调试模式下显示错误信息
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 8))
                            .foregroundColor(.red)
                            .padding(4)
                            .multilineTextAlignment(.center)
                    }
                    #endif
                }
            } else if isLoading {
                // 加载中显示进度指示器
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        isLoading = true
        loadError = false
        errorMessage = ""
        
        // 首先尝试加载本地资源
        if let localImage = UIImage(named: url) {
            self.image = localImage
            self.isLoading = false
            print("从本地资源加载图片成功: \(url)")
            return
        }
        
        // 如果URL是空字符串或者无效URL，直接使用占位图
        guard !url.isEmpty, let imageURL = URL(string: url) else {
            // 如果URL无效，但不是为了加载本地资源，才报错
            if !url.isEmpty && UIImage(named: url) == nil {
                errorMessage = "无效URL或本地资源不存在: \(url)"
                isLoading = false
                loadError = true
            }
            return
        }
        
        // 如果不是http开头，认为是本地资源名称，不继续尝试网络加载
        if !url.hasPrefix("http") {
            errorMessage = "本地资源不存在: \(url)"
            isLoading = false
            loadError = true
            return
        }
        
        // 打印URL便于调试
        print("尝试从网络加载图片: \(url)")
        
        // 检查是否有缓存
        if let cachedImage = ImageCache.shared.get(forKey: url) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // 配置超时
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        
        // 创建自定义session
        let session = URLSession(configuration: config)
        
        // 从URL下载图片
        session.dataTask(with: imageURL) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    loadError = true
                    errorMessage = "网络错误: \(error.localizedDescription)"
                    print("图片加载错误: \(url) - \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    loadError = true
                    errorMessage = "非HTTP响应"
                    print("非HTTP响应: \(url)")
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    loadError = true
                    errorMessage = "HTTP错误: \(httpResponse.statusCode)"
                    print("HTTP错误 \(httpResponse.statusCode): \(url)")
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    loadError = true
                    errorMessage = "数据为空"
                    print("空数据: \(url)")
                    return
                }
                
                guard let downloadedImage = UIImage(data: data) else {
                    loadError = true
                    errorMessage = "无效图片数据"
                    print("无效图片数据: \(url)")
                    return
                }
                
                // 保存到缓存
                ImageCache.shared.set(downloadedImage, forKey: url)
                self.image = downloadedImage
                print("图片网络加载成功: \(url)")
            }
        }.resume()
    }
}

// 图片缓存
class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        // 设置缓存容量
        cache.countLimit = 100
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

// 本地图片加载组件 - 专门用于加载本地资源
struct LocalImage: View {
    let name: String
    let placeholder: String
    
    var body: some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: placeholder)
                .resizable()
                .scaledToFit()
                .padding()
                .foregroundColor(.blue)
        }
    }
}

#if os(macOS)
// 在macOS上定义UIImage为NSImage的别名
typealias UIImage = NSImage
#endif 