# Update AGENTS.md with Latest Architecture

## Status
To Do

## Description
Update the existing `AGENTS.md` file at the project root to reflect the current architecture of the PVM codebase, incorporating findings from the `/init-deep` exploration.

## Phases

### Phase 1: Analyze Current AGENTS.md vs Exploration Findings
- Status: Done
- Description: Compare existing AGENTS.md content with all exploration results to identify gaps and inaccuracies.
- Steps:
  1. Read existing AGENTS.md (368 lines)
  2. Review exploration findings:
     - `currentEnvironment` getter in `IOSManager` (discovered but not clearly documented)
     - `ComposerCommand` implementation details (PATH scanning for composer.bat/composer.phar)
     - `IOProcessManager` execution mode (ProcessStartMode.normal vs inheritStdio)
     - Testing patterns (two-tier mocks, adversarial_test.dart, fake managers)
     - Project structure (26 Dart files, clear subdirectory organization)
  3. List specific sections that need updates

### Phase 2: Draft Updated AGENTS.md Content
- Status: Done
- Description: Prepare the updated content sections that will replace/augment existing content.
- Steps:
  1. Update "Environment Access" section to mention FakeOSManager/FakeProcessManager in test/services/
  2. Add ComposerCommand details to "Service Layer" section
  3. Clarify Process Execution Details: distinguish between runInteractive (inheritStdio for PhpCommand) and runCaptured (normal for Composer)
  4. Expand "Testing Guidelines" with:
     - Two-tier mock system (Mock in lib/ vs Fake in test/)
     - Adversarial test file location and purpose
     - Process manager testing pattern (real subprocess execution)
     - Example test patterns (setUp/tearDown, group(), inline data)
  5. Update "Implementation Details to Remember" with separator between PhpCommand and ComposerCommand subsections
  6. Add note about `.php-version` JSON format and project root discovery algorithm
  7. Add note about `pvm composer` vs `pvm php vendor/bin/composer` distinction
  8. Ensure no duplicate content, maintain telegraphic style, keep total lines ~400-450

### Phase 3: Apply Changes to AGENTS.md
- Status: Done
- Description: Execute the edits using Edit tool (since file exists).
- Steps:
  1. Use Edit tool for each section update (do NOT use Write — file exists)
  2. Preserve overall structure and formatting
  3. Verify line count remains reasonable (no bloat)
  4. Ensure all updates are accurate and reflect exploration findings exactly

### Phase 4: Verify Quality
- Status: Done
- Description: Check that updated AGENTS.md meets quality gates.
- Steps:
  1. Confirm no generic advice that applies to all projects (telegraphic, project-specific)
  2. Confirm no redundancy (child directories won't have separate AGENTS.md)
  3. Confirm all critical architecture details are present and correct
  4. Ensure "WHERE TO LOOK" table uses actual file paths from codebase
  5. Ensure "CODE MAP" is accurate (if included)
  6. Confirm anti-patterns section lists project-specific forbidden patterns

## Conclusion
AGENTS.md will be fully up-to-date, providing accurate guidance for future agents working on PVM. No subdirectory AGENTS.md files are needed as the root file is comprehensive.

## Suggestions
- Consider adding a "Quick Reference" section at top with most common commands: `pvm global`, `pvm use`, `pvm php`, `pvm composer`
- Consider adding a "Common Errors" section with error messages and fixes
- Keep this AGENTS.md as the single source of truth; avoid creating excessive subdirectory files
