//
//  LingIMCallOptionsManager.swift
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/5.
//

import UIKit
import LiveKitClient
import WebRTC

@objcMembers public class LingIMCallOptionsManager: NSObject {
    // MARK: ******单例创建******
    
    // 禁止外部调用init初始化方法
    private override init() {
        super.init()
    }
    
    //带立即执行闭包初始化器的全局变量
    static var singleton: LingIMCallOptionsManager? = {
        var singleton = LingIMCallOptionsManager()
        return singleton
    }()
    
    @objc
    public class func sharedManager() -> LingIMCallOptionsManager {
        return singleton!
    }
    
    
    // MARK: <<<<<<******单例相关的方法/属性******>>>>>>
    
    // MARK: 配置连接参数
    @objc
    public func configConnectOptions() -> ConnectOptions {
        let connectOptions = ConnectOptions(
            autoSubscribe: true,//自动订阅为true则publishOnlyMode为nil
            rtcConfiguration: .liveKitDefault(),
            publishOnlyMode: nil,//"publish_\(UUID().uuidString)",//一个字符串来标识发布者(身份的唯一标识)
            protocolVersion: .v8
        )
        return connectOptions
    }
    
    
    // MARK: 配置房间参数
    @objc
    public func configRoomOptions() -> RoomOptions {
        let roomOptions = RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(
                position: .front,
                dimensions: .h1080_169,
                fps: 30
            ),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
                dimensions: .h1080_169,
                fps: 30,
                showCursor: true,
                useBroadcastExtension: true
            ),
            defaultAudioCaptureOptions: AudioCaptureOptions(
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: true,
                typingNoiseDetection: true,
                highpassFilter: true
            ),
            
            defaultVideoPublishOptions: VideoPublishOptions(
                simulcast: true//同步广播转播
            ),
            adaptiveStream: true,//自适应流
            dynacast: true,//动态广播
            stopLocalTrackOnUnpublish: true,//取消发布的时候停止本地轨道
            suspendLocalVideoTracksInBackground: true,//后台时，暂停本地视频的轨道
            reportStats: true//报告状态
        )
        return roomOptions
    }
    
    // MARK: 音频扬声器开启或关闭
    public func configAudioOutSpeaker(speaker: Bool) {
        AudioManager.shared.preferSpeakerOutput = speaker
    }
    
    // MARK: 获取房间远端流数组
    public func getRoomRemoteParticipants(room: Room) -> Array<Any> {
        return Array(room.remoteParticipants.values)
    }
    
}
