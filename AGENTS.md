# AGENTS.md

## Scope

These instructions apply to the entire repository.

## Environment

- Develop and validate on native Windows with PowerShell. Do not use WSL for this project.
- Use Godot 4.7 with GDScript and the Compatibility renderer.
- Keep simulation and domain rules independent from rendering and UI whenever practical.

## File Size

- Keep every handwritten source or documentation file at no more than 1,000 lines.
- Split a file before it exceeds the limit, using cohesive modules with clear responsibilities.
- Generated and imported Godot artifacts are exempt, but must not be edited manually without a specific reason.

## Design and Reuse

- Prefer reusable components, composition, shared services, and data-driven resources over duplicated code.
- Follow SOLID principles and give each class, scene, and script one clear responsibility.
- Depend on stable abstractions or signals when this reduces coupling between gameplay systems.
- Keep domain logic testable without requiring the scene tree whenever practical.
- Avoid speculative systems: implement only what the current task and GDD require.
- Update the GDD or relevant specification whenever a gameplay rule changes materially.

## Quality

- Use test-driven development for gameplay behavior: write a failing test, implement the smallest change, make the test pass, then refactor.
- Run Godot tests through native Windows PowerShell with `./tools/run_godot_tests.ps1`; pass `-Suite 'res://path/to/test.gd'` for a focused registered suite.
- Run the relevant automated tests and a Godot smoke check before declaring a task complete.
- Do not hide warnings, failing checks, or incomplete behavior.

## Central Game Settings

- Put every new tunable gameplay, map, camera, generation, presentation, lighting, or demo value in `config/game_settings.tres`.
- Declare its typed Inspector field and validation in `scripts/config/game_settings.gd`.
- Do not duplicate production tuning values as local constants or defaults; keep only structural and mathematical invariants in code.

## Git Workflow

- Inspect `git status -sb` and the relevant diff before staging.
- Stage only files that belong to the current task; never mix unrelated changes.
- After every completed task: verify it, create a focused commit, and push the current branch to `origin`.
- Use clear commit messages that describe the completed outcome.
- Never force-push, hard-reset, or discard existing user changes without explicit authorization.
