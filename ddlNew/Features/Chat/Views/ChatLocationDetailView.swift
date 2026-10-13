//
//  ChatLocationDetailView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import MapKit

struct ChatLocationDetailView: View {
    let message: ChatMessageRecord
    @State private var region: MKCoordinateRegion
    private let coordinate: CLLocationCoordinate2D?

    /// 历史位置只读，校验经纬度后由原生地图显示，不申请定位或发送新位置。
    init(message: ChatMessageRecord) {
        self.message = message
        if let lat = Double(message.latitude), let lon = Double(message.longitude), (-90...90).contains(lat), (-180...180).contains(lon) { coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon) }
        else { coordinate = nil }
        _region = State(initialValue: MKCoordinateRegion(center: coordinate ?? CLLocationCoordinate2D(), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
    }

    var body: some View {
        VStack {
            if let coordinate {
                Map(coordinateRegion: $region, annotationItems: [LocationPoint(coordinate: coordinate)]) { point in MapMarker(coordinate: point.coordinate) }
                Text(message.text).font(.headline).padding()
                if let url = mapURL(coordinate) { Link("在系统地图打开", destination: url).padding() }
            } else { Text("此位置记录的坐标已不可用").foregroundStyle(.secondary) }
        }.navigationTitle("位置")
    }

    /// 只有用户点击链接才打开地图，历史展示无需位置授权。
    private func mapURL(_ coordinate: CLLocationCoordinate2D) -> URL? {
        var url = URLComponents(string: "https://maps.apple.com/")
        url?.queryItems = [URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"), URLQueryItem(name: "q", value: message.text)]
        return url?.url
    }
}

private struct LocationPoint: Identifiable { let id = "location"; let coordinate: CLLocationCoordinate2D }
