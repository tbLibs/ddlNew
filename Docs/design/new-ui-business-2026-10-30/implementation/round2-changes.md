# Remaining layouts — implementation report

2026-10-30, `feature-newUI-5`. Incremental baseline: `/tmp/ddlNew-round2-before/ddlNew/` (all 36 assigned sources saved before editing); changed paths: `/tmp/ddlNew-round2-changed.txt`. 27 sources changed, 9 retained after source/PNG comparison. No Stores, Services, Models, ViewModels, network, SDK, project, shared theme/component sources changed by this worker. No commits, push, build or device operation. Parent owns integration and handoff updates.

Read requirements, approved DESIGN.md, craft-floor and render.swift; viewed approved screen PNGs directly, including contact sheets assembled from actual PNGs. IDs below refer to `Docs/design/new-ui-business-2026-10-30/screens/`. PNG comparison establishes intended composition, not runtime acceptance.

## Original 27 sources

| Source | Design IDs | Actual disposition / evidence |
|---|---|---|
| RecordsScreen | 018–021 | Changed: zero inter-card spacing; white scroll canvas. ActivityCard already delegates to flat HomeActivityRow (title/date/place/status/chevron/bottom divider), so no replacement activity/card logic. Real participation status remains visible; no unsupported search feature added to imitate sample. |
| CheckInSelectionScreen | 022 | Changed: removed per-row ClubCard and decorative scan icon; continuous title/date/status/chevron rows with separators. Same NavigationLink and eligible activity set. |
| GlobalSearchView | 029,111 | Retained: source has fixed search header and continuous per-kind result sections, count, avatar/title/detail/time/chevron rows and separators, explicit no-results/error/retry. Real four SDK result categories retained rather than three sample groups. No nested card container. |
| ChatRoomView | 030,031,034,035,115,030-failed | Retained: source owns chronological scroll, incoming/outgoing bubble rows, pinned/notice strips, composer safe area, independent multi-select bottom actions, native message/delete menus, and genuine read/send/failure conditions. Bubble/theme/composer sources already carry approved styling; no artificial sample date or extra actions inserted. Composer separately changed below. |
| ChatMessageEditorView | 036 | Changed: explicit 正文 label, neutral rounded input face (272pt minimum), white canvas, bottom full-width save, cancel/discard/draft/mentions logic retained. |
| ChatHistorySearchView | 038 | Retained: fixed search + category tabs, real optional group-member Picker, flat result rows/separators and locate callbacks. Separate member row retained for available long names rather than unsupported static pick label. |
| ChatForwardRecipientView | 039,040 | Changed: single counted full-width bottom send. Existing search/scopes/merge mode/count, selection rows, confirmation modal recipients/preview and exact forwarding snapshots retained. Native focused confirmation sheet remains instead of a fake static alert. |
| ChatForwardRecordView | 041 | Changed: leading record heading/body reading layout; text entries use inline author/time metadata instead of avatar-heavy rows. Navigation title is 聊天记录; record title is in reading content. All attachment/card open paths and share restrictions retained. |
| ChatPinnedMessagesView | 042 | Retained: actual source is a continuous zero-gap list of ChatSecondaryRecordRow with separators and direct locate+dismiss, with empty state and a short interaction hint; no cards. |
| ChatPinActionView | 043 | Changed: neutral message preview, flat independent scope rows with scope explanations and trailing 置顶/取消置顶; genuine status/global-role restrictions and requests retained. |
| ChatStickersView | 044 | Changed: four flexible columns (two at accessibility sizes), adjusted resource/cell dimensions to fit; real animated resource/title and direct-send callback remain. No bottom send added. |
| ChatMediaDetailView | 047,048 | Changed: file download/voice replay anchored bottom; voice receiver setting becomes unboxed flat row, white content canvas. Real file preview, cancellation, download retry, cleanup, share permission and playback callbacks retained. |
| ChatLocationDetailView | 049 | Retained: actual Map occupies main content and genuine location name/system-map link sit in bottom strip; coordinate invalid state preserved. Native Map is visual authority for map surface, no sample map illustration. |
| AddFriendView | 053,054 | Changed: labeled account field on neutral input face, leading own-account row, in-content scan entry and full-width bottom search; flat actual result rows. Same submitted query, exact account lookup, QR/copy routes and clearing lifecycle. |
| NewFriendsView | 055 | Changed: request actions are plain blue text with native borderless List button behavior/44pt minimum, rather than filled per-row primary buttons. Navigation, direction/state/permission conditions and visible-row read marking unchanged. |
| BusinessQRCodeView | 062,079 | Changed: removed outer generic card; centered real identity and generated QR directly on white canvas. QR white backing/quiet area, true expiry and actual save/share actions remain. |
| BusinessQRScannerView | 063 | Changed: real unjoined-group result uses leading title and labeled neutral approval-reason field on white scroll surface; full-width genuine join action. Camera framing/native photo picker/permissions and decode lifecycle untouched. |
| ContactsRecipientPickerView | 064 | Retained: source is native plain List with search, true friend/group sections, checkmark/avatar/title rows, counted navigation share and bottom selected summary; genuine confirmation and 100-target cap remain. No new scope state introduced merely to mimic a sample 好友 tab. |
| ChatGroupMembersView | 070,074,075 | Changed: private removal confirmation now flat white scroll content with title/toggle, retaining modal, native role/mute/transfer menu, busy/error feedback and confirmations. Main searchable native List already flat. |
| ChatGroupRemovalView | 071,072 | Changed: removal modal flattened to leading selected members and deletion option on white canvas; original chosen-member validation, canSubmit, delete-message setting and destructive request ownership remain. Native modal intentionally retains configurable toggle absent from static alert. |
| ChatGroupManagementView | 073,113,120 | Changed: no rounded group cards; continuous separated navigation and policy rows, explicit 开启/关闭 secondary labels, real banned members. Permission-loss and all server-bound toggles/unmute callbacks preserved. |
| ChatGroupAvatarView | 076 | Changed: 100pt circular current avatar, genuine group name and 当前群头像 text; authorized photo action anchored bottom. Permission refresh, image preparation and upload cancellation retained. |
| ChatGroupNoticesView | 080,081,082 | Changed: detail body directly on white reading surface; editor has 正文 label, neutral 272pt input face, separated pin/send toggles, bottom publish/save. Real notice author/time/body, delete/discard/permission/draft and modal ownership unchanged. List retains genuine publish/navigation toolbar rather than changing permission behavior. |
| GroupApplicationsView | 083,083-pending | Changed: agree/reject row buttons become compact blue/red text actions with44pt targets. Existing all/pending tabs, true invitation/applicant data, pending selection/footer and confirm/review paths retained. |
| MassMessageRecipientPicker | 093 | Retained: source has search/scopes, selected-only/all-selection controls, sectioned native List with real checkmarks/avatars/names and counted completion. Bottom completion is existing native task affordance, retained to avoid duplicating navigation and bottom actions. No sample recipients or extra business scope added. |
| MassMessageRecipientsView | 094,094-failed | Retained: source is native plain list with real recipient avatars/name/type plus genuine failure detail, pagination/retry/refresh. All/failed are route-owned stores, not local sample tabs; no fake filter introduced. |
| BlacklistView | 102,112,117 | Retained: source is plain sectioned native list with true avatar/name/account and explicit 移出 per row; loading/failure/retry and submitting disable retained. No decorative cards or batch actions. |

