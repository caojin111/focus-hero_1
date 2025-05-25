import SwiftUI
import AVKit

struct ItemPreviewView: View {
    let item: ShopItem
    let onPurchase: () -> Void
    let onDismiss: () -> Void
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var shopManager = ShopManager.shared
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var wasPlayingWorkMusic = false
    @State private var wasPlayingRelaxMusic = false
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    stopPreview()
                    onDismiss()
                }
            
            // 预览内容
            VStack(spacing: 20) {
                // 标题栏
                HStack {
                    Text(item.name)
                        .font(.title2)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        stopPreview()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                // 预览区域
                ZStack {
                    // 预览背景
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 300)
                    
                    // 根据商品类型显示不同的预览内容
                    Group {
                        switch item.type {
                        case .effect:
                            // 特效预览
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 250)
                        case .sound, .bgm:
                            // 音效/BGM预览
                            VStack {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        toggleAudio()
                                    }
                                Text(isPlaying ? "点击暂停" : "点击播放")
                                    .foregroundColor(.white)
                                    .padding(.top, 10)
                            }
                        case .background:
                            // 背景预览
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 250)
                        case .premium:
                            // 礼包预览
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 250)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 商品描述
                Text(item.description)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 按钮区域
                VStack(spacing: 12) {
                    // 如果已购买，显示装备/卸下按钮
                    if item.isPurchased ?? false {
                        let isEquipped = shopManager.isItemEquipped(itemId: item.id)
                        Button(action: {
                            if isEquipped {
                                shopManager.unequipItem(itemId: item.id)
                            } else {
                                shopManager.equipItem(itemId: item.id)
                            }
                            // 强制刷新UI
                            shopManager.objectWillChange.send()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isEquipped ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                Text(isEquipped ? "脱下" : "装备")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: 160)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(isEquipped ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(isEquipped ? Color.orange : Color.blue, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(ScaleButtonStyle()) // 添加按压效果
                    } else {
                        // 购买按钮
                        Button(action: {
                            stopPreview()
                            onPurchase()
                        }) {
                            HStack {
                                if let priceString = item.priceString {
                                    Text(priceString)
                                } else {
                                    Image("coin")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Text("\(item.price)")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(25)
                        }
                    }
                }
                .padding(.top, 20)
            }
            .frame(width: UIScreen.main.bounds.width * 0.9)
            .background(Color(white: 0.15).opacity(0.95))
            .cornerRadius(20)
            .padding()
        }
        .onAppear {
            // 只有预览音效和BGM时才需要停止当前播放的音频
            if item.type == .sound || item.type == .bgm {
                // 记录当前音乐播放状态
                wasPlayingWorkMusic = audioManager.isWorkMusicPlaying
                wasPlayingRelaxMusic = audioManager.isRelaxMusicPlaying
                
                // 停止所有当前播放的音频
                audioManager.stopAllAudio()
            }
        }
        .onDisappear {
            stopPreview()
            
            // 只有在之前停止了音频的情况下才需要恢复
            if item.type == .sound || item.type == .bgm {
                // 恢复之前的音乐播放状态
                if wasPlayingWorkMusic {
                    audioManager.resumeWorkMusic()
                }
                if wasPlayingRelaxMusic {
                    audioManager.resumeRelaxMusic()
                }
            }
        }
    }
    
    private func toggleAudio() {
        if isPlaying {
            stopPreview()
        } else {
            playPreview()
        }
    }
    
    private func playPreview() {
        // 根据商品类型播放对应的音频
        if item.type == .sound {
            switch item.id {
            case "sound_1":
                audioManager.playSound("shop_thunder")
                // 设置一个定时器在音效播放完成后重置状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // 假设音效长度为1秒
                    isPlaying = false
                }
                isPlaying = true
            case "sound_2":
                audioManager.playSound("shop_attack")
                // 设置一个定时器在音效播放完成后重置状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // 假设音效长度为0.5秒
                    isPlaying = false
                }
                isPlaying = true
            default:
                print("未知的音效ID: \(item.id)")
            }
        } else if item.type == .bgm {
            switch item.id {
            case "bgm_1":
                if let url = Bundle.main.url(forResource: "relax_music_2", withExtension: "mp3") {
                    do {
                        audioPlayer = try AVAudioPlayer(contentsOf: url)
                        audioPlayer?.volume = audioManager.musicVolume
                        audioPlayer?.delegate = AudioPlayerDelegate(onComplete: {
                            isPlaying = false
                        })
                        audioPlayer?.play()
                        isPlaying = true
                    } catch {
                        print("播放BGM预览失败: \(error)")
                    }
                }
            case "bgm_2":
                if let url = Bundle.main.url(forResource: "work_music_2", withExtension: "mp3") {
                    do {
                        audioPlayer = try AVAudioPlayer(contentsOf: url)
                        audioPlayer?.volume = audioManager.musicVolume
                        audioPlayer?.delegate = AudioPlayerDelegate(onComplete: {
                            isPlaying = false
                        })
                        audioPlayer?.play()
                        isPlaying = true
                    } catch {
                        print("播放BGM预览失败: \(error)")
                    }
                }
            default:
                print("未知的BGM ID: \(item.id)")
            }
        }
    }
    
    private func stopPreview() {
        if isPlaying {
            if item.type == .sound {
                switch item.id {
                case "sound_1":
                    audioManager.stopSound("shop_thunder")
                case "sound_2":
                    audioManager.stopSound("shop_attack")
                default:
                    break
                }
            } else if item.type == .bgm {
                audioPlayer?.stop()
                audioPlayer = nil
            }
            isPlaying = false
        }
    }
}

// 音频播放完成代理
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            DispatchQueue.main.async {
                self.onComplete()
            }
        }
    }
}

// 添加按压效果的按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
} 