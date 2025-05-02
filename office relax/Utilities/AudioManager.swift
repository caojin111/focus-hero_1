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
    private let soundCooldown: TimeInterval = 3.0
    
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("无法设置音频会话: \(error.localizedDescription)")
        }
    }
    
    // 准备音频播放器
    private func prepareAudioPlayers() {
        // 加载工作模式音乐
        if let workMusicURL = Bundle.main.url(forResource: "work_music", withExtension: "mp3") {
            do {
                workModePlayer = try AVAudioPlayer(contentsOf: workMusicURL)
                workModePlayer?.numberOfLoops = -1 // 无限循环
                workModePlayer?.volume = musicVolume
                workModePlayer?.prepareToPlay()
            } catch {
                print("无法加载工作模式音乐: \(error.localizedDescription)")
            }
        } else {
            print("未找到工作模式音乐文件")
        }
        
        // 加载休息模式音乐
        if let relaxMusicURL = Bundle.main.url(forResource: "relax_music", withExtension: "mp3") {
            do {
                relaxModePlayer = try AVAudioPlayer(contentsOf: relaxMusicURL)
                relaxModePlayer?.numberOfLoops = -1 // 无限循环
                relaxModePlayer?.volume = musicVolume
                relaxModePlayer?.prepareToPlay()
            } catch {
                print("无法加载休息模式音乐: \(error.localizedDescription)")
            }
        } else {
            print("未找到休息模式音乐文件")
        }
    }
    
    // 播放工作模式音乐
    func playWorkMusic() {
        guard isMusicEnabled else { return }
        
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
        // 首先检查是否启用了音效
        // 所有商店音效(shop_开头)或特殊标记的音效都受音效开关控制
        if isShopSound(name) && !soundEnabled {
            print("音效已禁用，不播放: \(name)")
            return
        }
        
        // 检查音效冷却时间，任何音效3秒内只能播放一次
        if !canPlaySound(name) {
            print("音效 \(name) 在冷却中，跳过播放")
            return
        }
        
        // 记录音效播放时间
        lastSoundPlayTimes[name] = Date()
        
        // 如果已经有播放器在播放这个音效，先停止它
        if let existingPlayer = soundPlayers[name] {
            existingPlayer.stop()
            soundPlayers.removeValue(forKey: name)
        }
        
        // 加载音效文件
        guard let soundURL = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("未找到音效文件: \(name)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            
            // 设置音效音量
            // 商店音效使用系统音效音量设置，其他音效使用默认音量
            if isShopSound(name) {
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
} 