## Expanded ownership from parent

| Source | Design IDs | Actual changes |
|---|---|---|
| RegistrationScreen | 015 | Removed three generic cards; leading activity summary, member input face and retained real member/avatar/account/notice/consent. Exact submit handler anchored bottom, same accepted/saving conditions. |
| RegistrationResultScreen | 016,017 | Sparse outlined result glyph, true success/waiting heading, centered actual title/date/meeting/participation explanation; bottom 完成 calls existing onDone. |
| CheckInScreen | 023,024,023-error | One visible labeled numeric neutral field replaces four fake digit boxes/invisible field; exact four-digit sanitation and checkIn submission retained. Bottom confirm uses same guard. Actual checkedIn renders sparse success and normal dismiss completion. |
| MineProfileView incl. MineNicknameEditor | 097–100 | Profile labels/values stack leading; genuine avatar and read-only account unchanged. Nickname editor gains visible label, white page and bottom save bound to exact canSaveNickname/saveNickname. System camera/library/crop unchanged. |
| LoginVerificationSheet | 005,005-failed,006-code | Actual CAPTCHA image on wide neutral face; native image/security input labels; bottom continue uses same submitted/trim-empty condition. Provider WKWebView/retry/loading lifecycle unchanged. |
| ClubScreen | 026 | Leading editorial club title/description/how-to, unboxed info navigation. Existing statistics retained as secondary content, no invented announcements/routes. |
| InformationSheet | 027 | Removed card/double margins; real first paragraph treated as title and remaining selected text as body, no sample paragraph invented. Existing page/dismiss ownership retained. |
| CallRoomView | 086–089 | Single identity heading, circular avatars, two-column group grid, incoming wide pill actions, full-width connected/cancel hangup; equipment controls separate and lighter. Single video surface under header/control overlays; existing local/remote swap, actual per-person states, invite, coordinator lifecycle/enabled guards retained. |
| ChatMediaComposer | 032 | Attachment-first tools (album/camera/file then eligible video/audio), four-column wrap/two at accessibility sizes. Idle mic/keyboard moved left, active send remains right. Existing typing/sticker/voice state machine and gestures untouched. No new expansion state or synthetic plus button. Tools remain visible because that is existing interaction ownership; exact static collapsed/expanded behavior intentionally not invented. |

