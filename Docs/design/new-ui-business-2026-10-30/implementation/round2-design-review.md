# Round 2 independent design audit

2026-10-30, feature-newUI-5. Read-only production review; only this report written. No build, devices, business actions, commits or source edits. Other worker owns 27 remaining shared-style sources; their in-flight work is excluded from duplicate findings. Source mapping is not visual completion.

## Confirmed omissions outside the 27-file implementation scope

Each row is confirmed against the current source and personally viewed approved PNG. Paths below are relative to ddlNew/Features/. Priorities concern approved design fidelity, not proven runtime crashes. Preserve current values, eligibility, handlers, lifecycle, and request ownership.

|Priority|Design IDs|Source / exact view|Confirmed gap|Specific remedy|
|---|---|---|---|---|
|P1|086,087,088,089; 087-wait associated|Calls/Views/CallRoomView.swift: header, participants, controls, action|Header is small title3 near top; audio duplicates peer name below avatar; all controls are 58pt circles; connected hangup remains small circle. Approved images use one large identity heading, circular avatar, low incoming pills and full-width connected hangup. Video stays inside padded rounded container. Group adaptive105 grid creates three columns at common phone widths whereas approved089 has two broad tiles.|Recompose phase-specific layout with one identity heading, circular audio avatar, two-column adaptive group layout, full-width bottom hangup and incoming low pill actions; keep actual video surfaces, swap action, additional invite, per-person state and control enabled conditions. Large text may require adaptive layout, not fixed pixel recreation.|
|P1|023,024; 023-error associated|Activities/Views/CheckInScreen.swift|Input uses four bordered digit boxes with nearly invisible TextField, badge and centered inset ClubCard. Success remains the same form card with small icon and status section. Approved023 uses single labeled gray-blue field and bottom confirmation;024 is a distinct sparse success composition with bottom completion.|Use one visible numeric field bound to existing code, retain four-digit sanitization and existing checkIn handler. Bottom-pin confirmation with same disabled condition. Render checkedIn as result composition; reuse existing dismissal/navigation ownership for completion. Never mark success without checkedIn.|
|P1|015|Activities/Views/RegistrationScreen.swift|Three ClubCard sections with category badge, avatar/member-account and switch; confirmation follows content. Approved015 uses compact activity summary, labeled gray-blue member display, agreement row and bottom confirmation.|Flatten existing fields into approved hierarchy, retain all genuine account/notice data, switch binding and acceptance semantics. Place submit in bottom safe-area action preserving saving/accepted and exact register/completed flow. Checkbox appearance is presentation only.|
|P1|016,017|Activities/Views/RegistrationResultScreen.swift|72pt rounded-square icon, result heading, date/shield confirmation card, button follows content. Approved uses large outlined circular success glyph, sparse centered result/title/details, bottom action.|Recompose success/waiting using existing status, activity title/date/meeting data and onDone callback. Bottom-anchor completion; avoid replacing meaningful real data with sample strings.|
|P2|097|Mine/Views/MineProfileView.swift: row|Nickname/account label and value are opposite ends of HStack; approved097 is leading label then value below with trailing accessory. Outer16 plus row16 increases inset.|Use leading label/value VStack and trailing existing chevron. Preserve read-only account behavior. Approved copy affordance is not authority to add a new account mutation; adding copy is optional existing-business capability decision.|
|P2|098|Mine/Views/MineProfileView.swift: MineNicknameEditor|No visible nickname label; save lives in toolbar. Approved098 has label and bottom save. Gray-blue field and outside counter already exist.|Add visible field label and bottom save using exact canSaveNickname/busy/saveNickname/dismiss contract. Keep character explanation, clear action and draft behavior.|
|P2|005|Login/Views/LoginVerificationSheet.swift: imageCaptcha / continueButton|Bare intrinsic captcha image, missing explicit input label, continue immediately after input. Approved005 has wide gray-blue image surface, labeled field and bottom continue.|Add image surface and field label, anchor existing continueButton at bottom for image/security input branches. Leave third-party web layout and loading/error lifecycle intact; never draw fake captcha.005-failed remains error-state evidence only.|
|P2|026|Club/Views/ClubScreen.swift|Centered mountain, statistics row and numbered how-to still dominate; approved026 starts leading club title/description and editorial section headings.|Reflow existing club title, description and how-to into leading editorial hierarchy; preserve all existing info routes and useful statistics as secondary real content. Do not replace club mountain symbol with app logo merely for brand consistency.|
|P2|027|Club/Views/InformationSheet.swift|Every paragraph uses body style inside ClubCard padding22 + outer20; card also adds bottom rule. Approved027 has heading/body contrast and simpler page margins.|Flatten document surface; style actual heading entries where the existing InformationPage identifies them. Current announcements first paragraph is genuinely title-like; do not invent “参与活动前” text absent from data. Keep all paragraphs and text selection.|
|P2|032|Chat/Components/ChatMediaComposer.swift: inputRow / tools|Always-visible tools use calls-first five-column layout (video,audio,album,camera,file); approved expanded032 is attachments-first four-column wrap. Input mic is right, smiley embedded, no separate expansion affordance.|Align expanded panel order/grid and input affordance positioning using existing permissions/callbacks. Do not invent a new panel state or new feature merely to copy a plus glyph: current ChatComposerMode has typing/stickers/voice semantics. Root must preserve established composer interaction and explicitly decide any expand/collapse behavior change.|

