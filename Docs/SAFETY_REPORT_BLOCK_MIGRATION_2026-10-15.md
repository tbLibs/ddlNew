# 2026-10-15 系统投诉与黑名单迁移记录

## 范围与状态

用户要求研究旧xgd并新增举报/拉黑，随后明确“仅系统投诉，不含邀请码/IP域名”。C-020/C-021由原暂缓转入开发/回归，当前批准105/116项、整体暂缓11项，其余子范围不变。Mobile MCP继续暂停，本轮未操作设备、未提交真实投诉或改动A/B及群数据；不提交或推送代码。实时分支`feature-message-4 / ecf1b89`，上轮媒体预览解包取消修正保留。

已完成真实SDK接入、离线检查和无签名构建；真实黑名单阻断/恢复、证据上传与投诉受理/审核尚未验收。演示举报/拉黑仍删除，不恢复本地延迟后伪装服务器成功或24小时处理承诺。

## 旧端依据（只读xgd）

以下路径均相对`/Users/taobotaobo/Desktop/xgd/NoaChatKit/CandyTalk`，xgd工作区检查仍干净。

| 旧端路径 | 已核对的行为 |
| --- | --- |
| Modules/ContactsModule/Controllers/Friend/NoaFriendManageVC.m | 黑态查询、status1加入/status0移出、bool成功、加入确认、44016/44017审核、好友投诉用户目标 |
| Modules/ContactsModule/Controllers/Friend/NoaUserHomePageVC.m | 已拉黑时主页消息/通话动作关闭；新端只迁已有发消息入口，不新增通话 |
| Modules/MineModule/Controllers/NoaBlackListViewController.m | 真实全量名单、备注优先、首字母分区、资料直达、移出 |
| Modules/ChatModule/Controllers/ReportComplain/NoaComplainVC.m | 旧端系统及邀请码/IP域名两标签；新端按用户选择仅系统投诉 |
| Modules/ChatModule/Controllers/ReportComplain/NoaComplainFromVC.m | 1–9图、8类原因、UTF16正文200上限、有效邮箱、先上传再反馈、用户/群/通用目标 |
| Base/NoaFileUpload/NoaFileUploadTools.m、Base/Headers/NoaMacroHeader.h | JPEG0.5、加密上传、Minio通用目录/zim/universal/、云供应商universal/，返回资源可为相对路径或完整URL |

实际SDK声明/实现位于新仓`NoaChatSDKCore/.../NoaIMSDKManager+Friend.h/.m`与`+User.h/.m`，复用既有接口，不新增后端端点。

## 入口与业务合同

| 功能 | 新端入口与结果 |
| --- | --- |
| 拉黑/解除 | 好友资料更多；加入二次确认，解除直接请求；真实bool为true才更新，false/失败/审核不改成最终成功 |
| 资料黑态 | 打开资料重新读取；普通好友黑态未知或为true时不可从该页发消息，已拉黑显示说明；自身份/系统文件助手不适用 |
| 黑名单 | 我的—黑名单；服务器全量快照、字母分区且#最后、资料直达及可见“移出”；空成功清旧状态，失败保留旧快照供重试 |
| 用户投诉 | 好友资料更多—投诉与支持，ufbToType=0、ufbToUserId |
| 群投诉 | 群设置—投诉与支持，ufbToType=1、ufbToGroupId，复核当前群资格 |
| 通用系统投诉 | 我的—投诉与支持，ufbToType=3；不传用户/群目标 |

黑名单SDK使用`getUserBlackState(with:)`、`getBlackListFromServer(with:)`、`addUserToBlackList(with:)`、`removeUserFromBlackList(with:)`；请求字段`userUid`、`friendUserUid`、写入`status`为1/0。布尔回执严格接收数值0/1，未知字符串/对象不按成功处理。加入/解除不删除好友、聊天记录或会话。

系统投诉使用`userAddFeedBack(with:)`。字段为`userUid`、`nickname`、`username`、`ufbImages`、`ufbContentGroup`、`ufbUserEmail`及上述目标；非空选填正文使用`ufbComment`。原因编码按旧端：1有害、2广告、3种族歧视、4文化歧视、5骚扰、6帐号被盗、8欺诈、7其他。有效邮箱支持现代长后缀；正文沿UTF16计数，不按Swift字符数放宽。

不调用`ssoFeedBackWith`、不传域名反馈的`productCode/ufbTo`，无邀请码/IP域名标签或输入。没有新增消息级举报、投诉历史或处理结果页。

## 上传、结果与生命周期

- 图片通过PhotosPicker读取；ImageIO先下采样最大边2048再解码并应用方向，输出JPEG质量0.5，临时文件仅由当前表单持有并清理。旧端仅质量压缩，新端额外限制解码尺寸以控制内存。
- 内部附件类型102仅代表投诉证据，复用现有XOR编码、Minio/四云供应商真实上传和临时凭据获取；目录对应旧universal，不落chat目录，不加入消息发送队列。该类型跳过聊天发送配额，但仍要求当前认证、真实非空文件和目标访问资格；普通媒体权限规则保持原合同。
- 顺序上传保留证据顺序，全部资源成功才拼接ufbImages并提交；缺资源/部分失败不会提交。上传返回资源原样使用，空串或包含逗号的歧义资源拒绝，不编造地址。
- SDK业务成功回调才标记投诉提交，明确false拒绝；44016/44017只显示申请审核状态，其他失败保留完整表单并可重试。关闭只取消等待和本地发布资格，已到服务器的请求不能保证撤回；已上传孤立资源没有可用删除接口，不声称回滚服务器图片。
- 防重复点击及成功后重复提交；页面打开即绑定用户、俱乐部和认证轮次，等待前后核对；切号/退出/关闭后取消客户端及等待器，迟到回调不更改新页面。群/来源群权限仍需满足原资料访问限制。
- 黑态读取和名单读取独立版本化，写入成功使旧读取失效；全量名单成功也刷新此前已知黑态，其他端解除后不会保留旧禁止发送。认证重置清空所有黑态及名单。

