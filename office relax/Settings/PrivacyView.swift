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
    // 本地隐私政策HTML文件
    private let privacyPolicyFileName = "privacy_policy.html"
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .systemBackground
        
        // 加载本地HTML文件
        if let htmlPath = Bundle.main.path(forResource: privacyPolicyFileName, ofType: nil) {
            let url = URL(fileURLWithPath: htmlPath)
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            // 如果文件不存在，显示错误信息
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
                <h1>Unable to Load Privacy Policy</h1>
                <p>Sorry, the privacy policy could not be loaded. Please contact the app developer.</p>
                <p>Email: dxycj250@gmail.com</p>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
            
            // 记录错误，方便调试
            print("错误：本地隐私政策文件未找到 - \(privacyPolicyFileName)")
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