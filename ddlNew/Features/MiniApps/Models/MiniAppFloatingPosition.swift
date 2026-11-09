//
//  MiniAppFloatingPosition.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import Foundation
import CoreGraphics

/// 拖动和轻点共用一个触摸序列；一旦发生拖动，回到原点也不能变成点击。
struct MiniAppFloatingPosition {
    var rightEdge = true
    var restingY: CGFloat = 100
    private var origin: CGPoint?
    private var translation = CGSize.zero
    private var dragged = false

    func position(in size: CGSize) -> CGPoint {
        let base = origin ?? CGPoint(x: rightEdge ? size.width - 32 : 32, y: restingY)
        return CGPoint(x: min(max(32, base.x + translation.width), max(32, size.width - 32)),
                       y: min(max(56, base.y + translation.height), max(56, size.height - 120)))
    }

    mutating func update(translation value: CGSize, in size: CGSize) {
        if origin == nil { origin = position(in: size) }
        if hypot(value.width, value.height) >= 8 { dragged = true }
        if dragged { translation = value }
    }

    /// 返回是否为独立轻点。拖动中跟手，松手后才贴近边缘。
    mutating func finish(translation value: CGSize, in size: CGSize) -> Bool {
        update(translation: value, in: size)
        let point = position(in: size)
        let opens = !dragged
        rightEdge = point.x >= size.width / 2
        restingY = point.y
        cancel()
        return opens
    }

    mutating func cancel() { origin = nil; translation = .zero; dragged = false }
}
