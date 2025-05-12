import SwiftUI
import StoreKit

struct GiftPackageView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var giftManager = GiftPackageManager.shared
    @ObservedObject private var shopManager = ShopManager.shared
    @ObservedObject private var audioManager = AudioManager.shared
    
    @State private var showConfirmation = false
    @State private var showSuccessAlert = false
    @State private var showRestoreFailedAlert = false
    @State private var restoreFailedMessage = ""
    @State private var isAnimating = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    
    // 保存格式化的价格
    @State private var displayPrice: String = ""
    
    var body: some View {
        ZStack {
            // 使用shop_bg.png作为整个界面的背景
            Image("shop_bg")
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .scaleEffect(1.2)
                .edgesIgnoringSafeArea(.all)
            
            // 使用礼包宣传页面图片作为内容背景
            Image("gift page")
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 1.05)
                .offset(y: 20)
            
            // 礼包内容
            VStack(spacing: 0) {
                // 使用空间推动内容到底部
                Spacer().frame(height: UIScreen.main.bounds.height * 0.22 + 20)
                
                Spacer()
                
                // 使用ZStack包装两个独立控制的部分
                ZStack {
                    // 包含内容部分
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Contained:")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 5)
                        
                        // 礼包内容列表
                        ForEach(giftManager.starterPackage.includedItems, id: \.self) { itemId in
                            if let item = shopManager.shopItems.first(where: { $0.id == itemId }) {
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    
                                    Text(item.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .offset(x: 30, y: -110) // 商品列表的偏移量：向右100像素，向上80像素
                    
                    // 添加商品描述文本 - 独立控制偏移
                    Text("equip them to make your focus scene more lovely!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.0)) // 亮黄色，更醒目
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(x: 40, y: -40) // 描述文本的偏移量：向右20像素，向上40像素
                }
                
                // 价格和购买按钮 - 向上移动60像素
                VStack(spacing: 15) {
                    // 检查礼包是否已购买，根据是否包含礼包中的任一物品判断
                    let isPackagePurchased = self.isPackagePurchased()
                    
                    Button(action: {
                        if !isPackagePurchased {
                            audioManager.playSound("click")
                            showConfirmation = true
                        }
                    }) {
                        HStack {
                            Text(isPackagePurchased ? "Purchased" : "Purchase")
                                .font(.system(size: 16, weight: .bold))
                            
                            if !isPackagePurchased {
                                // 使用StoreKit获取的价格或默认价格
                                Text(displayPrice.isEmpty ? giftManager.starterPackage.priceString : displayPrice)
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(width: 150)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: isPackagePurchased ? 
                                                  [Color.gray.opacity(0.6), Color.gray.opacity(0.8)] : 
                                                  [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                    }
                    .disabled(giftManager.isLoading || isPackagePurchased)
                    .overlay(
                        Group {
                            if giftManager.isLoading && !isPackagePurchased {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            }
                        }
                    )
                    
                    // 恢复购买按钮
                    if !isPackagePurchased {
                        Button(action: {
                            audioManager.playSound("click")
                            restorePackage()
                        }) {
                            Text("Restore")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .disabled(giftManager.isLoading)
                    }
                }
                .padding(.bottom, 30)
                .offset(y: -60) // 添加向上60像素的偏移
            }
            .frame(width: UIScreen.main.bounds.width * 0.9)
            
            // 新增：退出按钮使用ZStack绝对定位到右上角
            Button(action: {
                audioManager.playSound("click")
                presentationMode.wrappedValue.dismiss()
            }) {
                Image("quit")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
            .position(x: UIScreen.main.bounds.width - 40, y: 100)
            .zIndex(10)
            
            // 确认购买弹窗
            if showConfirmation {
                confirmationDialog
            }
            
            // 成功提示
            if showSuccessAlert {
                successAlert
            }
            
            // 恢复购买失败提示
            if showRestoreFailedAlert {
                restoreFailedAlert
            }
            
            // 错误提示
            if showErrorAlert {
                errorDialog
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        .onAppear {
            // 开始动画
            isAnimating = true
            
            // 从StoreKit更新价格显示
            updatePriceDisplay()
            
            // 添加通知监听，产品信息更新时刷新显示价格
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ProductsLoaded"), object: nil, queue: .main) { _ in
                self.updatePriceDisplay()
            }
        }
        .onDisappear {
            // 停止动画
            isAnimating = false
            
            // 移除通知监听
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ProductsLoaded"), object: nil)
        }
    }
    
    // 更新价格显示
    private func updatePriceDisplay() {
        if let product = giftManager.getProduct(for: giftManager.starterPackage.id) {
            displayPrice = giftManager.formattedPrice(for: product)
        }
    }
    
    // 确认购买弹窗
    var confirmationDialog: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showConfirmation = false
                }
            
            VStack(spacing: 20) {
                Text("Confirm")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Sure to purchase \(giftManager.starterPackage.name)")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if !displayPrice.isEmpty {
                    Text("Price: \(displayPrice)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        audioManager.playSound("click")
                        showConfirmation = false
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        audioManager.playSound("click")
                        showConfirmation = false
                        
                        // 处理购买
                        purchasePackage()
                    }) {
                        Text("Yes")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(30)
            .background(Color(red: 0.1, green: 0.1, blue: 0.3))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    // 成功提示
    var successAlert: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showSuccessAlert = false
                    presentationMode.wrappedValue.dismiss()
                }
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Purchase success!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Items in package are now in your item list.")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Button(action: {
                    audioManager.playSound("click")
                    showSuccessAlert = false
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("OK")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color(red: 0.1, green: 0.1, blue: 0.3))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    // 恢复购买失败提示
    var restoreFailedAlert: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showRestoreFailedAlert = false
                }
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Restore failed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text(restoreFailedMessage)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    audioManager.playSound("click")
                    showRestoreFailedAlert = false
                }) {
                    Text("OK")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color(red: 0.1, green: 0.1, blue: 0.3))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    // 错误提示对话框
    var errorDialog: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showErrorAlert = false
                }
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Error")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text(errorMessage)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    audioManager.playSound("click")
                    showErrorAlert = false
                }) {
                    Text("OK")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color(red: 0.1, green: 0.1, blue: 0.3))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    // 购买礼包
    private func purchasePackage() {
        giftManager.purchaseGiftPackage { success, message in
            if success {
                print("Purchase success")
                showSuccessAlert = true
            } else {
                print("Purchase failed: \(message)")
                errorMessage = message
                showErrorAlert = true
            }
        }
    }
    
    // 恢复购买
    private func restorePackage() {
        giftManager.restorePurchases { success, message in
            if success {
                showSuccessAlert = true
            } else {
                restoreFailedMessage = message
                showRestoreFailedAlert = true
            }
        }
    }
    
    // 检查礼包是否已购买
    private func isPackagePurchased() -> Bool {
        // 检查礼包中的任何物品是否已购买
        let shopManager = ShopManager.shared
        return shopManager.purchasedItems.contains { item in
            giftManager.starterPackage.includedItems.contains(item.id)
        }
    }
}

#Preview {
    GiftPackageView()
} 
