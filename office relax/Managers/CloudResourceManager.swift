//
//  CloudResourceManager.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import Foundation
import SwiftUI

class CloudResourceManager {
    static let shared = CloudResourceManager()
    
    // 云资源基础URL
    private let baseUrl = "https://lazygat.github.io/lazycat-resources"
    
    // 资源类型枚举
    enum ResourceType {
        case audio
        case animation
        case image
        
        var path: String {
            switch self {
            case .audio: return "audio"
            case .animation: return "animations"
            case .image: return "images"
            }
        }
    }
    
    // 缓存目录
    private var cacheDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("LazyCAT-Resources")
    }
    
    private init() {
        // 创建缓存目录
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("创建缓存目录失败: \(error)")
        }
    }
    
    // 获取资源URL
    func getResourceUrl(type: ResourceType, name: String) -> URL {
        return URL(string: "\(baseUrl)/\(type.path)/\(name)")!
    }
    
    // 加载资源
    func loadResource(type: ResourceType, name: String, completion: @escaping (Data?, Error?) -> Void) {
        // 检查本地缓存
        if let cachedData = checkCache(type: type, name: name) {
            completion(cachedData, nil)
            return
        }
        
        // 从云端加载
        let url = getResourceUrl(type: type, name: name)
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                // 保存到缓存
                self.saveToCache(type: type, name: name, data: data)
                completion(data, nil)
            } else {
                completion(nil, error ?? NSError(domain: "CloudResourceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "数据获取失败"]))
            }
        }.resume()
    }
    
    // 检查本地缓存
    private func checkCache(type: ResourceType, name: String) -> Data? {
        let cacheFile = cacheDirectory.appendingPathComponent("\(type.path)_\(name)")
        do {
            let data = try Data(contentsOf: cacheFile)
            return data
        } catch {
            return nil
        }
    }
    
    // 保存到本地缓存
    private func saveToCache(type: ResourceType, name: String, data: Data) {
        let cacheFile = cacheDirectory.appendingPathComponent("\(type.path)_\(name)")
        do {
            try data.write(to: cacheFile)
        } catch {
            print("缓存保存失败: \(error)")
        }
    }
}

// SwiftUI图片加载扩展
struct CloudImage: View {
    let imageName: String
    @State private var imageData: Data? = nil
    
    var body: some View {
        Group {
            if let data = imageData {
                Image(systemName: "photo") // 使用系统图标作为占位符
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        AsyncImage(url: URL(string: "data:image/png;base64,\(data.base64EncodedString())")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .failure(_):
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    )
            } else {
                ProgressView()
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        CloudResourceManager.shared.loadResource(type: .image, name: imageName) { data, error in
            DispatchQueue.main.async {
                if let imageData = data {
                    self.imageData = imageData
                }
            }
        }
    }
} 