//
//  PrivacyView.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI
import WebKit

struct PrivacyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            WebViewContainer()
                .navigationTitle("Privacy Policy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    // 在线隐私政策URL
    private let privacyPolicyURL = "https://docs.qq.com/doc/DZUxPZkJlR2NVSnNB?electronTabTitle=Privacy+Policy&isOfflineNewFileFlag=true"
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .systemBackground
        
        // 加载在线隐私政策URL
        if let url = URL(string: privacyPolicyURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            // 如果URL无效，显示错误信息
            let errorHTML = """
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body { font-family: -apple-system, sans-serif; padding: 20px; color: #333; }
                    h1 { color: #FF3B30; }
                </style>
            </head>
            <body>
                <h1>无法加载隐私政策</h1>
                <p>抱歉，隐私政策无法加载。请检查您的网络连接或联系应用开发者。</p>
                <p>邮箱: support@lazygeng.com</p>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
            
            // 记录错误，方便调试
            print("错误：无效的隐私政策URL")
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 更新时不需要额外操作
    }
}

#Preview {
    PrivacyView()
} 