# Privacy integration

- App manifest describes the current local implementation: no tracking or off-device collection by app business code. Re-audit when networking changes.
- WCDB 2.1.16 with SQLCipher 1.4.7: FileTimestamp / C617.1 covers metadata for database files within the app container. The Xcode build phase inserts this manifest in the actual SPM framework before Embed Frameworks signs it. Xcode uses `PackageFrameworks/` for normal builds and the real product under OBJROOT/UninstalledProducts for install/archive builds (avoiding sandbox writes through the BUILT_PRODUCTS_DIR symlink); nested build settings select the correct path.
- **Open issue:** SQLCipher imports statfs/fstatfs for filesystem locking flags. This is not evidence for a sufficient-free-space check. No unsupported DiskSpace reason is asserted. Resolve with upstream or a verified SDK change before submission.
- SwiftUIX 0.3.2 has no resources in Package.swift. `ddlNew/Legal/SwiftUIX_Privacy.bundle` carries C56D.1 for its UserDefaults wrapper functions. Release dead stripping can remove these wrappers; retaining the SDK's wrapper declaration covers Debug and future calls without an inaccurate app-global reason.
- UIAdapter bundles its own manifest. TBBasicLib remains a resolvable SPM dependency but is not linked into the app target.
- Recheck archived manifests and `codesign --verify --deep --strict` whenever dependencies change. Do not edit cached checkouts as a persistent fix.
