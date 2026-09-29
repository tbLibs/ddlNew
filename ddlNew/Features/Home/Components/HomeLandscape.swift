//
//  HomeLandscape.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 原生矢量山景，作为活动卡的装饰；无需下载图片，也不依赖真实活动封面。
struct HomeLandscape: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                HomeTheme.heroBackground
                Circle().fill(HomeTheme.sun)
                    .frame(width: height * 0.32, height: height * 0.32)
                    .position(x: width * 0.76, y: height * 0.3)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.85))
                    path.addLine(to: CGPoint(x: width * 0.29, y: height * 0.12))
                    path.addLine(to: CGPoint(x: width * 0.54, y: height * 0.63))
                    path.addLine(to: CGPoint(x: width * 0.76, y: height * 0.36))
                    path.addLine(to: CGPoint(x: width, y: height * 0.8))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }.fill(HomeTheme.mountainBack)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.72))
                    path.addQuadCurve(to: CGPoint(x: width * 0.54, y: height * 0.69),
                                      control: CGPoint(x: width * 0.26, y: height * 0.3))
                    path.addQuadCurve(to: CGPoint(x: width, y: height * 0.6),
                                      control: CGPoint(x: width * 0.82, y: height * 0.95))
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }.fill(HomeTheme.mountainFront)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
