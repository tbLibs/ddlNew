//
//  ChatVoiceRecordingMeter.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

import SwiftUI

/// 录音器真实电平驱动七条波形；不另建常驻动画定时器。
struct ChatVoiceRecordingMeter: View {
    let level: Double
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<7) { index in
                    Capsule().fill(.white)
                        .frame(width: 3, height: max(3, geometry.size.height * level * [0.4, 0.7, 0.9, 1, 0.8, 0.6, 0.35][index]))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityHidden(true)
    }
}
