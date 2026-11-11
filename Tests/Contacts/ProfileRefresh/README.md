# 好友资料自动更新回归

运行 `bash Tests/Contacts/ProfileRefresh/run-checks.sh`：编译生产会话客户端的观察注册／解除、完整好友代理及生产 ContactsStore，验证好友资料事件到消息列表、账号轮次、可见好友刷新、30秒退避、四并发上限及请求合并。外部SDK及网络以夹具替代。修复前观察检查实际失败：好友头像昵称已落库，但消息列表没有收到刷新事件。

运行 `bash Tests/Contacts/ProfileRefresh/run-adapter-checks.sh`：提取生产 SDKContactsClient.refreshProfile 与 stopObserving，使用真实解析器、请求等待器和资料版本门；只替代SDK网络／数据库及登录状态。覆盖对方UID参数、昵称／头像写回、备注保护、相同内容不写库、显式请求优先、好友删除和退出后的迟到响应。ObjectMapper从本机已有Xcode依赖检出编译，无需网络。

这些是离线边界验证，不代表真实服务端推送或设备UI验收。设备验收需另一账号修改头像与昵称，停留前台通讯录／消息列表观察约30秒周期更新，并确认设置过的备注不变、离开页面或后台不继续轮询。
