# 2026-10-15 系统导航栏统一

用户要求消息、通讯录及其它页面的自定义页头统一改成`.toolbar {}`。实时基线`feature-message-4 / ecf1b89`，已有功能改动原样保留，不提交/推送。Mobile MCP继续暂停，本轮未使用其它工具操作设备。

## 实现范围

- 四个实际Tab根页统一显示原生导航栏：消息保留同步状态、搜索及新增菜单；通讯录保留搜索和添加好友；首页保留社团标题/公告入口，问候语作为正文；我的保留设置入口。使用现有导航栈与路由、森林绿和UIAdapter。
- 活动列表、个人签到移除重复导航标题，活动名称仍作为签到正文内容。
- 消息页的顶部`safeAreaInset`移除，通讯录/首页/我的不再用正文HStack模拟导航栏。9处旧`.navigationBarHidden(false)`及Tab根页隐藏设置改成`.toolbar(.visible, for: .navigationBar)`，二级页面继续使用现有原生标题/操作。
- 剩余顶部`safeAreaInset`为群申请的业务筛选标签，不是导航标题；底部聊天输入、确认/提交条保持底部安全区职责。未接入App的`OriginalHomeView/OriginalMessagesView/OriginalContactsView`保留原型参考，不计入实际页面。

## 验证边界

通讯录与消息会话离线检查通过；无签名generic iOS workspace构建`/tmp/ddlNew-20261015-all-toolbars-build.log`为exit0、`BUILD SUCCEEDED`。全源码核对不再存在`.navigationBarHidden`；`.safeAreaInset(edge: .top)`只剩群申请业务筛选。后续表情/@改动的统一回归结果见[聊天布局记录](CHAT_LAYOUT_ALIGNMENT_2026-10-15.md)。

尚未验收真机/iPad/Mac实际导航布局、搜索/菜单触点、返回手势及大字号外观；构建不代表这些场景已通过。首页和我的继续沿原森林绿主题，不新增导航所有者，不修改业务权限或服务器协议。
