# Things To Fix

Audit date: March 11, 2026

## 1. ~~Critical: `commitAndPush()` can create dangling commits in detached HEAD~~ FIXED

**Fix:** Added `ensureAttachedHeadForSourceRepo()` call at the start of `commitAndPush()` so detached HEAD is detected and repaired before any commit attempt.

- `ChezmoiSyncMonitor/Services/ChezmoiService.swift`

## 2. ~~High: Detached-HEAD auto-repair can orphan prior detached commits~~ FIXED

**Fix:** `ensureAttachedHeadForSourceRepo()` now creates a safety branch (`detached-backup-<sha>`) from the current detached HEAD before switching to the tracking branch. This preserves the commit so it is not lost to garbage collection.

- `ChezmoiSyncMonitor/Services/ChezmoiService.swift`

## 3. ~~High: Remote drift can be reclassified as local drift after `pullSource()`~~ FIXED

**Fix:** Added a `pendingRemoteFiles` sticky set to `AppStateStore`. When `behind > 0`, the remote-changed file set is stored. When `behind` drops to 0 (post-pull), the sticky set is merged into classification input and only pruned when files no longer appear in `chezmoi status` (i.e., apply succeeded).

- `ChezmoiSyncMonitor/State/AppStateStore.swift`

## 4. ~~Medium: Tool/source-repo overrides are persisted but not wired into runtime services~~ FIXED

**Fix:** `createAppState()` now reads saved preferences via `PreferencesStore().load()` and passes `chezmoiPathOverride`/`gitPathOverride` to the `ChezmoiService` and `GitService` constructors. A restart-required note was added to the Preferences Tools tab since services are constructed once at launch.

- `ChezmoiSyncMonitor/App/ChezmoiSyncMonitorApp.swift`
- `ChezmoiSyncMonitor/UI/Preferences/PreferencesView.swift`
- `ChezmoiSyncMonitor/Resources/Strings.swift`
- `ChezmoiSyncMonitor/Resources/Localizable.strings`

## 5. ~~Medium: Destructive apply is not revalidated at execution time~~ FIXED

**Fix:** `updateSingle()` now validates that the file is still in `remoteDrift` or `dualDrift` state before proceeding. If the file is missing from the snapshot or in a different state, the apply is aborted with a logged error. `updateSafe()` also revalidates each file before applying in the batch loop, with skipped-count tracking.

- `ChezmoiSyncMonitor/State/AppStateStore.swift`

## Notes

- No hard-destructive git commands were found (`reset --hard`, `clean -fd`, forced checkout).
- This is a static audit; no end-to-end detached-HEAD integration scenario was executed.
- All 127 tests pass after fixes (126 existing + 1 new test for state-change abort).
