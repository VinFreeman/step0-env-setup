# step0-env-setup

Reusable Codex plugin for generating a project-local step0 environment setup workflow for remote Linux/HPC conda/R bioinformatics projects.

## Why

This plugin packages hard-won environment setup lessons into a portable repository:

- bootstrap-only conda first phase;
- explicit account-owned conda;
- isolated `CONDARC`;
- `CONDA_SOLVER=classic`;
- R packages installed one by one inside R with per-package logs;
- one-by-one conda fallback;
- delayed Python package installation;
- project-local `R_MAKEVARS_USER` for source builds;
- tracked launch and bounded monitoring scripts.

## Quick Start

```powershell
python scripts\step0_env_setup.py init --project L:\new_project --profile gx4 --env-name st1
python scripts\step0_env_setup.py validate --project L:\new_project
```

Then edit:

- `config/step0_env.yaml`
- `config/step0_r_packages.tsv`
- `config/step0_conda_fallback.tsv`

## Natural Language

After installing this plugin in Codex, a new project conversation can say:

```text
使用 step0-env-setup 初始化当前项目，profile 用 gx4，env name 用 st1
```

## Distribution

This plugin is intended to live in Git. Clone or copy the repository to another machine, register it in that account's Codex plugin marketplace, and open a new Codex conversation.

See `INSTALL.md` and `docs/RELEASE.md`.
