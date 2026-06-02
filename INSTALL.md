# step0-env-setup Installation

This plugin is portable as a normal directory. It does not depend on the original Windows account path.

## Same Computer, Current Account

This account already has the plugin at:

```text
C:\Users\Freeman\plugins\step0-env-setup
```

and a personal marketplace entry at:

```text
C:\Users\Freeman\.agents\plugins\marketplace.json
```

After opening a new Codex conversation, you can ask:

```text
使用 step0-env-setup 初始化当前项目
```

## Different Computer Or Account

1. Copy the full plugin directory:

```text
step0-env-setup/
  .codex-plugin/plugin.json
  skills/
  scripts/
  templates/
  INSTALL.md
```

2. Put it under the target account's plugin directory, for example:

```text
<user-home>\plugins\step0-env-setup
```

3. Create or update the target account's personal marketplace file:

```json
{
  "name": "personal",
  "interface": {
    "displayName": "Personal"
  },
  "plugins": [
    {
      "name": "step0-env-setup",
      "source": {
        "source": "local",
        "path": "./plugins/step0-env-setup"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
```

4. Restart or open a new Codex conversation so the skill list refreshes.

5. Use natural language:

```text
使用 step0-env-setup 给当前项目初始化远端 conda/R 环境配置
```

or use the CLI:

```powershell
python <plugin-root>\scripts\step0_env_setup.py init --project <project-path>
python <plugin-root>\scripts\step0_env_setup.py validate --project <project-path>
```

## Repository Distribution Option

For broader reuse, store this plugin directory in a Git repository or shared internal template repository. On each new machine, clone or copy it into the target plugin directory and register the marketplace entry above.

## Validation

Run:

```powershell
python <plugin-root>\scripts\test_step0_env_setup.py
```

Expected output includes:

```text
PASS test_plugin_manifest_and_skill_exist
PASS test_cli_lists_template_files
PASS test_init_generates_project_without_known_bad_patterns
PASS test_validate_checks_existing_generated_project
```
