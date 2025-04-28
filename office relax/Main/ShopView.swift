import SwiftUI

struct ShopView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var shopManager = ShopManager.shared
    @ObservedObject private var userDataManager = UserDataManager.shared
    @StateObject private var audioManager = AudioManager.shared
    @State private var selectedType: ShopItem.ItemType? = nil
    @State private var selectedItem: ShopItem? = nil
    @State private var showPurchaseDialog = false
    @State private var showEquipDialog = false
    @State private var showUnequipDialog = false
    @State private var showErrorDialog = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    audioManager.playSound("click")
                    presentationMode.wrappedValue.dismiss()
                }
            
            // 商店主界面
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    // 返回按钮
                    Button(action: {
                        audioManager.playSound("click")
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // 金币显示
                    HStack(spacing: 8) {
                        Image("coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("\(userDataManager.userProfile.coins)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(20)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // 类型筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterButton(title: "全部", isSelected: selectedType == nil) {
                            audioManager.playSound("click")
                            selectedType = nil
                        }
                        
                        ForEach(ShopItem.ItemType.allCases, id: \.self) { type in
                            FilterButton(
                                title: getTypeTitle(type),
                                isSelected: selectedType == type
                            ) {
                                audioManager.playSound("click")
                                selectedType = type
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
                
                // 商品列表
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(filteredItems) { item in
                            ShopItemCard(
                                item: item,
                                isEquipped: shopManager.isItemEquipped(itemId: item.id),
                                action: {
                                    audioManager.playSound("click")
                                    handleItemTap(item)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.8)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            // 购买确认弹窗
            if showPurchaseDialog, let item = selectedItem {
                PurchaseDialog(
                    item: item,
                    onConfirm: {
                        audioManager.playSound("click")
                        handlePurchase(item)
                    },
                    onCancel: {
                        audioManager.playSound("click")
                        selectedItem = nil
                        showPurchaseDialog = false
                    }
                )
            }
            
            // 装备确认弹窗
            if showEquipDialog, let item = selectedItem {
                EquipDialog(
                    item: item,
                    onConfirm: {
                        audioManager.playSound("click")
                        shopManager.equipItem(itemId: item.id)
                        selectedItem = nil
                        showEquipDialog = false
                        shopManager.objectWillChange.send()
                    },
                    onCancel: {
                        audioManager.playSound("click")
                        selectedItem = nil
                        showEquipDialog = false
                    }
                )
            }
            
            // 卸载确认弹窗
            if showUnequipDialog, let item = selectedItem {
                UnequipDialog(
                    item: item,
                    onConfirm: {
                        audioManager.playSound("click")
                        shopManager.unequipItem(itemId: item.id)
                        selectedItem = nil
                        showUnequipDialog = false
                        shopManager.objectWillChange.send()
                    },
                    onCancel: {
                        audioManager.playSound("click")
                        selectedItem = nil
                        showUnequipDialog = false
                    }
                )
            }
            
            // 错误提示弹窗
            if showErrorDialog {
                ErrorDialog(
                    message: errorMessage,
                    onDismiss: {
                        audioManager.playSound("click")
                        showErrorDialog = false
                        errorMessage = ""
                    }
                )
            }
        }
    }
    
    private func handleItemTap(_ item: ShopItem) {
        selectedItem = item
        if item.isPurchased {
            if shopManager.isItemEquipped(itemId: item.id) {
                showUnequipDialog = true
            } else {
                showEquipDialog = true
            }
        } else {
            showPurchaseDialog = true
        }
    }
    
    private func handlePurchase(_ item: ShopItem) {
        let result = shopManager.purchaseItem(itemId: item.id)
        if result.success {
            selectedItem = nil
            showPurchaseDialog = false
            shopManager.objectWillChange.send()
            userDataManager.objectWillChange.send()
        } else {
            showPurchaseDialog = false
            errorMessage = "购买失败: \(result.errorCode)"
            showErrorDialog = true
        }
    }
    
    var filteredItems: [ShopItem] {
        if let type = selectedType {
            return shopManager.shopItems.filter { $0.type == type }
        }
        return shopManager.shopItems
    }
    
    func getTypeTitle(_ type: ShopItem.ItemType) -> String {
        switch type {
        case .effect:
            return "特效"
        case .sound:
            return "音效"
        case .bgm:
            return "BGM"
        case .background:
            return "背景"
        case .premium:
            return "付费"
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.3))
                .cornerRadius(20)
        }
    }
}

struct ShopItemCard: View {
    let item: ShopItem
    let isEquipped: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // 商品图片区域
                ZStack {
                    // 黑色底框
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .aspectRatio(1, contentMode: .fit)
                    
                    // 商品图片
                    LocalImage(name: item.imageName, placeholder: getPlaceholderImage())
                        .padding()
                    
                    // 已购买标记
                    if item.isPurchased {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                            .padding(8)
                            .background(Circle().fill(Color.black))
                            .position(x: 20, y: 20)
                    }
                }
                
                // 商品信息区域
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(item.description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        if item.isPurchased {
                            // 装备/卸载按钮
                            Text(isEquipped ? "卸载" : "装备")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(isEquipped ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3))
                                .cornerRadius(4)
                        } else {
                            // 价格和购买按钮
                            HStack(spacing: 4) {
                                Image("coin")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                Text("\(item.price)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Text("购买")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.3))
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func getPlaceholderImage() -> String {
        switch item.type {
        case .effect:
            return "sparkles"
        case .sound:
            return "speaker.wave.2"
        case .bgm:
            return "music.note"
        case .background:
            return "photo"
        case .premium:
            return "star.fill"
        }
    }
}

// 自定义弹窗组件
struct PurchaseDialog: View {
    let item: ShopItem
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("购买确认")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("确认花费 \(item.price) 金币购买 \(item.name)？")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("取消")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("购买")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct EquipDialog: View {
    let item: ShopItem
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("装备确认")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("确认装备 \(item.name)？")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("取消")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("确定")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct UnequipDialog: View {
    let item: ShopItem
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("卸载确认")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("确认卸载 \(item.name)？")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("取消")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("确定")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.3))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ErrorDialog: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("错误")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(message)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Button(action: onDismiss) {
                    Text("确定")
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(10)
                }
            }
            .padding(30)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    ShopView()
} 