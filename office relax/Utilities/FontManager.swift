//
//  FontManager.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import Foundation
import UIKit
import SwiftUI

// 字体管理器：用于注册和管理应用中的自定义字体
class FontManager {
    static let shared = FontManager()
    
    // 支持的字体名称常量
    static let fibberishFontName = "Fibberish"
    
    // 自定义字体尺寸
    struct FontSize {
        static let large: CGFloat = 20
        static let medium: CGFloat = 16
        static let small: CGFloat = 14
        static let tiny: CGFloat = 12
    }
    
    // 在应用启动时注册所有自定义字体
    static func registerFonts() {
        registerFont(name: "fibberish", extension: "ttf")
    }
    
    // 注册单个字体文件
    private static func registerFont(name: String, extension: String) {
        guard let fontURL = Bundle.main.url(forResource: name, withExtension: `extension`) else {
            print("⚠️ 无法找到字体文件：\(name).\(`extension`)")
            return
        }
        
        guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL) else {
            print("⚠️ 无法加载字体数据：\(name).\(`extension`)")
            return
        }
        
        guard let font = CGFont(fontDataProvider) else {
            print("⚠️ 无法创建字体：\(name).\(`extension`)")
            return
        }
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            if let error = error?.takeRetainedValue() {
                print("⚠️ 注册字体失败：\(error.localizedDescription)")
            } else {
                print("⚠️ 注册字体失败，原因未知")
            }
            return
        }
        
        print("✅ 成功注册字体：\(name).\(`extension`)")
    }
    
    // 返回自定义字体，如果加载失败则返回后备字体
    static func fibberishFont(size: CGFloat) -> UIFont {
        if let font = UIFont(name: fibberishFontName, size: size) {
            return font
        } else {
            print("⚠️ 无法加载Fibberish字体，使用系统字体代替")
            return UIFont.systemFont(ofSize: size)
        }
    }
    
    // 检查字体是否已正确注册
    func checkFontAvailability() {
        for familyName in UIFont.familyNames.sorted() {
            print("字体家族: \(familyName)")
            for fontName in UIFont.fontNames(forFamilyName: familyName) {
                print("-- 字体: \(fontName)")
            }
        }
    }
    
    // 在使用前确认Fibberish字体是否可用
    func isFibberishFontAvailable() -> Bool {
        return UIFont.fontNames(forFamilyName: "Fibberish").count > 0
    }
}

// SwiftUI字体扩展
extension Font {
    // 创建Fibberish字体
    static func fibberish(size: CGFloat) -> Font {
        return Font.custom(FontManager.fibberishFontName, size: size, relativeTo: .body)
    }
    
    // 预定义尺寸的Fibberish字体
    static var fibberishLarge: Font {
        return fibberish(size: FontManager.FontSize.large)
    }
    
    static var fibberishMedium: Font {
        return fibberish(size: FontManager.FontSize.medium)
    }
    
    static var fibberishSmall: Font {
        return fibberish(size: FontManager.FontSize.small)
    }
    
    static var fibberishTiny: Font {
        return fibberish(size: FontManager.FontSize.tiny)
    }
}

// SwiftUI视图扩展，便于应用字体样式
extension View {
    // 应用Fibberish字体
    func fibberishFont(size: CGFloat) -> some View {
        self.font(.fibberish(size: size))
    }
    
    // 应用预定义尺寸的Fibberish字体
    func fibberishLargeFont() -> some View {
        self.font(.fibberishLarge)
    }
    
    func fibberishMediumFont() -> some View {
        self.font(.fibberishMedium)
    }
    
    func fibberishSmallFont() -> some View {
        self.font(.fibberishSmall)
    }
    
    func fibberishTinyFont() -> some View {
        self.font(.fibberishTiny)
    }
}

// 字体管理器 - 用于注册和应用自定义字体
enum CustomFont {
    static let regular = "fibberish"
    
    // 注册自定义字体
    static func registerFonts() {
        registerFont(bundle: Bundle.main, fontName: "fibberish", fontExtension: "ttf")
    }
    
    // 注册单个字体文件
    private static func registerFont(bundle: Bundle, fontName: String, fontExtension: String) {
        guard let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("无法加载字体: \(fontName).\(fontExtension)")
            return
        }
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            print("注册字体出错: \(error.debugDescription)")
        }
    }
}

// SwiftUI字体扩展 - 用于在视图中方便地使用自定义字体
extension Font {
    static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.custom(CustomFont.regular, size: size)
            .weight(weight)
    }
    
    // 替代系统字体的便捷方法
    static func customLargeTitle() -> Font {
        return custom(size: 34, weight: .bold)
    }
    
    static func customTitle() -> Font {
        return custom(size: 28, weight: .bold)
    }
    
    static func customTitle2() -> Font {
        return custom(size: 22, weight: .bold)
    }
    
    static func customTitle3() -> Font {
        return custom(size: 20, weight: .semibold)
    }
    
    static func customHeadline() -> Font {
        return custom(size: 17, weight: .semibold)
    }
    
    static func customBody() -> Font {
        return custom(size: 17)
    }
    
    static func customCallout() -> Font {
        return custom(size: 16)
    }
    
    static func customSubheadline() -> Font {
        return custom(size: 15)
    }
    
    static func customFootnote() -> Font {
        return custom(size: 13)
    }
    
    static func customCaption() -> Font {
        return custom(size: 12)
    }
}

// 应用于UIKit的字体扩展
extension UIFont {
    static func customFont(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        guard let font = UIFont(name: CustomFont.regular, size: size) else {
            print("无法加载自定义字体，使用系统字体代替")
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        return font
    }
}

// 字体类型枚举
enum AppFontType {
    case title1
    case title2
    case title3
    case body
    case small
    
    var size: CGFloat {
        switch self {
        case .title1: return 28
        case .title2: return 24
        case .title3: return 20
        case .body: return 16
        case .small: return 14
        }
    }
}

// 字体样式扩展
struct AppFont {
    static let fontName = "Fibberish"
    
    static func font(_ type: AppFontType) -> Font {
        if FontManager.shared.isFibberishFontAvailable() {
            return .custom(fontName, size: type.size)
        } else {
            // 如果自定义字体不可用，回退到系统字体
            switch type {
            case .title1: return .largeTitle
            case .title2: return .title
            case .title3: return .title2
            case .body: return .body
            case .small: return .footnote
            }
        }
    }
}

// 便捷的Text扩展
extension Text {
    func appFont(_ type: AppFontType) -> Text {
        return self.font(AppFont.font(type))
    }
}

// 视图修饰符
struct AppFontModifier: ViewModifier {
    let fontType: AppFontType
    
    func body(content: Content) -> some View {
        content.font(AppFont.font(fontType))
    }
}

extension View {
    func appFont(_ type: AppFontType) -> some View {
        self.modifier(AppFontModifier(fontType: type))
    }
} 