## Justified differences and non-findings

- 099 avatar source uses native confirmationDialog;100 uses native UIImagePickerController editing. Native sheet/crop appearance and available-camera filtering are justified; no custom fake picker needed.
- System menus, alerts, permission UI, file importer, camera, photo picker, WKWebView challenge and JXPhotoBrowser can remain native. Their content/affordances must still be visible, but static illustration appearance is not a missing layout by itself.
- 027 sample heading that does not exist in InformationPage must not become synthetic business content. Existing information routes differ from sample labels; preserve actual routes.
- 032 attachment order/layout mismatch is confirmed; new expansion state is not automatically authorized by the visual audit.
- Activity record details use existing ActivityDetailScreen. Its title, facts, status, notice and bottom action are present; do not erase real participation states to match available-registration sample. RecordsScreen itself is owned by other worker.
- Existing 12-file fixes (profile detail, remarks/groups/password, selections, settings, mass-message) should not be undone. Their DIRECT-EDIT label never implied every branch visually matched.

## Inventory reconciliation and limits

Enumerated every pages.json source, excluded legacy065, resolved all66 production source labels, and scanned every resolved production source for layout containers and private sheets/editors. LegalDocumentScreen / RemoteLegalPage is one design source label with its secondary web view within source. This is inventory coverage, not66 screenshot passes.

27 sources in remaining-layout-brief.md are delegated/in-flight; no duplicate source edits made. The10 confirmed source groups above include11 view compositions because MineProfileView includes private nickname editor. Other direct sources retain current implementations pending runtime review; absence of an additional confirmed finding is not a visual pass.

Personally viewed approved PNGs in this review:005,015,016,017,023,024,026,027,032,086,087,088,089,097,098,099. No actual runtime screenshots examined this round. All findings are design/source comparisons; keyboard, dynamic type, deep appearance, sheets, streaming video, calls, real registration/check-in and server submission remain unverified. No production tests executed because scope was read-only and no build/devices were authorized for this subtask.

## Complete 66-source disposition

SCANNED means located and structural source scanned this round; it does not mean visually approved. CONFIRMED entries have PNG evidence above. IN-FLIGHT ownership is explicit and cannot be counted closed here.

