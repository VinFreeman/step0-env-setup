# Architecture

## Layers

1. Plugin layer
   - `.codex-plugin/plugin.json`
   - `skills/step0-env-setup/SKILL.md`
   - Codex discovery and natural-language use.

2. CLI layer
   - `scripts/step0_env_setup.py`
   - Commands: `init`, `validate`, `plan-files`, `profiles`, `package`.

3. Profile layer
   - `profiles/*.yaml`
   - Server or organization defaults such as remote alias, conda path, connection spacing, and fair-use notes.

4. Template layer
   - `templates/`
   - Project-local generated files.

5. Schema and tests
   - `schemas/step0_env.schema.json`
   - `scripts/test_step0_env_setup.py`
   - Generated project policy test `tests/test_step0_policy.ps1`.

## Extension Points

- Add a server profile under `profiles/`.
- Add a new generated file by editing `GENERATED_FILES` and adding the corresponding template path.
- Add validation rules in `scan_bad_patterns()` or generated `tests/test_step0_policy.ps1`.
- Add project-type package defaults by introducing a new package plan TSV template or profile field.

## Non-goals

- This plugin does not directly SSH into a server during `init`.
- This plugin does not install conda or R packages locally.
- This plugin does not replace project-specific remote connection policy.
