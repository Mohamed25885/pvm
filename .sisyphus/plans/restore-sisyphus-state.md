# Recovery: Restore .sisyphus Agent State

## Status
To Do

## Context
During a cleanup operation, the `.sisyphus/` directory was accidentally removed from the working tree and `.gitignore` was modified to exclude it. This directory contains critical agent planning state and **must be tracked** by git.

The `AGENTS.md` file (recently updated) describes policies that were violated by performing destructive git operations without permission.

## Objective
Restore the `.sisyphus/` directory to its correct state and ensure it remains tracked by git.

## Steps

### Step 1: Recover .sisyphus from reflog
The last commit that contained `.sisyphus/` was `ce03cc1` (fixup! Document pvm composer...). Use git to restore the directory from that commit:

```bash
# Show .sisyphus/ contents from commit ce03cc1 to verify
git ls-tree -r ce03cc1 -- .sisyphus/

# Restore the directory and all its contents to working tree
git checkout ce03cc1 -- .sisyphus/
```

This will bring back all planning files:
- `.sisyphus/plans/` (multiple plan documents)
- `.sisyphus/drafts/` (draft plans)
- `.sisyphus/notepads/` (decision logs, issues, learnings)
- `.sisyphus/ralph-loop.local.md` (loop state)
- `.sisyphus/boulder.json` (boulder state)

### Step 2: Revert .gitignore modifications
Remove the lines that incorrectly ignore `.sisyphus/`:

```bash
# Edit .gitignore and remove these lines if present:
# - # Agent workspace (runtime state, not committed)
# - .sisyphus/
```

Or revert `.gitignore` to the state before the erroneous edit (from commit `20a9779` or later):

```bash
git checkout 20a9779 -- .gitignore
```

Then manually ensure the file does NOT contain `.sisyphus/` in ignore patterns.

### Step 3: Ensure .sisyphus/ is tracked
After restoring, run:

```bash
git status .sisyphus/
```

All files should show as "untracked" (ready to be staged). Verify they are not ignored:

```bash
git check-ignore -v .sisyphus/plans/add-composer-proxy-command.md
```

Should return nothing (not ignored).

### Step 4: Stage and commit (if needed)
If `.sisyphus/` files were previously committed and we're just restoring them, they should already be tracked in the commit `ce03cc1`. After `git checkout ce03cc1 -- .sisyphus/`, the working tree will have them and git will see them as "modified" (content matches commit). This is fine; no new commit is required unless we made intentional changes to these files later.

If we intentionally updated `.sisyphus/plans/add-composer-proxy-command.md` after that commit, we may need to re-apply those updates manually or cherry-pick the changes.

### Step 5: Verify final state
```bash
git status
```

Should show:
- `.sisyphus/` directory present with all files
- `.gitignore` without `.sisyphus/` exclusion
- No untracked files that should be tracked

---

## Notes
- **Do not perform another history rewrite** — this recovery only touches the working tree.
- **Do not use `git reset --hard` or `git rebase`** — we already have a good commit history; we only need to restore missing files.
- The `.sisyphus/` folder is essential for agent continuity and must remain tracked.

---

**Plan created to guide recovery without violating Git Operations Policy.**