|Source|Design IDs|Disposition|
|---|---|---|
|LaunchScreen.storyboard|001|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|InvitationCodeView|002|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|LoginView|003, 010, 011, 003-empty, 003-busy|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|AccountRegistrationView|004|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|LoginVerificationSheet|005, 005-failed, 006-code|CONFIRMED omissions above|
|LoginCaptchaWebView|006, 006-failed|SYSTEM: native/provider surface; surrounding chrome still requires runtime review|
|PasswordChangeView|007, 008, 009|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|ClubHomeView|012|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|ActivitiesScreen|013, 121|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|ActivityDetailScreen|014, 025, 014-wait, 014-joined|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|RegistrationScreen|015|CONFIRMED omissions above|
|RegistrationResultScreen|016, 017|CONFIRMED omissions above|
|RecordsScreen|018, 019, 020, 021|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|CheckInSelectionScreen|022|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|CheckInScreen|023, 024, 023-error|CONFIRMED omissions above|
|ClubScreen|026|CONFIRMED omissions above|
|InformationSheet|027|CONFIRMED omissions above|
|MessageView|028|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|GlobalSearchView|029, 111|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatRoomView|030, 031, 034, 035, 115, 030-failed|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatMediaComposer|032|CONFIRMED omissions above|
|ChatVoiceRecordingMeter|033, 033-cancel|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|ChatMessageEditorView|036|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatMentionPickerView|037|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|ChatHistorySearchView|038|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatForwardRecipientView|039, 040|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatForwardRecordView|041|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatPinnedMessagesView|042|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatPinActionView|043|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatStickersView|044|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatPhotoBrowserView|045, 046, 114|SYSTEM: native/provider surface; surrounding chrome still requires runtime review|
|ChatMediaDetailView|047, 048|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatLocationDetailView|049|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatSettingsView|050, 066, 077, 078, 084, 085, 116, 119, 066-member, 066-owner|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|ContactsView|051, 052|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|AddFriendView|053, 054|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|NewFriendsView|055|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ContactRecordDetailView|056, 057, 056-stranger, 056-blocked|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|ContactRemarkEditor|058, 118, 058-error|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|FriendGroupManagerView|059|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|FriendGroupNameEditor|060|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|ContactGroupPicker|061|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|BusinessQRCodeView|062, 079|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|BusinessQRScannerView|063|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ContactsRecipientPickerView|064|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|GroupMemberPickerView|067, 068, 069|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|ChatGroupMembersView|070, 074, 075|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatGroupRemovalView|071, 072|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatGroupManagementView|073, 113, 120|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatGroupAvatarView|076|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ChatGroupNoticesView|080, 081, 082|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|GroupApplicationsView|083, 083-pending|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|CallRoomView|086, 087, 088, 089, 087-wait|CONFIRMED omissions above|
|CallMemberSelectionView|090|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|MassMessageView|091, 091-accepted|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|MassMessageComposerView|092, 095, 092-error, 092-attachment|SCANNED: earlier 12-file structural fixes present; no new confirmed gap, runtime still pending|
|MassMessageRecipientPicker|093|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|MassMessageRecipientsView|094, 094-failed|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|MineView|096, 108|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|MineProfileView|097, 098, 099, 100|CONFIRMED omissions above|
|SettingsScreen|101, 107|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|BlacklistView|102, 112, 117|IN-FLIGHT: remaining-layout worker; consume its source/PNG report|
|ComplaintView|103, 104, 103-ready, 103-busy, 103-error|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|DeleteAccountScreen|105, 106, 105-ready|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|
|LegalDocumentScreen / RemoteLegalPage|109, 110|SYSTEM: native/provider surface; surrounding chrome still requires runtime review|
|LaunchWaitingView|001-wait|SCANNED: direct production implementation present; no new confirmed gap, full visual pass not claimed|

## Final representative-PNG gap pass (42 previously uncovered sources)

This addendum replaces the earlier SCANNED-only limitation for the following42 source labels: each now has a personally viewed representative approved PNG and source composition comparison. Images are actual approved PNG contact sheets `/tmp/audit-final-0.png` through5 plus006 individually; not runtime screenshots. Together with the33-PNG independent implementation review, every66 production source label has representative source/PNG evidence. This still does not mean146 state variants or runtime visuals passed.

New actionable omissions sent to root immediately:

