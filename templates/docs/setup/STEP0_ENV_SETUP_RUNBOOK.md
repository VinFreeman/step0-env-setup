# Step0 Environment Setup Runbook

This generated runbook documents the reusable step0 environment setup workflow for a new project or server.

## Generated Workflow

- Edit `config/step0_env.yaml`.
- Keep `config/envs/step0_bootstrap_environment.yml` bootstrap-only.
- Edit R packages in `config/step0_r_packages.tsv`.
- Edit conda fallback specs in `config/step0_conda_fallback.tsv`.
- Sync generated step0 files with `run/step0/sync.ps1`.
- Launch remotely with `bash run/step0/launch.sh <remote-project-root> config/step0_env.yaml`.
- Monitor sparsely with `bash run/step0/check.sh <remote-project-root> config/step0_env.yaml --tail-lines 120`.

## Core Rules

- Use explicit account-owned conda and isolated `CONDARC`.
- First phase uses `conda create -p` with `--override-channels`.
- Do not use the old first-stage YAML-driven conda environment creation pattern.
- Use `CONDA_SOLVER=classic` to avoid libmamba sqlite lock issues such as `repodata_shards.db`.
- Avoid defaults and `repo.anaconda.com` unless the user explicitly accepts the policy/legal implications.
- Install R packages one by one inside R and keep per-package logs.
- Retry missing dependencies when R logs reveal them.
- Use one-by-one conda fallback only after R attempts.
- Defer Python packages such as `numpy`, `pandas`, `matplotlib`, `opencv`, and `PySide2`.
- Configure `R_MAKEVARS_USER` with `/usr/bin/gcc`, `/usr/bin/g++`, `/usr/bin/gfortran`, `/usr/bin/ar`, and `/usr/bin/ranlib` before source builds.

## Known Lessons From GX4-151

- Account `.condarc` contamination can redirect conda to server-specific endpoints such as `sxygptcloud.com:6002`.
- Long `Solving environment` phases can be first-stage conda solve problems, not R package installation.
- `Rhdf5lib` and `monocle3` failures can be caused by missing `x86_64-conda-linux-gnu-ar`, not missing HDF5 itself.
- `PySide2` may import with a NumPy 2.x ABI warning; treat it as a compatibility risk.
- Avoid detached cron automation unless smoke-run evidence proves prompt delivery.

## Validation

Run locally before remote mutation:

```powershell
powershell -ExecutionPolicy Bypass -File tests/test_step0_policy.ps1
python <plugin-root>\scripts\step0_env_setup.py validate --project .
```
