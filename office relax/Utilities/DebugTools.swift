import SwiftUI

// 调试工具视图
struct DebugToolsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var animationManager = AnimationManager.shared
    @State private var message: String = ""
    @State private var showMessage: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("动画配置")) {
                    Button("重新加载动画配置") {
                        // 不要强制刷新动画，避免重置角色状态
                        // animationManager.reloadConfigurationAndRefresh() - 注释掉
                        
                        // 如果需要预加载特定动画，可以用以下替代
                        if ShopManager.shared.isItemEquipped(itemId: "effect_3") {
                            _ = AnimationManager.shared.getAnimationInfo(for: "hammer.run")
                            _ = AnimationManager.shared.getAnimationInfo(for: "hammer.attack")
                        } else {
                            _ = AnimationManager.shared.getAnimationInfo(for: "hero.run")
                            _ = AnimationManager.shared.getAnimationInfo(for: "hero.attack")
                        }
                        showAlert(message: "动画配置已重新加载")
                    }
                }
                
                Section(header: Text("信息")) {
                    Text("配置版本: \(animationManager.config?.version ?? "未加载")")
                    Text("已加载动画: \(animationManager.loadedAnimations.count)")
                    Text("已预加载帧: \(animationManager.preloadedFrames.count)")
                }
            }
            .navigationTitle("调试工具")
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showMessage) {
                Alert(
                    title: Text("通知"),
                    message: Text(message),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    private func showAlert(message: String) {
        self.message = message
        self.showMessage = true
    }
}

// 调试工具按钮
struct DebugToolsButton: View {
    @State private var showDebugTools = false
    
    var body: some View {
        Button(action: {
            showDebugTools = true
        }) {
            Image(systemName: "hammer.fill")
                .foregroundColor(.gray)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                )
        }
        .sheet(isPresented: $showDebugTools) {
            DebugToolsView()
        }
    }
} 