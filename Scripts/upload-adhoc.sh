#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $# == 1 ]] || { printf '用法：%s <含 ddlNew.ipa 和 manifest.plist 的目录>\n' "$0" >&2; exit 1; }
ARTIFACTS="$(cd "$1" && pwd)"
for name in ddlNew.ipa manifest.plist; do
    [[ -s "$ARTIFACTS/$name" ]] || { printf '缺少产物：%s\n' "$name" >&2; exit 1; }
done
/usr/bin/plutil -lint "$ARTIFACTS/manifest.plist"
# User-requested local configuration, intentionally not excluded from Git.
source "$SCRIPT_DIR/adhoc-upload-config.sh"
export DDLNEW_SSH_PASSWORD

# Only the two release artifacts are transferred; no archive, logs or credentials.
IPA_SHA="$(/usr/bin/shasum -a 256 "$ARTIFACTS/ddlNew.ipa" | cut -d ' ' -f 1)"
MANIFEST_SHA="$(/usr/bin/shasum -a 256 "$ARTIFACTS/manifest.plist" | cut -d ' ' -f 1)"
RUN_ID="$(/usr/bin/uuidgen | tr '[:upper:]' '[:lower:]')"
REMOTE='/data/static-site/ddlnew'
STAGING="$REMOTE/.upload-$RUN_ID"
TARGET='root@8.210.96.3'
SOCKET_DIR="$(mktemp -d /tmp/ddlnew-ssh.XXXXXX)"
SSH_OPTIONS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=20
    -o ServerAliveInterval=15 -o ServerAliveCountMax=3
    -o ControlMaster=auto -o ControlPersist=60 -o "ControlPath=$SOCKET_DIR/socket")
run_auth() { /usr/bin/expect "$SCRIPT_DIR/ssh-password.exp" "$@"; }
remote() { run_auth /usr/bin/ssh "${SSH_OPTIONS[@]}" -p 22 "$TARGET" "$@"; }
cleanup() {
    /usr/bin/ssh "${SSH_OPTIONS[@]}" -p 22 -O exit "$TARGET" >/dev/null 2>&1 || true
    rm -rf "$SOCKET_DIR"
}
trap cleanup EXIT
printf '正在上传至 %s:%s/\n' "$TARGET" "$REMOTE"
remote "set -eu; mkdir -p '$REMOTE'; mkdir -m 700 '$STAGING'"
run_auth /usr/bin/scp "${SSH_OPTIONS[@]}" -P 22 \
    "$ARTIFACTS/ddlNew.ipa" "$ARTIFACTS/manifest.plist" "$TARGET:$STAGING/"

# Values interpolated below are fixed paths, UUIDs or SHA-256 digests.
# Verify both files before replacing anything. Keep backups only until publication succeeds.
remote "set -eu
cd '$STAGING'
printf '%s  %s\n' '$IPA_SHA' ddlNew.ipa '$MANIFEST_SHA' manifest.plist | sha256sum -c -
mkdir '$REMOTE/.publish-lock' || { echo '另一个发布正在进行，临时文件已保留' >&2; exit 1; }
trap 'rmdir \"$REMOTE/.publish-lock\"' EXIT
for name in ddlNew.ipa manifest.plist; do
    if [ -e \"$REMOTE/\$name\" ]; then cp -p \"$REMOTE/\$name\" \"previous-\$name\"; fi
done
chmod 644 ddlNew.ipa manifest.plist
mv -f ddlNew.ipa '$REMOTE/ddlNew.ipa'
if ! mv -f manifest.plist '$REMOTE/manifest.plist'; then
    if [ -f previous-ddlNew.ipa ]; then cp -p previous-ddlNew.ipa '$REMOTE/ddlNew.ipa'; else rm -f '$REMOTE/ddlNew.ipa'; fi
    echo '清单替换失败，IPA 已回退' >&2
    exit 1
fi
cd '$REMOTE'
printf '%s  %s\n' '$IPA_SHA' ddlNew.ipa '$MANIFEST_SHA' manifest.plist | sha256sum -c -
echo '服务器文件校验通过'
rm -f '$STAGING/previous-ddlNew.ipa' '$STAGING/previous-manifest.plist'
rmdir '$STAGING'"
printf '上传完成：%s/ddlNew.ipa 和 manifest.plist\n' "$REMOTE"
printf '上传临时目录已清理\n'