## Verification

- All 27 changed Swift sources: `xcrun swiftc -frontend -parse` exit0 (combined final pass).
- `git diff --check`: exit0.
- Existing affected checks: `Tests/Chat/run-member-page-checks.sh` 9 pass; `run-notice-store-checks.sh`38 pass; `run-settings-checks.sh`14 pass; `run-composer-mode-checks.sh` pass; `run-composer-focus-checks.sh` pass; `run-preview-download-checks.sh` pass; `Tests/Calls/run-presentation-checks.sh`10/10; `Tests/Contacts/run-business-checks.sh` pass; `Tests/LoginSecurity/run-checks.sh`69 pass. Combined invocation exit0. Existing ObjectMapper deprecation/tuple-label and Calls weak-var warnings only.
- No new tests that mirror visual markup. No full typecheck/build/device rendering in worker scope.

## Remaining acceptance / intentional differences

Parent must verify full iOS build and actual small/large type, keyboard, sheet, safe area, live video and deep appearance. Source parse and business tests do not establish screenshot fidelity. Native configurable removal/forward modals, true scope/category lists, real stats/notice/account content, file preview and map/permission/media picker surfaces intentionally retain functional content beyond sample PNGs. No API/network behavior changed. Shared MessagingScroll/Chrome and retained native lists still carry current theme spacing where there was no confirmed structural omission; this report does not claim every screen is pixel matched or device accepted.

## Review fix — single video safe area

Reviewer finding confirmed in source: the complete video participants ZStack, including the swap small window, had inherited `ignoresSafeArea` as a background. Narrow correction in `CallRoomView.swift`: only `mainVideo` ignores safe areas; `secondaryVideo` is now the expanding top-trailing content of the existing safe-area VStack **after** `header(call)` and its20pt spacing. Long/dynamic header therefore reserves its own height before the small window. Local/remote selection, dimensions, actual surfaces, swap callback, coordinator and controls unchanged.

Pre-fix snapshot: `/tmp/ddlNew-round2-call-safe-area/CallRoomView.before.swift`. Reviewer incremental diff: `/tmp/ddlNew-round2-call-safe-area/fix.diff`. Test output: `/tmp/ddlNew-round2-call-safe-area/presentation.log`.

Commands/output after fix:

```text
xcrun swiftc -frontend -parse ddlNew/Features/Calls/Views/CallRoomView.swift
exit0 (no output)
bash Tests/Calls/run-presentation-checks.sh
10/10 presentation checks passed
exit0; existing weak-var warnings at PresentationChecks.swift:82,106 only
git diff --check
exit0 (no output)
```

