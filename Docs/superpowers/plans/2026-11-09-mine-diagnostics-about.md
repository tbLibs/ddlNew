# Mine Diagnostics and About Implementation Plan

> Execute with superpowers:executing-plans. User approved direct implementation.

Goal: Add both Mine entries with DNS1-only diagnostics and current product information.
Architecture: Page-owned cancellable store, injected diagnostic runner, reuse production DNS1 decoding and independent ECDH transport. No connection selection writes.
Tech Stack: SwiftUI, Foundation, Network, existing NoaChatCore.
Spec: ../specs/2026-11-09-mine-diagnostics-about-design.md

## Constraints
Keep existing uncommitted migration. No legacy navigation, IP collection, Flutter, commits or symbol uploads.

## Review Focus
Cancellation during source loading; late callbacks after retry; same UID new session; no available nodes; maximum Dynamic Type.

## Tasks
- [x] Add diagnostic event runner and tests for fallback, success stopping, failure and cancellation.
- [x] Add page-owned store and transports with bounded requests and session validation; wire Mine routes.
- [x] Add About with actual bundle icon/version and existing legal documents.
- [x] Run diagnostic and DNS1 regressions, generic iOS unsigned build, review diff; update handoff.

Execution: 8 new checks and DNS1 43 + DoH passed. Independent read-only review found no important issues; hit target and missing fallback asset corrected. No commit/push. Final build log: /tmp/ddlNew-mine-support-final.log. Device visual/interaction validation remains unperformed.