## UI依据与源码入口

依用户指定应用`/Users/taobotaobo/.agents/skills/ui-ux-pro-max/SKILL.md`，采用分组表单、始终可见字段标签、明确操作按钮、44pt控件及键盘安全区固定提交。设计检索的默认异国语言字体/蓝色方案不适用，保持现有森林绿`MessagingTheme`、`UIAdapter.zoom()`、MessagingCard/Toast与中文业务注释。列表移出无需依赖滑动手势。必要邮箱/超限提示靠近字段；操作结果使用Toast。

后续修正：“我的—投诉与支持”的图标键由不存在的`message`改为现有`messages`，对应`club-messages.imageset`，沿用ClubIcon的模板渲染及页面颜色。资源引用与Swift语法检查通过，未操作设备。

- `ddlNew/Features/Safety/Models`：目标、原因、草稿校验与真实参数、导航路由。
- `ddlNew/Features/Safety/Services/ComplaintStore.swift`：可注入上传/提交及取消状态机。
- `ddlNew/Features/Safety/Media/ComplaintImagePreparation.swift`：真实ImageIO处理。
- `ddlNew/Features/Safety/Views`：投诉表单和黑名单。
- `ddlNew/Network/IM/SDKComplaintClient.swift`：SDK反馈、上传与认证/权限边界。
- `ddlNew/Features/Contacts/Services/ContactsBusinessStore.swift`及`Network/IM/Contacts`：真实黑态/名单/写入及解析。
- `ContactRecordDetailView`、`MineView`、`ChatSettingsView`及`TabbarView`：入口/导航/成功Toast。

## 已执行验证

| 阶段 | 结果与证据 |
| --- | --- |
| RED→GREEN | 通用证据编码、无聊天配额上传及全量空名单清旧黑态均先复现旧行为失败再通过；SDK Swift导入名首轮编译报错已按声明修正 |
| 投诉专项 | `bash Tests/Chat/run-complaint-checks.sh`通过，含真实ImageIO PNG→JPEG及损坏图、目标/参数/邮箱/数量/正文、部分上传失败、提交失败、重试、防重复、关闭后的迟到回执 |
| 黑名单专项 | `bash Tests/Contacts/run-blacklist-checks.sh`通过，含bool false、审核、加入/移出、空快照、自身份、旧读取和同UID重认证的迟到回执。独立只读复核另发现全量空名单未使在途单人查询失效；新回归先触发断言（exit133），修正失效集合后复跑exit0，日志`/tmp/ddlNew-20261015-blacklist-read-race-red.log`及`-green.log`，独立复核确认关闭该问题 |
| 既有合同 | ContactBusinessPayload严格布尔、MediaTransport证据XOR、CloudPolicy通用目录与配额分支均通过；普通媒体/通讯录回归包含在全套 |
| 全套 | `python3 Tests/MigrationAcceptance/run-all-checks.py --output /tmp/ddlNew-20261015-safety-offline`：65/65组exit0，逐脚本耗时合计236.06秒；summary.json逐项记录；最终邮箱helper/UI提示调整后另复跑投诉专项通过 |
| 编译 | workspace/ddlNew/Debug/generic iOS，CODE_SIGNING_ALLOWED=NO，exit0、BUILD SUCCEEDED；`/tmp/ddlNew-20261015-safety-complete-build.log`。独立复核窄修后最终`/tmp/ddlNew-20261015-safety-reviewed-build.log`同样exit0、BUILD SUCCEEDED。预编译SDK内历史ModuleCache路径仍有警告，不能声称零警告 |

完整65组完成后调整了邮箱helper/UI提示，并按独立复核补修全量名单使在途单人黑态失效；各改动分别复跑投诉/黑名单专项，最终另构建。工程文件同期出现的四行空inputPaths/outputPaths保留；本轮未手动调整构建阶段。临时日志可能清理，以上证据为当时执行结果。

## 待真实验收

1. A/B可恢复身份：查询、加入true/false/审核、名单与资料同步、重启/换号隔离；另一端消息是否被服务端阻断，移出后双向恢复。不能由禁用发消息按钮推断接收已阻断。
2. 经过授权的可恢复测试目标：用户/群/通用各一次，确认真实图片资源能回读、目标字段正确、SDK受理及实际管理端记录；没有条件时记录缺失，不借不可控第三身份或生产群测试。
3. 实际部署的Minio/阿里/腾讯/华为/亚马逊上传与证据显示；上传成功不能代替系统投诉受理，各供应商匿名夹具不能代替线上签名/权限证明。
4. 真机/iPad键盘、图片选择/移除、深色/字号/VoiceOver、取消/后台/弱网及重认证；本轮只有源码检查和编译，没有运行视觉验收。
5. 审核后状态回流、真实投诉处理结果及超时后重试是否重复由服务端联调确认；当前没有可用幂等键或投诉记录接口，不承诺跨重开表单的全局幂等。

昨晚其他未完成的媒体/弱网/三角色群矩阵继续按统一交接第8节，不因本轮65组离线通过而关闭。
