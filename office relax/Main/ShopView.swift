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
    @State private var showPreview = false
    
    var body: some View {
        ZStack {
            // 全屏背景图片
            Image("shop_bg")
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .opacity(0.95)
                .edgesIgnoringSafeArea(.all)
            
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
                            .frame(width: 30, height: 30)
                        Text("\(userDataManager.userProfile.coins)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.6, blue: 0.2))
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
                        FilterButton(title: "All", isSelected: selectedType == nil) {
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
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            // 预览窗口
            if showPreview, let item = selectedItem {
                ItemPreviewView(
                    item: item,
                    onPurchase: {
                        showPurchaseDialog = true
                    },
                    onDismiss: {
                        showPreview = false
                        selectedItem = nil
                    }
                )
            }
            
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
                        
                        // 装备商品
                        shopManager.equipItem(itemId: item.id)
                        
                        // 特殊处理 BGM 类型或 sound_1
                        if item.type == .bgm {
                            // 确保 shopItems 中的状态被更新
                            if let shopIndex = shopManager.shopItems.firstIndex(where: { $0.id == item.id }) {
                                shopManager.shopItems[shopIndex].isEquipped = true
                            }
                            
                            // 确保 purchasedItems 中的状态被更新
                            if let purchasedIndex = shopManager.purchasedItems.firstIndex(where: { $0.id == item.id }) {
                                shopManager.purchasedItems[purchasedIndex].isEquipped = true
                            }
                            
                            // 保存装备状态
                            shopManager.saveEquippedItems()
                            
                            // 强制触发 UI 更新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                shopManager.objectWillChange.send()
                            }
                        }
                        else if item.id == "sound_1" {
                            // 为sound_1特别处理，确保它显示为已装备状态
                            print("特别处理sound_1装备状态")
                            
                            // 确保已装备的音效列表包含sound_1
                            if !shopManager.equippedSounds.contains(where: { $0.id == "sound_1" }) {
                                if let soundItem = shopManager.purchasedItems.first(where: { $0.id == "sound_1" }) {
                                    var updatedSoundItem = soundItem
                                    updatedSoundItem.isEquipped = true
                                    shopManager.equippedSounds.append(updatedSoundItem)
                                }
                            }
                            
                            // 确保所有商店项目中的sound_1显示为已装备
                            if let index = shopManager.shopItems.firstIndex(where: { $0.id == "sound_1" }) {
                                shopManager.shopItems[index].isEquipped = true
                            }
                            
                            // 保存装备状态
                            shopManager.saveEquippedItems()
                        }
                        
                        shopManager.objectWillChange.send()
                        
                        // 关闭对话框
                        selectedItem = nil
                        showEquipDialog = false
                        
                        // 刷新UI
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            shopManager.objectWillChange.send()
                        }
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
                        
                        // 特殊处理 BGM 类型
                        if item.type == .bgm {
                            // 确保 shopItems 中的状态被更新
                            if let shopIndex = shopManager.shopItems.firstIndex(where: { $0.id == item.id }) {
                                shopManager.shopItems[shopIndex].isEquipped = false
                            }
                            
                            // 确保 purchasedItems 中的状态被更新
                            if let purchasedIndex = shopManager.purchasedItems.firstIndex(where: { $0.id == item.id }) {
                                shopManager.purchasedItems[purchasedIndex].isEquipped = false
                            }
                            
                            // 保存装备状态
                            shopManager.saveEquippedItems()
                            
                            // 强制触发 UI 更新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                shopManager.objectWillChange.send()
                            }
                        }
                        
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
        .onAppear {
            shopManager.refreshItems()
            shopManager.verifyAndFixGiftPackageItems()
        }
        .onDisappear {
            // 确保离开商店时保存装备状态
            shopManager.saveEquippedItems()
        }
    }
    
    private func handleItemTap(_ item: ShopItem) {
        selectedItem = item
        
        // 检查是否为starter pack物品且未购买
        if (item.id == "effect_3" || item.id == "effect_6") && !(item.isPurchased ?? false) {
            NotificationCenter.default.post(name: NSNotification.Name("OpenGiftPackage"), object: nil)
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        // 显示预览窗口
        showPreview = true
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
            errorMessage = "Failed: \(result.errorCode)"
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
            return "Effect"
        case .sound:
            return "Sound"
        case .bgm:
            return "BGM"
        case .background:
            return "Backgrounds"
        case .premium:
            return "Package"
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
                    
                    // 商品图片 - 使用aspectRatio适应不同比例的图片
                    LocalImage(name: item.imageName, placeholder: getPlaceholderImage())
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.4, maxHeight: UIScreen.main.bounds.width * 0.4)
                        .padding(8)
                    
                    // 已购买标记
                    if item.isPurchased ?? false {
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
                        if item.isPurchased ?? false {
                            // 装备/卸载按钮
                            Text(isEquipped ? "Take off" : "Equip")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(isEquipped ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3))
                                .cornerRadius(4)
                        } else {
                            // 价格和购买按钮
                            if let priceString = item.priceString {
                                // 显示自定义价格文本
                                Text(priceString)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                // 显示金币价格
                                HStack(spacing: 4) {
                                    Image("coin")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                    Text("\(item.price)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(red: 0.95, green: 0.6, blue: 0.2))
                                }
                            }
                            
                            Spacer()
                            
                            Text("Buy")
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
                Text("Confirm")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Sure to spend")
                            .foregroundColor(.white)
                        Text("\(item.price)")
                            .foregroundColor(Color(red: 0.95, green: 0.6, blue: 0.2))
                            .fontWeight(.bold)
                    }
                    
                    Text("coins to buy \(item.name)?")
                        .foregroundColor(.white)
                }
                .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("Buy")
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
                Text("Confirm")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Sure to equip \(item.name)?")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("Yes")
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
                Text("Confirm")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Sure to take off \(item.name)?")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("Yes")
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
                Text("Wrong")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(message)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Button(action: onDismiss) {
                    Text("Yes")
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