|Priority|ID|Exact source/composition|Remedy preserving business|
|---|---|---|---|
|P2|004|Login/Views/AccountRegistrationView.swift: primary registration button inside scrolling VStack|Bottom-anchor existing button, keeping accountWasRegistered return branch, disabled/phase/context guards and clearing lifecycle. Approved has bottom action; extra heading and connection feedback may remain as real context.|
|P2|014|Activities/Views/ActivityDetailScreen.swift: fact layout + safeAreaInset|Replace side-by-side labeled card columns with stacked icon/value metadata rows; existing title/category/requirement/status/notice stay. Full-width existing CTA at bottom; move real status summary into body rather than narrow CTA with90pt status column. Keep all status routing/disabled logic.|
|P2|101|Mine/Components/SettingsPageContent.swift: logout group|Existing logout button is inline after account management; approved pins full-width logout bottom. Parent SettingsScreen should own safe-area action using same callback and retain explanatory copy. Do not duplicate logout.|
|P2|105|Mine/Views/DeleteAccountScreen.swift: acknowledgment and submit|Move existing acknowledgment/submit region to bottom safe-area layout; maintain acknowledged/deleting disables and native final alert. Preserve all actual consequence copy despite sample being shorter.|
|P2|033,033-cancel|Chat/Components/ChatMediaComposer.swift: private voicePanel, not ChatVoiceRecordingMeter alone|Approved active recording is full-width pale-blue/pale-red panel with central waveform and release/cancel label. Current retains100pt mic circle plus floating160×60 blue/red card,10pt prompt and offset-70. Recompose presentation from existing voicePress.isHolding/isInside, recorder.level/duration; keep ChatVoiceRecordButton hit region and onBegin/onMove/onEnd/onCancel unchanged. No gesture/state rewrite required.|
|P3|103|Safety/Views/ComplaintView.swift: main VStack order|Approved reason precedes evidence, actual evidence precedes reason. Reorder existing reason then evidence then content/email, preserving Picker/PhotosPicker/draft handlers and bottom submit. Native menu selection is justified.|

Root independently found077/078 private ChatGroupNameEditor and093 completion placement; current source now has gray input + bottom save and counted navigation completion respectively. These are SOURCE-CLOSED on reinspection, not runtime acceptance.

