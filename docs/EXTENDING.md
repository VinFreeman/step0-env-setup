# Extending step0-env-setup

## Add A Server Profile

Create a YAML file under `profiles/`, for example:

```yaml
name: my-server
description: My lab server
remote_alias: my-server
remote_root: ~/proj_example
env_name: st1
env_prefix: ~/conda_envs/st1
allowed_prefix_root: ~/conda_envs
conda_dir: ~/miniconda3
connection_min_spacing_seconds: 20
connection_max_attempts_per_minute: 4
```

Then run:

```powershell
python scripts\step0_env_setup.py profiles
python scripts\test_step0_env_setup.py
```

## Add A Template File

1. Add the file under `templates/`.
2. Add its generated relative path to `GENERATED_FILES` in `scripts/step0_env_setup.py`.
3. Add assertions to `scripts/test_step0_env_setup.py`.
4. Run tests.

## Add A Validation Rule

- For plugin-level validation, edit `scripts/step0_env_setup.py`.
- For generated-project validation, edit `templates/tests/test_step0_policy.ps1`.

## Keep It Portable

- Do not hardcode local user paths.
- Use `<plugin-root>` in docs when referring to the plugin location.
- Keep server-specific defaults in `profiles/`, not in code.
- Keep project-specific generated state out of this plugin repository.
