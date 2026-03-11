# Plan To Fix Remote Apply Issues

## Scope
This plan addresses the issues observed when clicking `Apply` on a single remote-drift file:
- Row-level `Apply` triggers a global update instead of a file-scoped apply.
- A failure in another file (example: `Library/Preferences/com.pilotmoon.popclip.plist: EOF`) can block the requested file.
- Activity Log is ambiguous about what was requested vs what actually failed.
- After a failed apply, UI state can remain stale because refresh is not forced.

## Goals
1. Row `Apply` must apply only the selected file.
2. Batch apply must be explicit and clearly labeled as batch.
3. Failures must be isolated and observable per file.
4. Activity Log must explain intent, scope, and result.
5. Snapshot/UI must always refresh after apply attempts (success or failure).

## Non-Goals
- Redesigning the full dashboard layout.
- Changing conflict detection rules.
- Adding cloud/network retry orchestration.

## Implementation Plan

### Phase 1: Separate Single-File vs Batch Operations
1. Extend `ChezmoiServiceProtocol` with a dedicated single-file apply method:
   - `func apply(path: String) async throws -> CommandResult`
2. Implement the method in `ChezmoiService`:
   - Resolve path to destination path (same style used by `add` and `diff`).
   - Use a file-targeted `chezmoi apply` invocation (verify exact CLI args against local `chezmoi help apply` before coding).
3. Keep batch operation explicit:
   - Rename current `update()` path in call sites to batch semantics (method name can stay if refactor risk is high, but behavior/docs must clearly say "batch").

### Phase 2: Fix Dashboard Row Apply Flow
1. Replace row apply action to call a new state method:
   - `appState.updateSingle(path:)`
2. Keep per-row confirmation dialog, but bind the action to single-file apply only.
3. Remove dead/placeholder code that stores the selected path but does not use it for the command.

### Phase 3: Make Batch Apply Robust
1. Rework `updateSafe()` to run per-file applies for `remoteDrift` files instead of one global `chezmoi update` call.
2. Continue on per-file failure:
   - Record success/failure per file.
   - Finish the batch and report a summary.
3. Optional fast path:
   - If no per-file errors historically and user triggers explicit "Apply All Remote", allow global update mode behind a future preference.

### Phase 4: Improve Activity Log Clarity
1. Log an intent event before execution:
   - Single: `Applying remote changes for <path>`
   - Batch: `Applying remote changes for N files`
2. Log precise outcomes:
   - Single success/failure includes path.
   - Batch summary includes `X succeeded, Y failed`.
3. Preserve raw CLI failure detail for diagnostics, but prefix with operation context:
   - Example: `Apply failed for <requested-path>: <chezmoi error>`

### Phase 5: Always Refresh State After Apply Attempt
1. In `updateSingle` and `updateSafe`, force refresh in a `defer`-equivalent flow so UI updates even after failures.
2. If refresh itself fails, log a separate refresh error event (do not hide apply result).

### Phase 6: Use Existing Preference Correctly
1. `batchSafeSyncEnabled` currently exists but is not driving apply behavior.
2. Define expected behavior:
   - `false`: row-level actions only (no "Apply All Safe" quick action), or keep button but require explicit confirmation.
   - `true`: allow batch quick action.
3. Align menu/dashboard labels with actual behavior.

## Tests

### Unit Tests
1. `AppStateStore.updateSingle(path:)`:
   - Calls `chezmoiService.apply(path:)` with the selected path.
   - Logs success/failure with selected path.
   - Always calls `forceRefresh()`.
2. `AppStateStore.updateSafe()`:
   - Applies each remote file independently.
   - Continues after one file fails.
   - Emits correct batch summary.
   - Always refreshes.
3. `ChezmoiService`:
   - Path resolution for apply command (`~/...` conversion).
   - Command args for single-file apply.

### UI/Behavior Tests
1. Dashboard row `Apply` triggers single-file method (not batch).
2. Menu `Apply Safe Remote` triggers batch method.
3. Activity log lines include requested path and clear scope.

### Manual Verification
1. Scenario A: two remote files, one malformed (`EOF`), one valid:
   - Applying valid file succeeds even if malformed file exists.
2. Scenario B: click row apply on `karabiner.json`:
   - No unrelated file apply attempt appears as the primary operation.
3. Scenario C: failed apply:
   - Refresh runs and UI reflects current drift accurately.

## Acceptance Criteria
1. Row apply is strictly file-scoped.
2. A failure in file A does not prevent applying file B in batch mode.
3. Activity log unambiguously states operation scope and target path.
4. After any apply attempt, counts/list reflect a post-operation refresh.
5. Existing add/diff behavior remains unchanged.

## Suggested Execution Order
1. Phase 1 + Phase 2 (correctness for row apply first).
2. Phase 4 + Phase 5 (observability and trust).
3. Phase 3 (batch robustness).
4. Phase 6 (preference wiring and UX consistency).
5. Tests and manual validation sweep.
