# 用户资料排版与横向回弹回归

提取 ContactRecordDetailView 的完整资料滚动内容、detail 方法和两个局部滚动辅助类型，编译生产 MessagingScroll、MessagingCard、MessagingRowStyle、MessagingActionButtonStyle，并使用项目 DerivedData 中实际的 UIAdapter 包。头像替换为同尺寸占位，Store及业务动作替换为匿名只读夹具，不连接 SDK 或真实账号。

```bash
python3 Tests/Contacts/ProfileLayout/generate.py /tmp/ddlNew-profile-layout
xcodebuild -project /tmp/ddlNew-profile-layout/ProfileLayout.xcodeproj -scheme ProfileLayout -destination 'platform=iOS Simulator,id=<UUID>' -parallel-testing-enabled NO test
```

单元检查覆盖当前屏幕宽度及390、414、428、430、440点宽度，空备注／50字中文备注／50个连续英文字母备注，配合短描述／200字中文／200个连续英文字母／200 UTF-16单元表情，共72组。检查实际视口宽度、滚动内容宽度和长描述增高，宽度容差0.01点，避免忽略一个像素的溢出。iOS17.4起还断言原生bouncesHorizontally关闭，bouncesVertically保留。UI测试从导航入口打开填满备注和描述的资料、向上滚动再向左拖动，记录拖动期间的实际contentOffset.x。

2026-11-11：iPhone 17 Pro Max模拟器／iOS26.5，满备注和描述未复现内容撑宽（/tmp/ddlNew-profile-remark-full.xcresult）。只设置SwiftUI basedOnSize仍使原生bouncesHorizontally保持开启，新增开关断言失败（/tmp/ddlNew-profile-bounce-fixed.xcresult）；局部UIViewRepresentable显式关闭原生横向回弹后两项检查通过（/tmp/ddlNew-profile-native-fixed.xcresult），横向拖动偏移0。

该宿主没有真实账号状态、图片下载和页面刷新请求，也不是用户的iPhone16 Pro Max／iOS26真机；不能将测试通过表述为真机问题已验收。
