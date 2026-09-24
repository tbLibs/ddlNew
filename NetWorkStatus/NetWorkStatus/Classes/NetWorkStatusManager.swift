//
//  NetWorkStatusManager.swift
//  NetWorkStatus
//
//  Created by phl on 2025/8/28.
//

import UIKit
import Network

@available(iOS 12.0, *)
// 支持oc调用
@objcMembers
public class NetWorkStatusManager: NSObject {
    
    deinit {
        stopMonitoring()
    }
    
    /// 单例对象
    public static let shared = NetWorkStatusManager()
    
    /// 网络状态监听通知名称
    public static let NetworkStatusChangedNotification = "NetworkStatusChangedNotification"
    
    /// 网络wifi
    public static let wifi = "WiFi"
    
    /// 网络移动数据
    public static let wwan = "WWAN"
    
    /// 网络未知
    public static let unknown = "Unknown"
    
    /// 网络监听系统类
    private let monitor: NWPathMonitor
    
    /// 监听网络队列，避免网络监听阻塞线程
    private let queue = DispatchQueue(label: "cim.network.monitor")
    
    /// 当前是否连接了
    private(set) var isConnected: Bool = false
    
    /// 当前是否为wifi
    private(set) var isWifi: Bool = false
    
    /// 当前是否为蜂窝数据
    private(set) var isCellular: Bool = false
    
    private override init() {
        monitor = NWPathMonitor()
        super.init()
    }
    
    /// 开始监听网络变化
    public func startMonitoring() {
        print("[网络检测] 开启网络监听")
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            var isConnected = (path.status == .satisfied)

            // wiredEthernet 有线以太网(电脑模拟器用)
            let isWifi: Bool = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
            let isCellular: Bool = path.usesInterfaceType(.cellular)
            
            self.isWifi = isWifi
            self.isCellular = isCellular
                        
            if isConnected {
                let hasRealInterface = self.isWifi || self.isCellular
                if (hasRealInterface) {
                    // 真正联网
                    print("[网络检测] 网络可用")
                    isConnected = true
                }else {
                    // 认为无网络（可能是 VPN / 飞行模式）
                    isConnected = false
                    print("[网络检测] 网络不可用")
                }
            }else {
                print("[网络检测] 网络不可用")
            }
            
            if (self.isConnected == isConnected) {
                print("[网络检测] 当前联网状态没有发生变化，不进行推送")
                return
            }
            self.isConnected = isConnected
            print("[网络检测] 当前联网状态发生变化，进行推送")
            
            let NetworkStatusChangedNotification = NSNotification.Name(NetWorkStatusManager.NetworkStatusChangedNotification)
            
            // 在主线程发送通知，避免 UI 线程安全问题
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NetworkStatusChangedNotification,
                    object: nil
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    /// 停止监听
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    /// 获取当前手机是否连接上了WiFi、4G
    /// - Returns: Bool
    public func getConnectStatus() -> Bool {
        return self.isConnected
    }
    
    /// 获取当前手机联网状态
    /// - Returns: "WiFi"、"WWAN"、”Unknown“
    public func getConnectType() -> String {
        if self.isWifi {
            return NetWorkStatusManager.wifi
        }else if self.isCellular {
            return NetWorkStatusManager.wwan
        }else {
            return NetWorkStatusManager.unknown
        }
    }
}
