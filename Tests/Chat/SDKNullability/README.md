# SDK 消息查询可空契约回归

运行 `sh Tests/Chat/SDKNullability/run-checks.sh`。

脚本从生产NoaIMSDKManager+ChatMessage.h提取单条消息查询声明，用Objective-C匿名实现模拟未命中返回nil，然后以Swift的-Onone和-O分别编译生产同型的条件查询／Optional.map／缓存合并边界。无真实SDK数据库、账号或网络。

2026-11-12旧声明在NS_ASSUME_NONNULL_BEGIN内缺少nullable，Debug返回远端正常状态1，Release因信任非空声明把缺失缓存当成存在，返回状态0；日志/tmp/ddlNew-nullability-red2.log。修正声明后两种优化级别均返回状态1，/tmp/ddlNew-nullability-fixed.log。

最初把查询结果放入Optional数组再循环的夹具两种配置均通过，无法保留原调用点的优化事实，已替换为直接查询和合并；不把该夹具作为失败证据。既有Swift分页fake本来就将查询返回标记为Optional，因此94项分页测试不覆盖这个ObjC导入契约问题。
