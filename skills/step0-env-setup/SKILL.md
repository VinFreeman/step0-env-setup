---
name: step0-env-setup
description: Initialize, validate, or explain reusable step0 environment setup workflows for new remote servers and computational biology projects. Use when the user asks for step0_env_setup, step0 environment setup, remote conda/R bootstrap setup, reusable HPC environment setup, or packaging environment setup from previous project lessons.
---

# Step0 Env Setup

Use this plugin when a project needs a reproducible first environment setup stage for remote Linux/HPC bioinformatics work.

## Natural Language Use

After this plugin is installed and enabled on the current computer/account, the user can simply say:

- "使用 step0-env-setup 初始化当前项目"
- "用 step0_env_setup 给这个新服务器生成第0步环境配置"
- "初始化 remote conda/R step0 环境配置，env name 用 st1"

When invoked this way, inspect the current project context, then run the CLI from this plugin root. Do not rely on a hardcoded user path; resolve the CLI as `<plugin-root>/scripts/step0_env_setup.py`.

## What This Generates

Run:

```powershell
python <plugin-root>\scripts\step0_env_setup.py init --project <project-path>
```

The command generates:

- `config/step0_env.yaml`
- `config/envs/step0_bootstrap_environment.yml`
- `config/step0_r_packages.tsv`
- `config/step0_conda_fallback.tsv`
- `run/step0/step0_env_lib.sh`
- `run/step0/setup.sh`
- `run/step0/launch.sh`
- `run/step0/check.sh`
- `run/step0/sync.ps1`
- `scripts/setup/install_r_packages_step0.R`
- `scripts/setup/validate_step0.R`
- `docs/setup/STEP0_ENV_SETUP_RUNBOOK.md`
- `tests/test_step0_policy.ps1`

## Core Rules

- First conda phase is bootstrap-only.
- Use explicit account-owned conda, isolated `CONDARC`, clean conda home, `CONDA_SOLVER=classic`, and `conda create -p`.
- Do not use the old first-stage YAML-driven conda environment creation pattern.
- Install R packages one by one inside R with per-package logs.
- Retry missing R dependencies when logs reveal them.
- Continue after persistent package failures and write a failed-package list.
- Use one-by-one conda fallback only after R-internal attempts.
- Defer Python analysis packages to one-by-one installs.
- Configure `R_MAKEVARS_USER`, `/usr/bin/gcc`, `/usr/bin/g++`, `/usr/bin/gfortran`, `/usr/bin/ar`, and `/usr/bin/ranlib` before R source builds.
- Monitor bounded logs and status files, not PID liveness alone.

## Commands

Initialize a project:

```powershell
python <plugin-root>\scripts\step0_env_setup.py init --project L:\new_project --remote-alias sxy-gx4-151-ys005 --remote-root "~/proj_new" --env-name st1 --env-prefix "/data/user/conda_envs/st1" --conda-dir "/data/user/miniconda3"
```

Short form if the script is on `PATH`:

```powershell
step0_env_setup init --project L:\new_project --remote-alias sxy-gx4-151-ys005 --remote-root "~/proj_new" --env-name st1
```

Validate generated files:

```powershell
python <plugin-root>\scripts\step0_env_setup.py validate --project L:\new_project
```

List generated file paths:

```powershell
python <plugin-root>\scripts\step0_env_setup.py plan-files
```

## Portability

The plugin is portable as a directory. To use it on another computer/account:

1. Copy the whole `step0-env-setup` plugin folder to that account's plugin directory.
2. Register it in that account's personal marketplace or install from a marketplace/repo containing this plugin.
3. Open a new Codex conversation so the plugin skill is discovered.
4. Use natural language or the CLI.

See `INSTALL.md` in the plugin root for a concrete cross-machine setup recipe.

## After Init

1. Read `docs/setup/STEP0_ENV_SETUP_RUNBOOK.md`.
2. Edit `config/step0_env.yaml`, `config/step0_r_packages.tsv`, and `config/step0_conda_fallback.tsv`.
3. Run `powershell -ExecutionPolicy Bypass -File tests/test_step0_policy.ps1`.
4. Read the target project's remote connection policy before syncing or launching.
5. Use `run/step0/sync.ps1`, then `run/step0/launch.sh`, then sparse `run/step0/check.sh` monitoring.