These existing presentation tests cover floating-host containment/lifetime and do not render notch/header geometry. Full iOS build and rendered validation remain parent-owned. Source frozen after this correction.

## Review fix — notice detail bottom actions

Confirmed081 detail mismatch: edit/delete were still children of the reading ScrollView. Moved the existing `canManage` action group to a bottom `safeAreaInset` with white backing and640pt content bound. Both callbacks and `.disabled(store.busy)` remain; `confirmDelete`, native deletion confirmation and `onDelete`/dismiss ownership stay in ChatNoticeDetailView. Read-only content/permission conditions unchanged.

Pre-fix: `/tmp/ddlNew-round2-notice-bottom/ChatGroupNoticesView.before.swift`. Incremental reviewer diff: `/tmp/ddlNew-round2-notice-bottom/fix.diff`. Existing test log: `/tmp/ddlNew-round2-notice-bottom/notice-store.log`.

```text
xcrun swiftc -frontend -parse ddlNew/Features/Chat/Views/ChatGroupNoticesView.swift
exit0 (no output)
bash Tests/Chat/run-notice-store-checks.sh
Notices store checks: 38 passed
exit0
git diff --check
exit0 (no output)
```

No additional source edits planned; both round1 corrections frozen for reviewer/build integration. These checks do not establish rendered long-notice safe-area acceptance.

## Review fix — check-in interactive keyboard dismissal

Added only `.scrollDismissesKeyboard(.interactively)` to CheckInScreen ScrollView, restoring the interaction previously supplied by ClubScroll introspection. Existing ClubKeyboardDismissal modifier and its done button unchanged. Snapshot: `/tmp/ddlNew-round2-checkin-keyboard/CheckInScreen.before.swift`; incremental diff: `/tmp/ddlNew-round2-checkin-keyboard/fix.diff`.

`xcrun swiftc -frontend -parse ddlNew/Features/Activities/Views/CheckInScreen.swift`: exit0, no output. `git diff --check`: exit0, no output. No repeated business suite for this single layout modifier. Source frozen.

## Review fix — private group-name/nickname editor and093 action position

Expanded ownership to `ChatSettingsView.swift` **private ChatGroupNameEditor only**. Directly viewed077/078: replaced generic MessagingCard with visible label and neutral rounded TextField surface on white ScrollView, kept interactive keyboard dismissal; moved exact existing save Task to full-width bottom safeAreaInset. `valid`, `canSave`, original/input snapshots, busy, confirmation/discard, error handling and `.rename/.nickname` remain unchanged. Group-name length has no newly added30-character restriction; existing nickname-only limit and explanation remain. Other ChatSettingsView content untouched by this correction.

Directly viewed093: the earlier retained bottom completion was an unimplemented action-position difference, not justified. Moved the exact completion closure (available-identity filtering, selection sort and dismissal) to counted navigation confirmation. Bottom area now carries selected-count summary only; scope, search, selection, all/selected controls unchanged. This supersedes the earlier MassMessageRecipientPicker retained disposition. Total assigned sources now37, with29 changed and8 retained versus the original saved baseline; newly added ChatSettings snapshot is the current parent-integrated pre-fix file, not the initial session baseline.

Review artifacts in `/tmp/ddlNew-round2-private-editors/`: `ChatSettingsView.before.swift`, `MassMessageRecipientPicker.before.swift`, `settings.diff`, `massmessage.diff`, `settings.log`, `massmessage.log`.

```text
xcrun swiftc -frontend -parse ddlNew/Features/Chat/Views/ChatSettingsView.swift ddlNew/Features/MassMessage/Views/MassMessageRecipientPicker.swift
exit0 (no output)
bash Tests/Chat/run-settings-checks.sh
Settings checks: 14 passed
exit0
bash Tests/MassMessage/run-checks.sh
26 mass message checks passed
exit0
git diff --check
exit0 (no output)
```

No build or device work performed. Source frozen for narrow reviewer recheck and parent integration.

## Final remaining-PNG pass — seven-source completion

