import SwiftUI
import XCTest
import UIAdapter

final class LayoutTests: XCTestCase {
    @MainActor func testDescriptionStaysWithinViewportAndWraps() async {
        for width in [Double(UIScreen.main.bounds.width), 390.0, 414.0, 428.0, 430.0, 440.0] {
            for remarks in ["", String(repeating: "备注", count: 25), String(repeating: "W", count: 50)] {
            var heights: [CGFloat] = []
            for value in ["短描述", String(repeating: "描述", count: 100), String(repeating: "W", count: 200), String(repeating: "🙂", count: 100)] {
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: UIScreen.main.bounds.height))
                let host = UIHostingController(rootView: NavigationStack { ProfileFixture(description: value, remarks: remarks).navigationTitle("用户资料") }.frame(width: width, height: UIScreen.main.bounds.height))
                window.rootViewController = host; window.makeKeyAndVisible()
                host.view.frame = window.bounds
                host.view.setNeedsLayout(); host.view.layoutIfNeeded()
                try? await Task.sleep(nanoseconds: 150_000_000)
                host.view.layoutIfNeeded()
                func scroll(in view: UIView) -> UIScrollView? {
                    if let view = view as? UIScrollView { return view }
                    return view.subviews.lazy.compactMap { scroll(in: $0) }.first
                }
                guard let scroll = scroll(in: host.view) else { XCTFail("缺少原生滚动容器"); return }
                print("PROFILE width=\(width), chars=\(value.utf16.count), content=\(scroll.contentSize), bounds=\(scroll.bounds.size), insets=\(scroll.adjustedContentInset), horizontalBounce=\(scroll.alwaysBounceHorizontal), verticalBounce=\(scroll.alwaysBounceVertical)")
                XCTAssertEqual(scroll.bounds.width, width, accuracy: 0.5)
                XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 0.01, "width=\(width), chars=\(value.utf16.count), prefix=\(value.prefix(2)), remarks=\(remarks.count); content=\(scroll.contentSize), viewport=\(scroll.bounds.size)")
                if #available(iOS 17.4, *) {
                    XCTAssertFalse(scroll.bouncesHorizontally, "资料页不应允许横向弹性回弹")
                    XCTAssertTrue(scroll.bouncesVertically, "保留纵向回弹及下拉刷新")
                }
                heights.append(scroll.contentSize.height)
                window.isHidden = true
            }
            XCTAssertGreaterThan(heights[1], heights[0], "长描述应换行增高，不能裁剪隐藏")
            XCTAssertGreaterThan(heights[2], heights[0], "连续英文也应换行增高")
            }
        }
    }
}
