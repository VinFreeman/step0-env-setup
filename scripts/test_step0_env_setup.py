import json
import subprocess
import sys
import tempfile
from pathlib import Path


PLUGIN_ROOT = Path(__file__).resolve().parents[1]
CLI = PLUGIN_ROOT / "scripts" / "step0_env_setup.py"


def run_cli(*args, cwd=None):
    return subprocess.run(
        [sys.executable, str(CLI), *args],
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def test_plugin_manifest_skill_and_repo_docs_exist():
    manifest_path = PLUGIN_ROOT / ".codex-plugin" / "plugin.json"
    skill_path = PLUGIN_ROOT / "skills" / "step0-env-setup" / "SKILL.md"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    assert manifest["name"] == "step0-env-setup"
    assert manifest["skills"] == "./skills/"
    assert "step0" in manifest["description"].lower()

    skill = skill_path.read_text(encoding="utf-8")
    assert "Natural Language Use" in skill
    assert "step0_env_setup init" in skill
    assert "conda create -p" in skill
    assert "YAML-driven conda environment creation" in skill
    assert "<plugin-root>" in skill

    install = (PLUGIN_ROOT / "INSTALL.md").read_text(encoding="utf-8")
    assert "Different Computer Or Account" in install
    assert "./plugins/step0-env-setup" in install

    for rel in [
        "README.md",
        "docs/ARCHITECTURE.md",
        "docs/EXTENDING.md",
        "docs/RELEASE.md",
        "docs/STEP0_ENV_SETUP_PLUGIN_USER_GUIDE.md",
        "schemas/step0_env.schema.json",
        "profiles/gx4.yaml",
        "profiles/generic-linux.yaml",
    ]:
        assert (PLUGIN_ROOT / rel).exists(), rel


def test_docs_record_rna_velocity_extension_lessons():
    guide = (PLUGIN_ROOT / "docs" / "STEP0_ENV_SETUP_PLUGIN_USER_GUIDE.md").read_text(encoding="utf-8")
    extending = (PLUGIN_ROOT / "docs" / "EXTENDING.md").read_text(encoding="utf-8")
    combined = guide + "\n" + extending

    for marker in [
        "RNA velocity",
        "velocyto",
        "scVelo",
        "CellRank",
        "cellrank==2.0.7",
        "Python 3.11",
        "conda prefix",
        "DirectoryNotACondaEnvironmentError",
        "numpy",
        "cython",
        "--no-build-isolation",
        "TBB_INTERFACE_VERSION",
        "scipy",
        "spliced/unspliced",
        "BAM",
        "GTF",
        "不要重建",
        "bounded",
    ]:
        assert marker in combined, marker


def test_cli_lists_template_files():
    result = run_cli("plan-files")
    assert result.returncode == 0, result.stderr
    lines = result.stdout.strip().splitlines()
    required = {
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
    }
    assert required.issubset(set(lines))


def test_cli_lists_profiles_and_profile_defaults():
    result = run_cli("profiles")
    assert result.returncode == 0, result.stderr
    assert "generic-linux" in result.stdout
    assert "gx4" in result.stdout

    with tempfile.TemporaryDirectory() as tmp:
        project = Path(tmp) / "proj"
        project.mkdir()
        init = run_cli("init", "--project", str(project), "--profile", "gx4", "--force")
        assert init.returncode == 0, init.stderr
        config = (project / "config" / "step0_env.yaml").read_text(encoding="utf-8")
        assert "profile: gx4" in config
        assert "remote_alias: sxy-gx4-151-ys005" in config
        assert "connection_min_spacing_seconds: 20" in config
        assert "connection_max_attempts_per_minute: 4" in config


def test_init_generates_project_without_known_bad_patterns():
    with tempfile.TemporaryDirectory() as tmp:
        project = Path(tmp) / "proj"
        project.mkdir()
        result = run_cli(
            "init",
            "--project",
            str(project),
            "--remote-alias",
            "gx4-test",
            "--remote-root",
            "~/proj_test",
            "--env-name",
            "stx",
            "--env-prefix",
            "/data/user/conda_envs/stx",
            "--conda-dir",
            "/data/user/miniconda3",
            "--force",
        )
        assert result.returncode == 0, result.stderr

        expected = run_cli("plan-files").stdout.strip().splitlines()
        for rel in expected:
            assert (project / rel).exists(), rel

        config = (project / "config" / "step0_env.yaml").read_text(encoding="utf-8")
        assert "remote_alias: gx4-test" in config
        assert "env_name: stx" in config
        assert "env_prefix: /data/user/conda_envs/stx" in config
        assert "conda_dir: /data/user/miniconda3" in config

        combined = "\n".join(
            path.read_text(encoding="utf-8")
            for path in project.rglob("*")
            if path.is_file() and path.suffix.lower() in {"", ".sh", ".ps1", ".r", ".md", ".yml", ".yaml", ".tsv"}
        )
        assert "ST1_" not in combined
        assert "st_human_breast_cancer_remote" not in combined
        assert "conda env create -f" not in combined
        assert "repo.anaconda.com/pkgs/main" not in combined
        assert "condaset" not in combined

        policy = subprocess.run(
            [
                "powershell",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(project / "tests" / "test_step0_policy.ps1"),
            ],
            cwd=project,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        assert policy.returncode == 0, policy.stderr + policy.stdout


def test_validate_checks_existing_generated_project():
    with tempfile.TemporaryDirectory() as tmp:
        project = Path(tmp) / "proj"
        project.mkdir()
        init = run_cli("init", "--project", str(project), "--force")
        assert init.returncode == 0, init.stderr
        validate = run_cli("validate", "--project", str(project))
        assert validate.returncode == 0, validate.stderr
        assert "step0 project validation passed" in validate.stdout


def test_package_command_creates_portable_archive():
    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / "step0-env-setup.zip"
        result = run_cli("package", "--output", str(output))
        assert result.returncode == 0, result.stderr
        assert output.exists()
        assert output.stat().st_size > 1000


if __name__ == "__main__":
    tests = [
        test_plugin_manifest_skill_and_repo_docs_exist,
        test_docs_record_rna_velocity_extension_lessons,
        test_cli_lists_template_files,
        test_cli_lists_profiles_and_profile_defaults,
        test_init_generates_project_without_known_bad_patterns,
        test_validate_checks_existing_generated_project,
        test_package_command_creates_portable_archive,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")
