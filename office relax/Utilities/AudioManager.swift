//
//  AudioManager.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import Foundation
import AVFoundation
import SwiftUI

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    // 背景音乐播放器
    private var workModePlayer: AVAudioPlayer?
    private var relaxModePlayer: AVAudioPlayer?
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    
    // 跟踪每个音效最后播放时间
    private var lastSoundPlayTimes: [String: Date] = [:]
    // 音效播放的最小间隔时间(秒)
    private let soundCooldown: TimeInterval = 2.0
    
    // 全局控制是否允许播放音效
    @Published var isSoundPlaybackEnabled: Bool = true
    
    // 音量设置 (0.0 - 1.0)
    @Published var musicVolume: Float = 0.5 {
        didSet {
            workModePlayer?.volume = musicVolume
            relaxModePlayer?.volume = musicVolume
        }
    }
    
    // 是否启用背景音乐
    @Published var isMusicEnabled: Bool = true {
        didSet {
            if isMusicEnabled {
                // 恢复之前的音乐播放
                if isWorkMode {
                    playWorkMusic()
                } else {
                    playRelaxMusic()
                }
            } else {
                // 停止所有音乐
                stopAllMusic()
            }
        }
    }
    
    // 缓存系统音效设置
    @AppStorage("settings_sound_enabled") private var soundEnabled = true
    @AppStorage("settings_sound_volume") private var soundVolume: Double = 0.7
    
    // 当前模式
    private var isWorkMode: Bool = true
    
    private init() {
        setupAudioSession()
        prepareAudioPlayers()
    }
    
    // 设置音频会话
    private func setupAudioSession() {
        do {
            // 设置音频会话为播放模式，支持后台运行
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 启用后台音频会话保活
            setupBackgroundAudioSession()
            
            // 立即开始播放静音音频以保持会话活跃
            startSilentAudioPlayback()
            
            print("AudioManager: 音频会话设置成功，已启用后台保活")
        } catch {
            print("无法设置音频会话: \(error.localizedDescription)")
        }
    }
    
    // 设置后台音频会话保活
    private func setupBackgroundAudioSession() {
        do {
            // 设置音频会话为播放模式，这是iOS允许后台运行的模式
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 注册音频会话中断通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            
            print("AudioManager: 后台音频会话保活已设置")
        } catch {
            print("AudioManager: 设置后台音频会话失败: \(error)")
        }
    }
    
    // 处理音频会话中断
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("AudioManager: 音频会话中断开始")
        case .ended:
            print("AudioManager: 音频会话中断结束")
            // 尝试重新激活音频会话
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                print("AudioManager: 音频会话已重新激活")
            } catch {
                print("AudioManager: 重新激活音频会话失败: \(error)")
            }
        @unknown default:
            break
        }
    }
    
    // 启用后台保活
    func enableBackgroundAudio() {
        print("AudioManager: 启用后台音频保活")
        setupBackgroundAudioSession()
    }
    
    // 静音音频播放器
    private var silentAudioPlayer: AVAudioPlayer?
    
    // 开始静音音频播放
    private func startSilentAudioPlayback() {
        // 创建1秒的静音音频数据
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let frameCount = Int(sampleRate * duration)
        
        var audioData = Data()
        for _ in 0..<frameCount {
            // 添加静音样本 (16位，单声道)
            let sample: Int16 = 0
            audioData.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Data($0) })
        }
        
        do {
            silentAudioPlayer = try AVAudioPlayer(data: audioData)
            silentAudioPlayer?.volume = 0.0
            silentAudioPlayer?.numberOfLoops = -1 // 无限循环
            silentAudioPlayer?.prepareToPlay()
            silentAudioPlayer?.play()
            
            print("AudioManager: 静音音频播放已启动，音量: 0.0")
        } catch {
            print("AudioManager: 创建静音音频播放器失败: \(error)")
        }
    }
    
    // 停止静音音频播放
    private func stopSilentAudioPlayback() {
        silentAudioPlayer?.stop()
        silentAudioPlayer = nil
        print("AudioManager: 静音音频播放已停止")
    }
    
    // 禁用后台保活
    func disableBackgroundAudio() {
        print("AudioManager: 禁用后台音频保活")
        stopSilentAudioPlayback()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("AudioManager: 禁用音频会话失败: \(error)")
        }
    }
    
    // 准备音频播放器
    private func prepareAudioPlayers() {
        // 检查是否装备了 bgm_2
        let shopManager = ShopManager.shared
        let isWorkBGM2Equipped = shopManager.equippedBGMs.contains(where: { $0.id == "bgm_2" })
        
        // 加载工作模式音乐
        let workMusicFile = isWorkBGM2Equipped ? "work_music_2" : "work_music"
        preparePlayer(forMode: .work, withFile: workMusicFile)
        
        // 检查是否装备了 bgm_1
        let isRelaxBGM1Equipped = shopManager.equippedBGMs.contains(where: { $0.id == "bgm_1" })
        
        // 加载休息模式音乐
        let relaxMusicFile = isRelaxBGM1Equipped ? "relax_music_2" : "relax_music"
        preparePlayer(forMode: .relax, withFile: relaxMusicFile)
    }
    
    // 定义播放模式枚举
    private enum PlayMode {
        case work
        case relax
    }
    
    // 准备特定模式的播放器
    private func preparePlayer(forMode mode: PlayMode, withFile fileName: String) {
        // 如果当前播放器正在播放，不要中断它
        switch mode {
        case .work:
            if workModePlayer?.isPlaying == true {
                return
            }
        case .relax:
            if relaxModePlayer?.isPlaying == true {
                return
            }
        }
        
        if let musicURL = Bundle.main.url(forResource: fileName, withExtension: "mp3") {
            do {
                switch mode {
                case .work:
                    workModePlayer = try AVAudioPlayer(contentsOf: musicURL)
                workModePlayer?.numberOfLoops = -1 // 无限循环
                workModePlayer?.volume = musicVolume
                workModePlayer?.prepareToPlay()
                case .relax:
                    relaxModePlayer = try AVAudioPlayer(contentsOf: musicURL)
                relaxModePlayer?.numberOfLoops = -1 // 无限循环
                relaxModePlayer?.volume = musicVolume
                relaxModePlayer?.prepareToPlay()
                }
                print("成功准备\(mode == .work ? "工作" : "休息")模式音乐: \(fileName)")
            } catch {
                print("无法加载\(mode == .work ? "工作" : "休息")模式音乐: \(error.localizedDescription)")
            }
        } else {
            print("未找到\(mode == .work ? "工作" : "休息")模式音乐文件: \(fileName)")
        }
    }
    
    // 播放工作模式音乐
    func playWorkMusic() {
        guard isMusicEnabled else { return }
        
        // 检查是否装备了 bgm_2，准备相应的播放器
        let shopManager = ShopManager.shared
        let isWorkBGM2Equipped = shopManager.equippedBGMs.contains(where: { $0.id == "bgm_2" })
        let workMusicFile = isWorkBGM2Equipped ? "work_music_2" : "work_music"
        
        // 如果当前播放器为空或使用了不同的音乐文件，则重新准备
        if workModePlayer == nil || workModePlayer?.url?.lastPathComponent != "\(workMusicFile).mp3" {
            preparePlayer(forMode: .work, withFile: workMusicFile)
        }
        
        // 渐弱停止休息音乐
        fadeOutAndStop(player: relaxModePlayer) {
            // 渐强开始工作音乐
            self.fadeInAndPlay(player: self.workModePlayer)
        }
        
        isWorkMode = true
    }
    
    // 播放休息模式音乐
    func playRelaxMusic() {
        guard isMusicEnabled else { return }
        
        // 检查是否装备了 bgm_1，准备相应的播放器
        let shopManager = ShopManager.shared
        let isRelaxBGM1Equipped = shopManager.equippedBGMs.contains(where: { $0.id == "bgm_1" })
        let relaxMusicFile = isRelaxBGM1Equipped ? "relax_music_2" : "relax_music"
        
        // 如果当前播放器为空或使用了不同的音乐文件，则重新准备
        if relaxModePlayer == nil || relaxModePlayer?.url?.lastPathComponent != "\(relaxMusicFile).mp3" {
            preparePlayer(forMode: .relax, withFile: relaxMusicFile)
        }
        
        // 渐弱停止工作音乐
        fadeOutAndStop(player: workModePlayer) {
            // 渐强开始休息音乐
            self.fadeInAndPlay(player: self.relaxModePlayer)
        }
        
        isWorkMode = false
    }
    
    // 停止所有音乐
    func stopAllMusic() {
        fadeOutAndStop(player: workModePlayer)
        fadeOutAndStop(player: relaxModePlayer)
    }
    
    // 暂停所有音乐
    func pauseAllMusic() {
        workModePlayer?.pause()
        relaxModePlayer?.pause()
    }
    
    // 暂停所有音效
    func pauseAllSounds() {
        for (_, player) in soundPlayers {
            player.pause()
        }
    }
    
    // 停止所有音频 - 包括音乐和音效
    func stopAllAudio() {
        // 停止所有背景音乐
        stopAllMusic()
        
        // 停止所有商店音效
        stopAllShopSounds()
        
        // 停止所有其他音效
        for (name, player) in soundPlayers {
            player.stop()
            soundPlayers.removeValue(forKey: name)
            print("停止音效: \(name)")
        }
        
        // 清空音效播放器字典
        soundPlayers.removeAll()
        
        print("已停止所有音频播放")
    }
    
    // 恢复工作模式音乐
    func resumeWorkMusic() {
        guard isMusicEnabled else { return }
        workModePlayer?.play()
    }
    
    // 恢复休息模式音乐
    func resumeRelaxMusic() {
        guard isMusicEnabled else { return }
        relaxModePlayer?.play()
    }
    
    // 恢复所有音效
    func resumeAllSounds() {
        guard soundEnabled else { return }
        
        for (_, player) in soundPlayers {
            player.play()
        }
    }
    
    // 渐弱停止音乐
    private func fadeOutAndStop(player: AVAudioPlayer?, completion: (() -> Void)? = nil) {
        guard let player = player, player.isPlaying else {
            completion?()
            return
        }
        
        let initialVolume = player.volume
        let fadeTime = 1.0 // 淡出时间（秒）
        let fadeSteps = 20 // 淡出步骤数
        let volumeStep = initialVolume / Float(fadeSteps)
        let timeStep = fadeTime / Double(fadeSteps)
        
        var currentStep = 0
        
        let fadeTimer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { timer in
            currentStep += 1
            
            if currentStep >= fadeSteps {
                player.stop()
                player.volume = initialVolume
                timer.invalidate()
                completion?()
            } else {
                player.volume = initialVolume - (volumeStep * Float(currentStep))
            }
        }
        
        RunLoop.main.add(fadeTimer, forMode: .common)
    }
    
    // 渐强开始音乐
    private func fadeInAndPlay(player: AVAudioPlayer?) {
        guard let player = player else { return }
        
        player.volume = 0.0
        player.play()
        
        let targetVolume = musicVolume
        let fadeTime = 1.0 // 淡入时间（秒）
        let fadeSteps = 20 // 淡入步骤数
        let volumeStep = targetVolume / Float(fadeSteps)
        let timeStep = fadeTime / Double(fadeSteps)
        
        var currentStep = 0
        
        let fadeTimer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { timer in
            currentStep += 1
            
            if currentStep >= fadeSteps {
                player.volume = targetVolume
                timer.invalidate()
            } else {
                player.volume = volumeStep * Float(currentStep)
            }
        }
        
        RunLoop.main.add(fadeTimer, forMode: .common)
    }
    
    // 检查音效是否是商店购买的音效
    private func isShopSound(_ name: String) -> Bool {
        // 检查名称是否以shop_开头
        return name.hasPrefix("shop_")
    }
    
    // 检查音效是否可以播放（满足冷却时间要求）
    private func canPlaySound(_ name: String) -> Bool {
        if let lastPlayTime = lastSoundPlayTimes[name] {
            let elapsedTime = Date().timeIntervalSince(lastPlayTime)
            if elapsedTime < soundCooldown {
                print("音效 \(name) 在冷却中，剩余: \(soundCooldown - elapsedTime)秒")
                return false
            }
        }
        return true
    }
    
    // 播放音效 - 受到系统设置控制
    func playSound(_ name: String) {
        // 首先检查是否启用了音效播放功能
        guard isSoundPlaybackEnabled else {
            print("全局音效播放已禁用，不播放: \(name)")
            return
        }
        
        // 首先检查是否启用了音效
        // 所有商店音效(shop_开头)或特殊标记的音效都受音效开关控制
        if isShopSound(name) && !soundEnabled {
            print("音效已禁用，不播放: \(name)")
            return
        }
        
        // 特殊处理：shop_attack是sound_2的音效，使用attack.mp3
        let soundFileName = name == "shop_attack" ? "attack" : name
        
        // 检查音效冷却时间，普通音效3秒内只能播放一次
        // shop_attack不受冷却时间限制
        if name != "shop_attack" && !canPlaySound(name) {
            print("音效 \(name) 在冷却中，跳过播放")
            return
        }
        
        // 记录音效播放时间（不记录shop_attack的播放时间，因为它不受冷却限制）
        if name != "shop_attack" {
            lastSoundPlayTimes[name] = Date()
        }
        
        // 如果已经有播放器在播放这个音效，先停止它
        if let existingPlayer = soundPlayers[name] {
            existingPlayer.stop()
            soundPlayers.removeValue(forKey: name)
        }
        
        // 加载音效文件
        guard let soundURL = Bundle.main.url(forResource: soundFileName, withExtension: "mp3") else {
            print("未找到音效文件: \(soundFileName)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            
            // 设置音效音量和播放速率
            // sound_1(shop_thunder)和sound_2(shop_attack)音效音量固定设置为0.5
            if name == "shop_thunder" || name == "shop_attack" {
                player.volume = 0.5
                
                // 为shop_attack(攻击音效)调整播放速率，使其更好地匹配hammer girl的攻击动画
                if name == "shop_attack" {
                    // 降低播放速率以匹配动画
                    player.rate = 0.85
                    print("播放音效: \(name)，使用固定0.5音量，降低播放速率为0.85")
                } else {
                    print("播放音效: \(name)，使用固定0.5音量")
                }
            }
            // 其他商店音效使用系统音效音量设置，其他音效使用默认音量
            else if isShopSound(name) {
                player.volume = Float(soundVolume)
                print("播放商店音效: \(name)，音量: \(soundVolume)")
            } else {
                player.volume = 0.8 // 默认音效音量
            }
            
            player.prepareToPlay()
            player.play()
            
            // 保存播放器引用
            soundPlayers[name] = player
            
            // 播放完成后清理
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) {
                self.soundPlayers.removeValue(forKey: name)
            }
        } catch {
            print("播放音效时出错: \(error.localizedDescription)")
        }
    }
    
    // 系统设置改变时刷新所有播放中的音效音量
    func refreshAllSoundVolumes() {
        for (name, player) in soundPlayers {
            if isShopSound(name) {
                player.volume = Float(soundVolume)
            }
        }
    }
    
    // 停止所有商店音效（主要用于场景切换）
    func stopAllShopSounds() {
        let shopSoundKeys = soundPlayers.keys.filter { isShopSound($0) }
        
        for key in shopSoundKeys {
            if let player = soundPlayers[key] {
                player.stop()
                soundPlayers.removeValue(forKey: key)
                print("停止商店音效: \(key)")
            }
        }
    }
    
    // 停止特定的音效
    func stopSound(_ name: String) {
        if let player = soundPlayers[name] {
            player.stop()
            soundPlayers.removeValue(forKey: name)
            print("停止音效: \(name)")
        }
    }
    
    // 清除某个特定音效的冷却
    func clearSoundCooldown(_ name: String) {
        lastSoundPlayTimes.removeValue(forKey: name)
    }
    
    // 清除所有音效冷却
    func clearAllSoundCooldowns() {
        lastSoundPlayTimes.removeAll()
    }
    
    // 在装备BGM时调用此方法刷新播放器
    func refreshBGMPlayers() {
        // 检查当前模式并刷新对应的播放器
        if isWorkMode {
            let shopManager = ShopManager.shared
            let isWorkBGM2Equipped = shopManager.equippedBGMs.contains(where: { $0.id == "bgm_2" })
            let workMusicFile = isWorkBGM2Equipped ? "work_music_2" : "work_music"
            
            // 停止当前播放的音乐
            fadeOutAndStop(player: workModePlayer) {
                // 重新准备并播放
                self.preparePlayer(forMode: .work, withFile: workMusicFile)
                self.fadeInAndPlay(player: self.workModePlayer)
            }
        } else {
            let shopManager = ShopManager.shared
            let isRelaxBGM1Equipped = shopManager.equippedBGMs.contains(where: { $0.id == "bgm_1" })
            let relaxMusicFile = isRelaxBGM1Equipped ? "relax_music_2" : "relax_music"
            
            // 停止当前播放的音乐
            fadeOutAndStop(player: relaxModePlayer) {
                // 重新准备并播放
                self.preparePlayer(forMode: .relax, withFile: relaxMusicFile)
                self.fadeInAndPlay(player: self.relaxModePlayer)
            }
        }
    }
    
    // 获取工作模式音乐播放状态
    var isWorkMusicPlaying: Bool {
        return workModePlayer?.isPlaying ?? false
    }
    
    // 获取休息模式音乐播放状态
    var isRelaxMusicPlaying: Bool {
        return relaxModePlayer?.isPlaying ?? false
    }
} 