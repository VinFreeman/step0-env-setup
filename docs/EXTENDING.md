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

## Record Lessons From Post-Step0 Extensions

Some projects need extra analysis tools after the bootstrap environment is already usable.
Treat those additions as focused, logged extensions rather than reasons to rebuild the whole
environment. A good extension should have:

- a short plan document;
- one install script;
- one verify script;
- one bounded monitor/check script;
- one focused sync script;
- one policy test that protects the hard-won assumptions.

### RNA velocity example

When adding RNA velocity tooling to an existing Python 3.11 `st1` environment, the useful pattern
was:

- install `velocyto`, `scVelo`, and pinned `CellRank` into the existing prefix;
- pin `cellrank==2.0.7` for Python 3.11 compatibility instead of installing latest unpinned
  CellRank;
- avoid rewriting a recovered prefix with conda if `conda install -p <prefix>` reports
  `DirectoryNotACondaEnvironmentError`;
- treat this as a conda prefix manageability problem rather than proof that the environment's
  `python`, `pip`, `R`, or `Rscript` executables are unusable;
- use the prefix's own `python -m pip` when the prefix has working Python/R executables but is not
  conda-manageable;
- install `numpy` and `cython` before `velocyto`, then use `--no-build-isolation` for `velocyto`
  because its source build imports these during setup;
- expect network stalls while downloading large wheels such as `scipy`; monitor logs with bounded
  tails rather than relaunching;
- record any dependency movement such as a `scipy` downgrade caused by `cellrank==2.0.7`;
- record runtime warnings such as `TBB_INTERFACE_VERSION` being too old for Numba's TBB threading
  layer.

Do not treat a successful package import as proof that RNA velocity analysis is biologically ready.
The analysis still needs suitable BAM or FASTQ input, GTF annotation, barcode/sample metadata, and
spliced/unspliced count generation before scVelo or CellRank can be interpreted.

## Keep It Portable

- Do not hardcode local user paths.
- Use `<plugin-root>` in docs when referring to the plugin location.
- Keep server-specific defaults in `profiles/`, not in code.
- Keep project-specific generated state out of this plugin repository.
