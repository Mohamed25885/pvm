# PVM File Structure Refactoring (lib/ Structure)

## Status

**Completed**

---

## Description

Refactor the project from flat structure to proper Dart package structure under `lib/`. This improves maintainability, follows Dart best practices, and makes the codebase more professional.

**Current Structure:**
```
pvm/
├── pvm.dart              # Entry point
├── commands/             # Command files
├── utils/                # Mixed utilities
├── interfaces/           # OS abstractions (1 file)
├── enums/                # Options (1 file)
├── test/
├── builds/
└── versions/
```

**Target Structure:**
```
pvm/
├── lib/
│   └── src/
│       ├── commands/      # Command implementations
│       ├── core/          # Interfaces/contracts
│       ├── managers/      # OS/Process managers
│       ├── process/      # IOProcessManager
│       └── utils/        # Helpers
├── test/
├── bin/
│   └── pvm.dart          # Entry point (imports lib)
├── builds/
└── versions/
```

---

## Phases

### Phase 1: Create lib/src Directory Structure
- Status: Completed
- Create directories under lib/src/

### Phase 2: Move Files
- Status: Completed
- Move all files to new structure

### Phase 3: Update Imports
- Status: Completed
- Update all import paths

### Phase 4: Create Entry Point
- Status: Completed
- Move pvm.dart to bin/

### Phase 5: Update pubspec.yaml
- Status: Completed
- Add executables section

### Phase 6: Cleanup & Validate
- Status: Completed
- Remove old dirs, run tests

---

## Progress Log

### 2026-03-14
- Created plan for lib/ restructure
- Selected Option 3 (Full lib/ Structure) based on user preference

### 2026-03-14 (Completed)
- Created directories: lib/src/commands, lib/src/core, lib/src/managers, lib/src/process, lib/src/utils, bin/
- Moved commands/*.dart → lib/src/commands/
- Moved interfaces/os_manager.dart → lib/src/core/
- Moved utils/windows_os_manager.dart, mock_os_manager.dart → lib/src/managers/
- Created lib/src/process/io_process_manager.dart (no JobObjectManager — IOProcessManager used instead)
- Moved utils/*.dart → lib/src/utils/
- Moved enums/options.dart → lib/src/utils/
- Moved pvm.dart → bin/pvm.dart
- Updated all imports in:
  - bin/pvm.dart
  - lib/src/commands/*.dart (changed ../interfaces/ to ../core/)
  - lib/src/managers/*.dart (changed ../interfaces/ to ../core/)
  - *(no php_proxy.dart — PHP execution refactored into PhpExecutor service)*
  - test/mock_test.dart
  - test/adversarial_test.dart
- Added executables section to pubspec.yaml
- Removed old empty directories (commands/, interfaces/, enums/, utils/)
- Updated AGENTS.md with new project structure
- Verified new structure with ls
