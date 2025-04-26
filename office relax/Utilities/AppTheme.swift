//
//  AppTheme.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI

// 应用主题 - 全局文字样式管理
struct AppTheme {
    // 标题样式
    static let titleFont = Font.customTitle()
    static let subtitleFont = Font.customTitle3()
    
    // 内容样式
    static let bodyFont = Font.customBody()
    static let smallFont = Font.customSubheadline()
    static let captionFont = Font.customCaption()
    
    // 按钮样式
    static let buttonFont = Font.customHeadline()
    
    // 应用主题文字样式
    struct TextStyle {
        // 主要标题样式
        static func title() -> some ViewModifier {
            return TextModifier(font: titleFont, color: .primary)
        }
        
        // 副标题样式
        static func subtitle() -> some ViewModifier {
            return TextModifier(font: subtitleFont, color: .primary)
        }
        
        // 正文样式
        static func body() -> some ViewModifier {
            return TextModifier(font: bodyFont, color: .primary)
        }
        
        // 小字样式
        static func small() -> some ViewModifier {
            return TextModifier(font: smallFont, color: .secondary)
        }
        
        // 按钮文字样式
        static func button() -> some ViewModifier {
            return TextModifier(font: buttonFont, color: .primary)
        }
    }
}

// 文字样式修饰符
struct TextModifier: ViewModifier {
    let font: Font
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

// SwiftUI文字样式扩展
extension View {
    func titleStyle() -> some View {
        self.modifier(AppTheme.TextStyle.title())
    }
    
    func subtitleStyle() -> some View {
        self.modifier(AppTheme.TextStyle.subtitle())
    }
    
    func bodyStyle() -> some View {
        self.modifier(AppTheme.TextStyle.body())
    }
    
    func smallStyle() -> some View {
        self.modifier(AppTheme.TextStyle.small())
    }
    
    func buttonStyle() -> some View {
        self.modifier(AppTheme.TextStyle.button())
    }
} 