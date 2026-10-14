//
//  ChatLocationDetailView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import MapKit
import UIAdapter

struct ChatLocationDetailView: View {
    let message: ChatMessageRecord
    @State private var region: MKCoordinateRegion
    private let coordinate: CLLocationCoordinate2D?

    /// 历史位置只读，校验经纬度后展示，不申请定位或发送新位置。
    init(message: ChatMessageRecord) {
        self.message = message
        if let lat = Double(message.latitude), let lon = Double(message.longitude), (-90...90).contains(lat), (-180...180).contains(lon) { coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon) }
        else { coordinate = nil }
        _region = State(initialValue: MKCoordinateRegion(center: coordinate ?? CLLocationCoordinate2D(), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let coordinate {
                Map(coordinateRegion: $region, annotationItems: [LocationPoint(coordinate: coordinate)]) { point in MapMarker(coordinate: point.coordinate, tint: MessagingTheme.accent) }
                    .accessibilityLabel(message.text.isEmpty ? "消息中的位置" : message.text)
                VStack(alignment: .leading, spacing: 12.zoom()) {
                    Text(message.text.isEmpty ? "位置" : message.text).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    if let url = mapURL(coordinate) {
                        Link(destination: url) { Label("在系统地图打开", systemImage: "arrow.triangle.turn.up.right.diamond").frame(maxWidth: .infinity) }
                            .buttonStyle(MessagingActionButtonStyle())
                    }
                }.frame(maxWidth: 640).padding(16.zoom()).frame(maxWidth: .infinity).background(MessagingTheme.surface)
            } else { Spacer(); Label("此位置记录的坐标已不可用", systemImage: "mappin.slash").foregroundStyle(MessagingTheme.secondaryText).padding(24.zoom()); Spacer() }
        }.navigationTitle("位置").modifier(MessagingPageChrome())
    }

    /// 用户点击后才打开系统地图，历史展示无需位置授权。
    private func mapURL(_ coordinate: CLLocationCoordinate2D) -> URL? {
        var url = URLComponents(string: "https://maps.apple.com/")
        url?.queryItems = [URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"), URLQueryItem(name: "q", value: message.text)]
        return url?.url
    }
}

private struct LocationPoint: Identifiable { let id = "location"; let coordinate: CLLocationCoordinate2D }
