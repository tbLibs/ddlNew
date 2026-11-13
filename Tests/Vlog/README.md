# Vlog verification

- `bash Tests/Vlog/run-checks.sh`: production repository/store at -Onone and -O; media copy/reload, tenant isolation, delete scope, missing-file rollback, corrupt/unknown-schema preservation, cancellation and late account loads.
- `bash Tests/Vlog/run-share-checks.sh`: production share operation with transport/permission closures; call ordering, video/cover/size fields, permission rejection before upload, account invalidation after upload, cancellation and original-file retention. Does not send real messages.
- `python3 Tests/Vlog/UI/generate.py /tmp/ddlNew-vlog-ui`: anonymous native app uses production Vlog UI/storage/media processing/player/theme/localization and actual MemberTab cases. Only authentication, call state and recipient transport are replaced. Run `xcodebuild test -project /tmp/ddlNew-vlog-ui/VlogHost.xcodeproj -scheme VlogHost -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' CODE_SIGNING_ALLOWED=NO`.

The UI host generates a plain photo and a short H.264 fixture, imports them through production processing/storage, then checks five tabs, preview, share entry, deletion confirmation, restart and empty state. It does not exercise a real camera, account/SDK recipients or live upload/ACK. Those require device acceptance. The host bundle is `invalid.anonymous.vlog`, separate from production app data.