Viewed004/105/101/014/033/033-cancel/103 PNGs and inspected each actual production composition. Parent expanded ownership to seven sources; fresh **current pre-fix** snapshots and incremental diffs are under `/tmp/ddlNew-round2-final-layouts/` (each `<Source>.before.swift` and `<Source>.diff`). Earlier baseline/report counts are historical; this pass has7 sources with new changes, including existing ChatMediaComposer. No business/domain state or helper/request changes.

| Source | PNG | Correction |
|---|---|---|
| AccountRegistrationView | 004 | Exact registration/return-login button closure, busy/succeeded/context disabled rule and identifier moved from content to bottom safeAreaInset. Fields, password clearing, connection status, keyboard done/interactive dismissal and cancel unchanged. |
| DeleteAccountScreen | 105 | Existing acknowledgment toggle and destructive confirmation action moved to bottom safeAreaInset, leaving consequence text in reading content. Same binding, disabling, confirmation and delete/erase/error request flow. |
| SettingsPageContent + SettingsScreen | 101 | Component exposes its existing logout closure as a footer; parent owns fixed bottom safeAreaInset. Full-width blue primary surface follows approved101; role/destructive confirmation remains original. Same explanatory text and signOut callback, single visible logout action. No duplicate inline action. |
| ActivityDetailScreen | 014 | Activity time and meeting point are vertical icon/value facts; generic fact/status/notice cards removed. Bottom status column moved into body with all actual state/capacity/requirement data preserved; existing status-guarded CTA now full-width. Registration/check-in/cancellation ownership unchanged. |
| ChatMediaComposer.voicePanel | 033,033-cancel | Replaced white pane +100pt decorative mic circle + floating160×60 status card/shadow/tiny prompt with full-width pale-blue recording or pale-red cancel pane, centered live waveform/cancel glyph and release label. Actual ChatVoiceRecordButton stays100×100 and callbacks onBegin/onMove/onEnd/onCancel unchanged; no expanded gesture region, new recorder state or delay. Existing220pt panel/permission disabling retained. |
| ComplaintView | 103 | Actual reason Picker now precedes image evidence, then optional content/email. Only view order changed; all fields, validation, evidence requirement/picker preparation/removal, submission guard and lifecycle unchanged. |

Final seven-source `xcrun swiftc -frontend -parse ...`: exit0, no output. `git diff --check`: exit0, no output. Existing narrow regression commands all exit0:

```text
bash Tests/Chat/run-voice-recorder-checks.sh
Voice recorder checks: passed
bash Tests/Chat/run-composer-mode-checks.sh
Chat composer transition checks passed
bash Tests/Chat/run-complaint-checks.sh
Complaint validation, request and lifecycle checks passed
bash Tests/AccountLifecycle/run-checks.sh
PASS: 账号注册输入、真实协议、连接隔离、取消和 AUTH 跳转时序
```

Logs `voice.log`, `composer.log`, `complaint.log`, `account.log` in snapshot directory. No full build or device work by worker. Source frozen for parent build/render/review; rendered recording overlay/keyboard/safe-area/deep appearance remain unverified by these business tests.

## Runtime follow-up — field surfaces and completion toolbar contrast

Confirmed token aliases in current ClubTheme: `background = HomeTheme.surface` is the white page canvas; `wash = HomeTheme.background` is the neutral input surface. Changed **only** CheckInScreen numeric field and RegistrationScreen member input face from `ClubTheme.background` to `ClubTheme.wash`. No global token edits.

Viewed parent's actual `/tmp/ddlNew-newUI-5-round2-runtime/027-information.png`: native 完成 appeared white on light gray. InformationSheet and SettingsScreen existing toolbar 完成 now explicitly use `.buttonStyle(.plain)`, `.foregroundStyle(ClubTheme.teal / HomeTheme.forest)` and `.frame(minHeight: 44)`; dismiss closures unchanged.

Four pre-fix snapshots and matching incremental `<Source>.diff` under `/tmp/ddlNew-round2-field-toolbar/`. Four-source `xcrun swiftc -frontend -parse`: exit0, no output; `git diff --check`: exit0, no output. No business suite repeated for these surface/toolbar modifiers. Source frozen; parent owns rendered recheck.

