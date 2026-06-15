# PVMRC Migration

## Status
Done

## Description
Migrate project version hints from legacy `.php-version` to `.pvmrc`, with `Project` discovery and activators reading the canonical file name.

## Phases
### Phase 1: Domain and discovery
- Status: Done
- `Project` walks ancestors for `.pvmrc` / `.pvm` markers

### Phase 2: Commands and docs
- Status: Done
- `use`, `php`, and doctor messaging aligned with `.pvmrc`

## Progress Log

### 2026-05-25
- Integration branch consolidates `.pvmrc` as the project hint file
- Tests cover ancestor walk and missing-config errors

## Conclusion
`.pvmrc` is the single project version hint; legacy filenames removed from hot paths.

## Suggestions
- Optional `pvm migrate` command for repos still on `.php-version`
