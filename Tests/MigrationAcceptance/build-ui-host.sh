#!/bin/sh
# 隔离编译生产聊天UI；替代SDK/图片网络只存在本测试目标，不更改生产AUTH。
set -eu
QA_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
QA_BUILD=/tmp/ddlNew-migration-ui-host
QA_APP="$QA_BUILD/MigrationQA.app"
QA_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
mkdir -p "$QA_APP/Frameworks" "$QA_BUILD/modules"
# 开发仍在写源码，先保存本次UI编译快照，避免编译中输入文件变动。
QA_SNAPSHOT="$QA_BUILD/source"
rm -rf "$QA_SNAPSHOT"
mkdir -p "$QA_SNAPSHOT/ddlNew/Features" "$QA_SNAPSHOT/ddlNew/Network/Core" "$QA_SNAPSHOT/ddlNew/Configuration" "$QA_SNAPSHOT/Tests/MigrationAcceptance"
cp -R "$QA_ROOT/ddlNew/Features/Chat" "$QA_ROOT/ddlNew/Features/Contacts" "$QA_ROOT/ddlNew/Features/Groups" "$QA_SNAPSHOT/ddlNew/Features/"
cp -R "$QA_ROOT/ddlNew/Features/Message" "$QA_SNAPSHOT/ddlNew/Features/"
cp "$QA_ROOT/ddlNew/Network/Core/RemoteAvatarURL.swift" "$QA_SNAPSHOT/ddlNew/Network/Core/"
cp -R "$QA_ROOT/Tests/MigrationAcceptance/UIHost" "$QA_SNAPSHOT/Tests/MigrationAcceptance/"
# 快照仅保存业务偏好key，不复制Const认证与网络配置。
sed -n '/^let contactsApplicationStateKey = /p' "$QA_ROOT/ddlNew/Configuration/Const.swift" > "$QA_SNAPSHOT/ddlNew/Configuration/Const.swift"
QA_ROOT="$QA_SNAPSHOT"
# 只抽业务key，认证和网络常量不进入独立包。
sed -n '/^let contactsApplicationStateKey = /p' "$QA_ROOT/ddlNew/Configuration/Const.swift" > "$QA_BUILD/BusinessConstants.swift"
xcrun --sdk iphonesimulator swiftc -sdk "$QA_SDK" -target arm64-apple-ios16.0-simulator -emit-library -emit-module -module-name Kingfisher "$QA_ROOT/Tests/MigrationAcceptance/UIHost/KingfisherLayoutStub.swift" -emit-module-path "$QA_BUILD/modules/Kingfisher.swiftmodule" -o "$QA_APP/Frameworks/libKingfisher.dylib" -Xlinker -install_name -Xlinker @rpath/libKingfisher.dylib
xcrun --sdk iphonesimulator swiftc -sdk "$QA_SDK" -target arm64-apple-ios16.0-simulator -I "$QA_BUILD/modules" -L "$QA_APP/Frameworks" -lKingfisher -Xlinker -rpath -Xlinker @executable_path/Frameworks "$QA_ROOT/ddlNew/Features/Message/Models/ConversationRecord.swift" "$QA_ROOT/ddlNew/Features/Chat/Models/"*.swift "$QA_ROOT/ddlNew/Features/Chat/Services/ChatStore.swift" "$QA_ROOT/ddlNew/Features/Chat/Views/ChatRoomView.swift" "$QA_ROOT/ddlNew/Features/Chat/Components/ChatMessageBubble.swift" "$QA_ROOT/ddlNew/Features/Chat/Components/ChatAnimatedRemoteImage.swift" "$QA_ROOT/ddlNew/Features/Chat/Components/ChatMediaComposer.swift" "$QA_ROOT/ddlNew/Features/Chat/Media/ChatMediaStore.swift" "$QA_ROOT/ddlNew/Features/Chat/Media/ChatVoiceRecorder.swift" "$QA_ROOT/ddlNew/Features/Chat/Media/ChatCameraPicker.swift" "$QA_ROOT/ddlNew/Features/Chat/Media/ChatPickedMovie.swift" "$QA_ROOT/ddlNew/Features/Chat/Media/ChatAttachmentPreparation.swift" "$QA_ROOT/ddlNew/Network/Core/RemoteAvatarURL.swift" "$QA_BUILD/BusinessConstants.swift" \
 "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactsRoute.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactRecord.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactSection.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactSorter.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactsIdentity.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/FriendApplicationRecord.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/FriendBusinessGroup.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactBusinessOperation.swift" "$QA_ROOT/ddlNew/Features/Contacts/Models/ContactBusinessResponse.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactBusinessClient.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactBusinessError.swift" "$QA_ROOT/ddlNew/Features/Contacts/Services/ContactsBusinessStore.swift" "$QA_ROOT/ddlNew/Features/Contacts/Views/ContactRemarkEditor.swift" "$QA_ROOT/ddlNew/Features/Groups/Models/GroupMemberSelection.swift" "$QA_ROOT/ddlNew/Features/Groups/Models/GroupMemberPickerFilter.swift" "$QA_ROOT/ddlNew/Features/Groups/Views/GroupMemberPickerView.swift" "$QA_ROOT/Tests/MigrationAcceptance/UIHost/ChatLayoutHost.swift" -o "$QA_APP/MigrationQA"
/usr/libexec/PlistBuddy -c 'Clear dict' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.sigua.ddlNew.MigrationQA' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string MigrationQA' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string MigrationQA' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 1' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 1.0' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :MinimumOSVersion string 16.0' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :UILaunchScreen dict' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSMicrophoneUsageDescription string 独立UI验收录音权限' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSCameraUsageDescription string 独立UI验收相机权限' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :UIDeviceFamily array' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :UIDeviceFamily:0 integer 1' "$QA_APP/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :UIDeviceFamily:1 integer 2' "$QA_APP/Info.plist"
codesign --force --sign - "$QA_APP/Frameworks/libKingfisher.dylib"
codesign --force --sign - "$QA_APP"
printf '%s\n' "$QA_APP"
