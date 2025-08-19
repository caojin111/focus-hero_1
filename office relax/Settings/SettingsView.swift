//
//  SettingsView.swift
//  office relax
//
//  Created by LazyG on 2025/4/21.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var userDataManager = UserDataManager.shared
    @StateObject private var audioManager = AudioManager.shared
    
    @AppStorage("settings_sound_enabled") private var soundEnabled = true
    @AppStorage("settings_sound_volume") private var soundVolume = 0.7
    
    @AppStorage("settings_vibration_enabled") private var vibrationEnabled = true
    
    @State private var workDuration: Double = 0
    @State private var relaxDuration: Double = 0
    
    // 隐私政策显示状态
    @State private var showPrivacyPolicy = false
    
    var body: some View {
        NavigationView {
            Form {
                // 时间设置部分
                Section(header: Text("Time setting")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Work duration")
                            Spacer()
                            Text("\(Int(workDuration)) minutes")
                                .foregroundColor(.gray)
                        }
                        Slider(value: $workDuration, in: 1...60, step: 1)
                            .onChange(of: workDuration) { newValue in
                                print("SettingsView: 工作时长更新为 \(Int(newValue)) 分钟")
                                userDataManager.updateWorkDuration(Int(newValue))
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Relax duration")
                            Spacer()
                            Text("\(Int(relaxDuration)) minutes")
                                .foregroundColor(.gray)
                        }
                        Slider(value: $relaxDuration, in: 5...30, step: 1)
                            .onChange(of: relaxDuration) { newValue in
                                print("SettingsView: 休息时长更新为 \(Int(newValue)) 分钟")
                                userDataManager.updateRelaxDuration(Int(newValue))
                            }
                    }
                }
                
                Section(header: Text("BGM")) {
                    Toggle("Enable BGM", isOn: $audioManager.isMusicEnabled)
                    
                    if audioManager.isMusicEnabled {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)
                            Slider(value: $audioManager.musicVolume, in: 0...1)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Sound")) {
                    Toggle("Enable sound", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { newValue in
                            // 通知AudioManager音效开关状态已更改
                            if !newValue {
                                // 如果禁用音效，停止所有正在播放的商店音效
                                audioManager.pauseAllSounds()
                            }
                        }
                    
                    if soundEnabled {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)
                            Slider(value: $soundVolume, in: 0...1)
                                .onChange(of: soundVolume) { newValue in
                                    // 当音效音量改变时，更新所有正在播放的商店音效音量
                                    audioManager.refreshAllSoundVolumes()
                                }
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Vibration")) {
                    Toggle("Enable vibration", isOn: $vibrationEnabled)
                }
                
                Section(header: Text("About")) {
                    // Support us按钮 - 新增在最上方
                    Button(action: {
                        // 关闭设置页面
                        presentationMode.wrappedValue.dismiss()
                        // 发送通知打开礼包界面
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenGiftPackage"),
                            object: nil
                        )
                    }) {
                        HStack {
                            Text("Support us")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("LazyCat")
                            .foregroundColor(.gray)
                    }
                    
                    // 隐私政策按钮
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #endif
            }
            .onAppear {
                // 加载初始值
                workDuration = Double(userDataManager.getWorkDuration())
                relaxDuration = Double(userDataManager.getRelaxDuration())
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyView()
            }
        }
    }
}

#Preview {
    SettingsView()
} 