## Review fix — voice idle graphic hit alignment

Reviewer confirmed prior100×100 transparent control started66pt below pane top while visible mic starts32pt. Changed only control top padding66→24pt. The same centered100×100 control now covers idle mic (top32–72pt) and 按住说话 label; full pane is still not the hit region. No gesture size/state/callback or slide-out cancellation rule changes.

Pre-fix snapshot `/tmp/ddlNew-round2-voice-hit-alignment/ChatMediaComposer.before.swift`; one-line incremental diff `/tmp/ddlNew-round2-voice-hit-alignment/fix.diff`; `voice.log`/`composer.log` same directory.

```text
xcrun swiftc -frontend -parse ddlNew/Features/Chat/Components/ChatMediaComposer.swift
exit0 (no output)
bash Tests/Chat/run-voice-recorder-checks.sh
Voice recorder checks: passed
bash Tests/Chat/run-composer-mode-checks.sh
Chat composer transition checks passed
git diff --check
exit0 (no output)
```

Source frozen. Tests verify recorder/state transitions, not rendered long-press geometry; parent retains final runtime check.

## Final semantic surface fix — complaint103

Confirmed source: MessagingScroll used gray background identical to complaint field faces. Replaced this page's wrapper with native ScrollView + explicit white `MessagingTheme.surface` and interactive keyboard dismissal. Existing actual640pt max-width content/footer constraints preserved (current source was640, not600); no global scroll/theme changes. Reason Picker now has the same neutral rounded input face as editor/email/evidence, with52pt minimum. All field bindings, handlers, validation and draft lifecycle unchanged.

Pre-fix snapshot/diff/log under `/tmp/ddlNew-round2-complaint-surface/`: `ComplaintView.before.swift`, `fix.diff`, `complaint.log`.

```text
xcrun swiftc -frontend -parse ddlNew/Features/Safety/Views/ComplaintView.swift
exit0 (no output)
bash Tests/Chat/run-complaint-checks.sh
Complaint validation, request and lifecycle checks passed
exit0
git diff --check
exit0 (no output)
```

Combined finalbatch voice alignment + complaint surface changes frozen for reviewer and root runtime/build recheck.

## Actual-render follow-up — toolbar item role

Viewed `/tmp/ddlNew-newUI-5-round2-runtime/101-settings-verified.png`; system confirmationAction still imposed unreadable prominent appearance despite explicit plain/brand text. Changed **only** InformationSheet and SettingsScreen toolbar placement `.confirmationAction`→`.topBarTrailing`; existing plain style, brand foreground,44pt minimum and dismiss callbacks untouched.

Snapshots and one-line per-source diffs: `/tmp/ddlNew-round2-toolbar-placement/{InformationSheet,SettingsScreen}.{before.swift,diff}`. Two-source frontend parse exit0; diff-check exit0. No other changes/tests. Frozen for root rebuild and actual rendered verification.

## Actual-render follow-through — positive confirmation toolbar actions

After parent confirmed `.topBarTrailing` fixes system confirmationAction white-on-gray styling in101 and observed same problem in068 selected state, applied the identical local fix to positive confirmation toolbar items only in GroupMemberPickerView, CallMemberSelectionView, ContactRemarkEditor, ContactsRecipientPickerView, MassMessageRecipientPicker and ChatForwardRecipientView's nested confirm-send. Each uses `.topBarTrailing`, explicit `.buttonStyle(.plain).foregroundStyle(MessagingTheme.accent)` and at least44pt height. All original action closures and disabled guards remain byte-for-byte unchanged; no destructive confirmations, cancellations or legacy demos changed.

Six current pre-fix snapshots plus per-source incremental diffs: `/tmp/ddlNew-round2-positive-toolbar/<Source>.{before.swift,diff}`. Combined six-source frontend parse exit0; `git diff --check` exit0. Personally reviewed all six incremental diffs: placement/presentation modifiers only. Existing selection/presentation business tests not repeated for unchanged logic. Source frozen for review and parent rendered validation.
