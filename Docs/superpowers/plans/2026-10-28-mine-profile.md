# 我的个人资料编辑 Implementation Plan

**Goal:** 按 xgd 的个人资料流程，在我的页面提供修改头像和昵称。

**Architecture:** 我的头像/昵称进入个人资料页，账号只读，昵称独立编辑。SwiftUI 展示与 OwnProfileStore 分离，SDKOwnProfileClient 使用现有 SDK 修改接口和上传器；UserSessionStore 继续是唯一资料缓存，维护刷新以资料版本防止旧回包覆盖主动保存。

**Tech Stack:** iOS16、SwiftUI、UIKit 原生图片选择和方形编辑、Kingfisher、现有 NoaChatCore 与云上传。

## 行为与参考

参考 xgd 的 NoaUserInfoViewController、NoaChangeUserInfoViewController、NoaFileUploadTools。保留现有森林绿样式；头像相册/拍照并裁剪，200×200 JPEG、最多50KiB，个人目录 avatar/（Minio /zim/avatar/），沿用媒体包装。昵称不空、最多30 UTF-16单位、过滤英文单引号与右单引号，未变化不提交。账号不编辑。成功才发布与持久化；失败保留昵称稿及旧头像；退出/换号取消并拒绝旧回执。

选择独立个人资料页以对应旧端并集中两种修改；不在首页并排新增管理按钮，也不移入设置页。复用当前图片选择机制，UIKit provides square crop，无新增依赖。

## 实施与验证

- [x] Tests/Mine/run-checks.sh：生产 Store 的昵称边界、重复提交、失败保稿、上传/保存次序与取消/旧身份隔离。
- [x] Features/Mine/Models/OwnProfileChange.swift 与 Services/OwnProfileStore.swift：状态、校验、客户端协议。
- [x] Network/IM/SDKOwnProfileClient.swift：上传、SDK受理、资料缓存与SDK昵称更新。
- [x] ChatAttachment / SDKChatMediaClient / SDKCloudChatMediaClient / LegacyChatMediaCodec：专用个人头像类型、目录、包装。
- [x] UserSessionStore / SessionMaintenanceCoordinator：在途旧资料读取不得覆盖已保存字段。
- [x] MineView / MinePageContent / MineProfileView / MineAvatarPicker：入口、编辑、反馈及生命周期。
- [x] 本轮测试、维护/上传相关回归、无签名 workspace build、diff检查；同步 PROJECT_HANDOFF。

## 验证边界

不操作设备、不自动提交/推送；不发真实改名、上传或资料修改请求。真实相机/相册裁剪、双端资料同步及重启持久化留给新包真机验收。

实现与验证结果见 PROJECT_HANDOFF 的2026-10-28个人资料章节。
