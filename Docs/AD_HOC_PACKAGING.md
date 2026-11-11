# Ad Hoc 打包

查看全部参数：`./Scripts/package-adhoc.sh --help`（也支持 `-h`）。

在项目根目录运行：

```bash
./Scripts/package-adhoc.sh
```

指定本次版本号和 Build 号，并在成功后自动上传：

```bash
./Scripts/package-adhoc.sh --version 1.3.1 --build-number 2
```

`--version` 接受 1 至 3 段数字，`--build-number`（别名 `--build`）接受正整数，两者均可单独传入；未传参数沿用工程配置。通过本次 xcodebuild 的 `MARKETING_VERSION`／`CURRENT_PROJECT_VERSION` 覆盖，不修改工程文件。复用已有 `--archive` 时不接受版本参数，修改版本必须重新归档。

需要 Xcode、支持 `xcode archive/export` 的 `asc` CLI、Python 3 和与 `Podfile.lock` 一致的 Pods。脚本沿用项目团队 `DGK6VR7P2D` 和自动签名，使用 Release 归档、`release-testing`（Ad Hoc）导出。测试设备必须已包含在描述文件中；需要 Xcode 自动更新签名资源时运行：

```bash
./Scripts/package-adhoc.sh --allow-provisioning-updates
```

默认输出至 `build/adhoc/<时间戳.随机后缀>/`，该路径已被 Git 忽略。目录包含 `ddlNew.ipa`、`manifest.plist`、`ExportOptions.plist`、导出日志；重新归档时还包含 `.xcarchive`、独立 DerivedData 与归档日志。归档保留 dSYM，构建 PATH 仅包含系统工具目录，以跳过项目中通过 `which sentry-cli` 发现的可选符号／源码上传步骤。

可指定一个尚不存在的产物目录，或复用 Xcode Organizer 已有归档：

```bash
./Scripts/package-adhoc.sh --output "$HOME/Desktop/ddlNew-AdHoc"
./Scripts/package-adhoc.sh --archive "/完整路径/ddlNew.xcarchive"
```

现有目录不会被覆盖。失败会退出并保留日志；只有 IPA 导出和安装清单校验全部成功，才会输出“打包完成”。

安装清单直接读取**本次导出的 IPA**：`CFBundleIdentifier` 写入 `bundle-identifier`，`CFBundleShortVersionString` 写入 `bundle-version`，`CFBundleVersion` 写入下载页可选的 `build-version`。脚本不修改工程文件，打包成功后自动上传。

- IPA 固定地址：`https://static.xingqitongim.com/ddlnew/ddlNew.ipa`
- 清单部署地址：`https://static.xingqitongim.com/ddlnew/manifest.plist`
- 图标沿用现有下载页地址：`https://static.xingqitongim.com/ios/512.png`

上传连接为 `root@8.210.96.3:22`，目标目录 `/data/static-site/ddlnew/`。密码按用户要求直接保存在 `Scripts/adhoc-upload-config.sh`，不加入 `.gitignore`，不在本文复制密码。通过 macOS 自带 Expect 处理认证，密码不放进命令行参数；首次连接接受新主机密钥，已记录密钥发生变化时拒绝连接。

上传只传 `ddlNew.ipa` 与 `manifest.plist`，先存至远端唯一 `.upload-<UUID>/` 目录，两项 SHA-256 均匹配后获取发布锁、备份旧文件，再依次替换 IPA、清单并复验摘要。每个文件的替换为同文件系统 rename；两个文件不是一次原子事务，更新期间有短暂新 IPA／旧清单窗口。旧版只在发布过程中临时备份；正式文件复验成功后删除备份和本次 `.upload-<UUID>/` 目录，不长期保留历史包。传输或预校验失败不会替换正式文件，失败时保留本次临时内容以便排查或回退；被强制中止的发布锁需要核实无在途发布后人工处理。日志保留在产物目录 `upload.log`。

只打包或重试上传已有产物：

```bash
./Scripts/package-adhoc.sh --version 1.3.1 --build-number 2 --no-upload
./Scripts/upload-adhoc.sh "/完整路径/本次产物目录"
```

现有 `index.html` 保持从清单 `bundle-version` 读取版本。上传成功表示 SSH 目标文件摘要匹配，不代表 CDN 刷新或设备在线安装已验证。

离线流程检查（隔离替身，无真实签名／服务器访问）：

```bash
python3 Tests/Packaging/check_package_adhoc.py
python3 Tests/Packaging/check_upload_adhoc.py
```
