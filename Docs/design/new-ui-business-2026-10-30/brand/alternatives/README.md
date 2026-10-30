# 叮咚聊 · 四个 LOGO 选型记录

上一版双 D／错位口形标志已被用户否定。本轮为现有“岩白与钴蓝”视觉世界追加选项，颜色继续使用 #2859BC 与白色；未更换页面、产品定位或共享 token。

**用户已选择 D「笑着聊」。** `status = selected_by_user`，`selected = D`。当前规范资产在上级 `brand/`，`../mark.svg` 与 `d-smile.svg` 字节一致；上一版双 D 标志归档于 `../archive-dual-d/`。此前 OPTIONS-READY 是候选阶段的静态评审，本轮复评另见 `../../review.md`，不代表生产验收。

| 候选 | 图形与取舍 | 矢量 |
| --- | --- | --- |
| A · 一声叮 | 几何“叮”字，与 App 名称联系最直接，偏利落、有分量。 | [a-ding.svg](a-ding.svg) |
| B · 响铃 | 声音联想直接，但容易被理解为通用通知图标。 | [b-bell.svg](b-bell.svg) |
| C · 你来我往 | 相对引号表达对话；小尺寸可能被读成 f。 | [c-dialogue.svg](c-dialogue.svg) |
| D · 笑着聊（已选） | 微笑气泡更亲近，图形相对常见。 | [d-smile.svg](d-smile.svg) |

两张比较板保留选型前文案，作为历史记录，不代表当前仍待选择。[比较板](comparison.png) 包含白底标志、钴蓝底图标及60/40/24pt对照；[启动对照](startup-comparison.png) 用相同画面比较四案。比较板3200×1980px，启动对照3200×2100px。每案另有512×512透明 `*-mark.png` 与1024×1024不透明方形 `*-icon.png`，SVG viewBox 为256×256。圆角只出现在展示板，不烘焙进独立图标。

## 来源与边界

`render.swift` 以手工几何定义同时输出 SVG 和 AppKit PNG，未使用图像模型输出。上一轮 imagegen 调用失败没有可用产物，与本轮候选无关。可在本目录执行 `swift render.swift .` 重绘。

本轮未修改生产 Assets、LaunchScreen.storyboard 或业务源码；没有运行、真机、商店图标验收或商标独占性结论。当前 `../../flow-10.png`、品牌展示板和全部页面/状态已统一重绘为 D，不再使用旧标志占位。候选启动图不改变启动、连接、认证或路由行为，不能据此恢复已暂停的应用实现。
