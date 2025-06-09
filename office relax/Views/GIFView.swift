import SwiftUI
import UIKit

struct GIFView: UIViewRepresentable {
    let gifName: String
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // 保持宽高比完整显示
        imageView.backgroundColor = .clear // 透明背景
        imageView.clipsToBounds = false // 不裁剪，保证完整显示
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        print("🔍 尝试加载GIF: \(gifName)")
        
        // 从完整路径中提取文件名
        let fileName = (gifName as NSString).lastPathComponent
        
        if let path = Bundle.main.path(forResource: fileName, ofType: "gif") {
            print("✅ 找到GIF文件路径: \(path)")
            
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                print("✅ 成功读取GIF数据，大小: \(data.count) bytes")
                
                if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                    let frameCount = CGImageSourceGetCount(source)
                    print("✅ GIF帧数: \(frameCount)")
                    
                    var images: [UIImage] = []
                    var totalDuration: TimeInterval = 0
                    
                    for i in 0..<frameCount {
                        if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                            let image = UIImage(cgImage: cgImage)
                            images.append(image)
                            
                            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                               let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                               let duration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                                totalDuration += duration
                            }
                        }
                    }
                    
                    print("✅ 成功创建动画，总帧数: \(images.count), 总时长: \(totalDuration)秒")
                    
                    let animation = UIImage.animatedImage(with: images, duration: totalDuration)
                    uiView.image = animation
                } else {
                    print("❌ 无法创建CGImageSource")
                }
            } else {
                print("❌ 无法读取GIF数据")
            }
        } else {
            print("❌ 未找到GIF文件: \(fileName)")
            // 打印所有可用的资源
            if let resourcePath = Bundle.main.resourcePath {
                print("📁 资源目录: \(resourcePath)")
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("📋 可用资源文件:")
                    files.forEach { print("   - \($0)") }
                } catch {
                    print("❌ 无法读取资源目录: \(error)")
                }
            }
        }
    }
} 