|Source|Viewed PNG|Concrete comparison / disposition|
|---|---|---|
|LaunchScreen.storyboard|001|Selected smiling asset, centered brand/logo and white canvas; no fake timing. No new omission.|
|InvitationCodeView|002|Leading brand/title, labeled neutral input and clear connection action; actual legal links retained. No new composition omission.|
|LoginView|003|Brand/leading welcome, labeled fields, legal consent, main login and registration; native remember toggle and alert justified. Actual connection feedback retained. No new omission requiring business additions such as invented club name.|
|AccountRegistrationView|004|Labeled fields match; bottom registration placement missing as above.|
|LoginCaptchaWebView|006|Real third-party WKWebView owns challenge; surrounding sheet owns loading/retry. Static gray challenge illustration must not replace provider. Leading sample heading absent but not a major new composition blocker.|
|PasswordChangeView|007|Labeled neutral old-password field and bottom next/exit; new/success branch also explicitly composed. No remaining Form shell.|
|ClubHomeView|012|Source uses featured date/title/status/action, quick-entry strip and recent flat activities, same existing destinations. No new missing composition.|
|ActivitiesScreen|013|Search, underline tabs and zero-gap ActivityCard list; real empty state. No new omission.|
|ActivityDetailScreen|014|Metadata columns and narrowed bottom action mismatch above; real status/requirement/notice are legitimate extra content.|
|RecordsScreen|018|White zero-gap ActivityCard→HomeActivityRow, separators and genuine status; no generic outer cards remain. No new omission.|
|CheckInSelectionScreen|022|Plain title/date/status/chevron rows, real eligible activities and NavigationLink. No new omission.|
|MessageView|028|Explicit body title, search/tabs, conversation rows and unread/pin/failure indicators; native toolbar/tabbar retained. No new omission.|
|GlobalSearchView|029|Fixed search, per-kind count headings and flat avatar/title/detail/result links. Four real result categories rather than example categories justified. No new omission.|
|ChatRoomView|030|Actual chronological bubbles and composer; native menu/selection/sheets preserve source ownership. Root/composer changes treated separately; no new whole-room omission.|
|ChatVoiceRecordingMeter|033|Meter is only waveform component; actual missed active pane is private ChatMediaComposer.voicePanel above. Do not mark entire033 complete by changing meter tint.|
|ChatMentionPickerView|037|Name/real role secondary line + chevron plain list; native searchable placement justified. No new omission.|
|ChatHistorySearchView|038|Search+tabs, flat results, optional genuine member filter. Full-width member row accommodates real long names; not a missing business tab.|
|ChatPinnedMessagesView|042|Zero-gap source rows and separators with locate/dismiss; real instruction retained. No new omission.|
|ChatPhotoBrowserView|045|JXPhotoBrowser actual media canvas and toolbar, video/media lifecycle; native black preview justified. No fake image background required.|
|ChatLocationDetailView|049|Actual Map main surface + genuine location and bottom system-map link. Native map appearance justifies sample graphic difference.|
|ChatSettingsView|050,077|Plain setting sections; private group-name/nickname editor now independent neutral field + bottom save. Current source reinspection closes root's077/078 finding.|
|ContactsView|051|Title/search/shortcuts/tabs/indexed rows; real sections and permission-filtered shortcuts preserved. No new omission.|
|ContactRecordDetailView|056|Flat identity, leading details and bottom send; actual role/online/eligibility retained. No new omission.|
|ContactRemarkEditor|058|Independent labeled gray fields, outside counts, navigation save as approved. No new omission.|
|FriendGroupManagerView|059|Plain groups, native more/reorder, navigation add; default-group constraints preserved. No new omission.|
|FriendGroupNameEditor|060|Independent labeled gray name field and bottom save; add/edit title difference genuine. No new omission.|
|ContactGroupPicker|061|Plain target list, selected indicator and bottom add route; direct commit semantics preserved. No new omission.|
|BusinessQRScannerView|063|Actual camera, native photo picker, real result pane now flat; no fake scanning illustration. No new omission.|
|ContactsRecipientPickerView|064|Plain checkmark/avatar/name sections, search, counted navigation share and bottom selection summary. No scope state exists; do not invent tabs just to mimic sample.|
|GroupMemberPickerView|067|Search/underline tabs, checkmarks, bottom true chosen-avatar summary and navigation completion. Optional review reason preserved; not a generic Form.|
|CallMemberSelectionView|090|Left checkmark/avatar/name and already-in-call secondary, native search, counted navigation confirm. No new omission.|
|MassMessageView|091|Flat task status/title/body/actions and real receiver/failure routes; no new omission.|
|MassMessageComposerView|092|Object summary, labeled neutral tag/body, attachment action and bottom submission; exact resend locks retained. No new omission.|
|MassMessageRecipientPicker|093|Current counted navigation completion replaces old bottom action; existing selected summary remains. Root finding closed at source.|
|MassMessageRecipientsView|094|Plain actual name/type/error rows; all/failure are route-owned stores, so do not invent local tabs requiring different data. No new omission.|
|MineView|096|Actual profile/account/QR and four flat record routes, club and support sections. Extra real section labels/club glyph do not require deleting routes. No new missing composition.|
|SettingsScreen|101|Account/support/management rows present; bottom logout placement omission above.|
|BlacklistView|102|Plain avatar/name/account + explicit移出, real initial sections. Native section labels are valid list structure. No new omission.|
|ComplaintView|103|Neutral reason/content/email, evidence grid, bottom submit present; section ordering omission above.|
|DeleteAccountScreen|105|Consequences and acknowledgment real; bottom placement omission above. Native destructive alert preserved.|
|LegalDocumentScreen / RemoteLegalPage|109|Actual WKWebView with center loading/error/retry and completion; remote document layout cannot be statically recreated. No new omission.|
|LaunchWaitingView|001-wait|Instantiates genuine storyboard; existing root supplies actual connection progress. No duplicate/fake spinner. No new omission.|

Final audit distinction:66/66 representative production sources have design/source evidence across this report and round2-review.md. Confirmed addendum gaps above remain open until root integrates them. Every state-specific menu/error/busy branch and runtime geometry is not certified by this representative pass. No build or device execution performed.
