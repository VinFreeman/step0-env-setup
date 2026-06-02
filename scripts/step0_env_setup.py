#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


PLUGIN_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_ROOT = PLUGIN_ROOT / "templates"
PROFILE_ROOT = PLUGIN_ROOT / "profiles"

GENERATED_FILES = [
    "config/step0_env.yaml",
    "config/envs/step0_bootstrap_environment.yml",
    "config/step0_r_packages.tsv",
    "config/step0_conda_fallback.tsv",
    "run/step0/step0_env_lib.sh",
    "run/step0/setup.sh",
    "run/step0/launch.sh",
    "run/step0/check.sh",
    "run/step0/sync.ps1",
    "scripts/setup/install_r_packages_step0.R",
    "scripts/setup/validate_step0.R",
    "docs/setup/STEP0_ENV_SETUP_RUNBOOK.md",
    "tests/test_step0_policy.ps1",
]

PACKAGE_EXCLUDES = {
    ".git",
    "__pycache__",
}


def parse_simple_yaml(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def profile_paths() -> list[Path]:
    return sorted(PROFILE_ROOT.glob("*.yaml"))


def load_profile(name: str) -> dict[str, str]:
    path = PROFILE_ROOT / f"{name}.yaml"
    if not path.exists():
        available = ", ".join(p.stem for p in profile_paths())
        raise FileNotFoundError(f"profile not found: {name}. Available: {available}")
    return parse_simple_yaml(path)


def render_text(text: str, values: dict[str, str]) -> str:
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    return text


def copy_template(rel: str, project: Path, values: dict[str, str], force: bool) -> None:
    src = TEMPLATE_ROOT / rel
    dst = project / rel
    if not src.exists():
        raise FileNotFoundError(f"template missing: {src}")
    if dst.exists() and not force:
        raise FileExistsError(f"refusing to overwrite existing file without --force: {dst}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    text = src.read_text(encoding="utf-8")
    dst.write_text(render_text(text, values), encoding="utf-8", newline="\n")


def command_plan_files(_: argparse.Namespace) -> int:
    print("\n".join(GENERATED_FILES))
    return 0


def command_profiles(_: argparse.Namespace) -> int:
    for path in profile_paths():
        profile = parse_simple_yaml(path)
        print(f"{path.stem}\t{profile.get('description', '')}")
    return 0


def value_from_args_or_profile(args: argparse.Namespace, profile: dict[str, str], attr: str, key: str, default: str) -> str:
    value = getattr(args, attr)
    if value is not None:
        return value
    return profile.get(key, default)


def command_init(args: argparse.Namespace) -> int:
    profile = load_profile(args.profile)
    project = Path(args.project).resolve()
    project.mkdir(parents=True, exist_ok=True)

    env_prefix = value_from_args_or_profile(args, profile, "env_prefix", "env_prefix", "$HOME/conda_envs/step0")
    allowed_prefix_root = value_from_args_or_profile(args, profile, "allowed_prefix_root", "allowed_prefix_root", "")
    if not allowed_prefix_root:
        allowed_prefix_root = str(Path(env_prefix).parent).replace("\\", "/")

    values = {
        "PROFILE": args.profile,
        "REMOTE_ALIAS": value_from_args_or_profile(args, profile, "remote_alias", "remote_alias", "remote-alias"),
        "REMOTE_ROOT": value_from_args_or_profile(args, profile, "remote_root", "remote_root", "~/proj_example"),
        "ENV_NAME": value_from_args_or_profile(args, profile, "env_name", "env_name", "step0"),
        "ENV_PREFIX": env_prefix,
        "ALLOWED_PREFIX_ROOT": allowed_prefix_root,
        "CONDA_DIR": value_from_args_or_profile(args, profile, "conda_dir", "conda_dir", "$HOME/miniconda3"),
        "CONNECTION_MIN_SPACING_SECONDS": profile.get("connection_min_spacing_seconds", "20"),
        "CONNECTION_MAX_ATTEMPTS_PER_MINUTE": profile.get("connection_max_attempts_per_minute", "4"),
        "INSTALL_NCPUS": profile.get("install_ncpus", "2"),
        "MAX_DEPENDENCY_DEPTH": profile.get("max_dependency_depth", "3"),
    }
    for rel in GENERATED_FILES:
        copy_template(rel, project, values, force=args.force)
    print(f"step0_env_setup initialized: {project}")
    print(f"profile: {args.profile}")
    print("next: edit config/step0_env.yaml, then run validate")
    return 0


def scan_bad_patterns(project: Path) -> list[str]:
    bad_patterns = [
        "ST1_",
        "st_human_breast_cancer_remote",
        "conda env create -f",
        "repo.anaconda.com/pkgs/main",
        "repo.anaconda.com/pkgs/r",
        "condaset",
    ]
    suffixes = {"", ".sh", ".ps1", ".r", ".md", ".yml", ".yaml", ".tsv"}
    errors: list[str] = []
    for rel in GENERATED_FILES:
        path = project / rel
        if not path.exists():
            errors.append(f"missing generated file: {rel}")
            continue
        if path.suffix.lower() not in suffixes:
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in bad_patterns:
            if pattern in text:
                errors.append(f"{rel} contains forbidden pattern: {pattern}")
    return errors


def command_validate(args: argparse.Namespace) -> int:
    project = Path(args.project).resolve()
    errors = scan_bad_patterns(project)
    policy = project / "tests" / "test_step0_policy.ps1"
    if policy.exists():
        completed = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(policy)],
            cwd=project,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if completed.returncode != 0:
            errors.append(completed.stderr + completed.stdout)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("step0 project validation passed")
    return 0


def should_package(path: Path) -> bool:
    parts = set(path.relative_to(PLUGIN_ROOT).parts)
    return not bool(parts & PACKAGE_EXCLUDES)


def command_package(args: argparse.Namespace) -> int:
    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in PLUGIN_ROOT.rglob("*"):
            if path.is_file() and should_package(path):
                zf.write(path, path.relative_to(PLUGIN_ROOT.parent).as_posix())
    print(f"portable archive written: {output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="step0_env_setup")
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan-files", help="List files generated by init.")
    plan.set_defaults(func=command_plan_files)

    profiles = sub.add_parser("profiles", help="List available server profiles.")
    profiles.set_defaults(func=command_profiles)

    init = sub.add_parser("init", help="Generate step0 setup workflow into a project.")
    init.add_argument("--project", required=True, help="Project root to initialize.")
    init.add_argument("--profile", default="generic-linux", help="Profile name from profiles/*.yaml.")
    init.add_argument("--remote-alias", default=None)
    init.add_argument("--remote-root", default=None)
    init.add_argument("--env-name", default=None)
    init.add_argument("--env-prefix", default=None)
    init.add_argument("--allowed-prefix-root", default=None)
    init.add_argument("--conda-dir", default=None)
    init.add_argument("--force", action="store_true")
    init.set_defaults(func=command_init)

    validate = sub.add_parser("validate", help="Validate generated step0 files in a project.")
    validate.add_argument("--project", required=True)
    validate.set_defaults(func=command_validate)

    package = sub.add_parser("package", help="Create a portable zip archive of the plugin.")
    package.add_argument("--output", required=True)
    package.set_defaults(func=command_package)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
