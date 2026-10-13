//
//  KingfisherLayoutStub.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIKit

infix operator |> : AdditionPrecedence
/// 宿主图片处理链只保留类型形状，不处理用户资源。
public func |> <A, B>(left: A, right: B) -> Int { 0 }
public struct DownsamplingImageProcessor {
    /// 生产下采样尺寸仅用于编译，宿主不声明真实图片性能通过。
    public init(size: CGSize) {}
}

/// 宿主仅保留生产图片视图的布局合同，不访问远程资源，不声明下载通过。
public struct KFImage: View {
    /// 所有图片使用匿名占位，隔离测试不得读取真实头像地址。
    public init(_ url: URL?) {}
    /// 接口占位让生产视图原样编译，下载行为不属于本宿主证据。
    public func downloader<T>(_ value: T) -> Self { self }
    /// 生产旧图片处理器在宿主仅保留布局，不进行解密或下载。
    public func setProcessor<T>(_ value: T) -> Self { self }
    /// 保留占位合同，截图明确只验证布局。
    public func placeholder<V: View>(@ViewBuilder _ content: () -> V) -> Self { self }
    /// 图片尺寸仍由生产frame和clipShape决定。
    public func resizable() -> Self { self }
    /// 缓存序列化形状占位，不记录远程或用户资源。
    public func serialize<T>(by value: T) -> Self { self }
    /// 同步磁盘开关只满足编译，不执行磁盘下载。
    public func loadDiskFileSynchronously(_ value: Bool) -> Self { self }
    /// 取消合同形状占位，不声明真实网络取消通过。
    public func cancelOnDisappear(_ value: Bool) -> Self { self }
    /// 失败视图只保留布局形状。
    public func onFailureView<V: View>(@ViewBuilder _ content: () -> V) -> Self { self }
    public var body: some View { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary) }
}

/// 动画图片仅保留真实生产视图编译合同，宿主不提供GIF播放证明。
public struct KFAnimatedImage: View {
    /// 地址不被读取或访问。
    public init(_ url: URL?) {}
    /// 下载器仅保留类型形状。
    public func downloader<T>(_ value: T) -> Self { self }
    /// 处理器仅保留类型形状。
    public func setProcessor<T>(_ value: T) -> Self { self }
    /// 缓存序列化仅保留类型形状。
    public func serialize<T>(by value: T) -> Self { self }
    /// 不执行磁盘资源读取。
    public func loadDiskFileSynchronously(_ value: Bool) -> Self { self }
    /// 生命周期取消只保留接口。
    public func cancelOnDisappear(_ value: Bool) -> Self { self }
    /// 动画帧清理只保留接口。
    public func purgeFramesOnBackground(_ value: Bool) -> Self { self }
    /// 配置匿名UIView形状，不使用实际用户图片。
    public func configure(_ body: (LayoutAnimatedImageView) -> Void) -> Self { body(LayoutAnimatedImageView()); return self }
    /// 占位保留接口。
    public func placeholder<V: View>(@ViewBuilder _ content: () -> V) -> Self { self }
    /// 失败回退保留接口。
    public func onFailureView<V: View>(@ViewBuilder _ content: () -> V) -> Self { self }
    public var body: some View { Image(systemName: "photo").resizable() }
}
public final class LayoutAnimatedImageView: UIView {
    public var framePreloadCount = 0
    public var needsPrescaling = false
}
