# Release And Distribution

## Local Git Repository

Initialize once:

```powershell
git init
git add .
git commit -m "initial step0-env-setup plugin"
```

## Portable Archive

Create a zip archive:

```powershell
python scripts\step0_env_setup.py package --output step0-env-setup.zip
```

## New Machine Install

1. Clone the Git repository or unzip the archive.
2. Put the plugin folder under the target user's plugin directory, or keep it in a cloned repo and register the marketplace entry accordingly.
3. Ensure `.codex-plugin/plugin.json` exists.
4. Add marketplace entry:

```json
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
```

5. Open a new Codex conversation.

## Verification

```powershell
python scripts\test_step0_env_setup.py
```
