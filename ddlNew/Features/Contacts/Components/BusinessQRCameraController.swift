//
//  BusinessQRCameraController.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import UIKit
import AVFoundation

/// 捕获工作在串行队列完成，相机退出后丢弃迟到识别结果。
final class BusinessQRCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onError: ((String) -> Void)?
    private let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "ddlNew.businessQRCode.capture")
    private var preview: AVCaptureVideoPreviewLayer?
    private var active = true
    private var consumed = false

    /// 申请摄像头访问前显示系统相机占位背景。
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in if granted { self?.configure() } else { self?.onError?("请在系统设置中允许摄像头访问") } }
            }
        default: onError?("请在系统设置中允许摄像头访问")
        }
    }

    /// 会话使用后置镜头QR元数据，预览在主线程布局。
    private func configure() {
        guard active, let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { onError?("此设备无法使用摄像头"); return }
        let output = AVCaptureMetadataOutput()
        guard session.canAddInput(input), session.canAddOutput(output) else { onError?("相机初始化失败"); return }
        session.addInput(input); session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer); preview = layer; layer.frame = view.bounds
        let session = session
        captureQueue.async { session.startRunning() }
    }

    /// 旋转及分屏后相机预览保持填满可见区域。
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); preview?.frame = view.bounds }

    /// 每次进入只消费一个二维码，避免连续帧重复提交服务器请求。
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard active, !consumed, let value = metadataObjects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first else { return }
        consumed = true; stop(); onCode?(value)
    }

    /// 串行停止会话，与正在启动的会话保持队列顺序。
    func stop() { active = false; let session = session; captureQueue.async { if session.isRunning { session.stopRunning() } } }
}
