# 业务校正版设计预览

分支 `feature-newUI-5`，设计基线 `a55a32f`。本目录由静态 AppKit 绘制，未运行 iOS App。

- `index.html`：10组流程和147张页面/状态，可按名称搜索。
- `pages.json`：121条原清单及26条状态变体，页面来源、条件与去向。
- `flows.json`：关键状态组合。
- `render.swift`：静态绘制；`gallery.py`：预览与覆盖表生成。
- `DESIGN.md` / `PRODUCT.md`：视觉、业务约束。

复现（在本目录）:

```sh
python3 gallery.py
xcrun swift render.swift .
python3 -m http.server 8767 --bind 127.0.0.1
```

示例人物、账号、文案、日期均为合成内容。媒体内容为占位图形，二维码不可扫描。图示包含旧本地演示页面，不意味着实时服务实现。

当前只供设计评审。应用代码已按用户要求暂停；之前保留的UI改动尚未完成整合和编译验证。确认设计后再继续实现。动态字体、深色模式、键盘与实机交互需在实现阶段验证。

用户追加的 LOGO 与启动设计见 [品牌提案](brand/README.md)。App名已确认「叮咚聊」。
