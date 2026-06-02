# step0-env-setup 插件通用使用与维护手册

本文档说明如何在当前电脑、新项目、新电脑、新账号和新服务器上复用 `step0-env-setup` 插件，并说明如何维护、修正和增强这个插件仓库。

## 1. 插件定位

`step0-env-setup` 是一个可复用的 Codex 插件/模板仓库，用来生成新项目的第 0 步环境配置框架，重点服务于远端 Linux/HPC 上的 conda/R 生信项目。

它解决的问题包括：

- 把远端环境配置经验集中沉淀，不再散落在单个项目脚本里。
- 新项目可以直接生成标准的 `config/`、`run/step0/`、`scripts/setup/` 和 runbook。
- 新服务器只需要新增或修改 profile，不需要重写整个环境配置流程。
- 每次环境安装都有日志、状态文件、失败包记录和可监控脚本。
- 支持 Codex 自然语言触发，也支持直接命令行调用。

当前 GitHub 仓库：

```text
https://github.com/VinFreeman/step0-env-setup
```

当前本机插件目录：

```text
C:\Users\Freeman\plugins\step0-env-setup
```

## 2. 当前电脑上如何在新项目中使用

假设新项目路径是：

```text
L:\new_project
```

在 PowerShell 中运行：

```powershell
python C:\Users\Freeman\plugins\step0-env-setup\scripts\step0_env_setup.py init --project L:\new_project --profile gx4 --env-name st1
```

然后验证生成结果：

```powershell
python C:\Users\Freeman\plugins\step0-env-setup\scripts\step0_env_setup.py validate --project L:\new_project
```

如果只想查看插件会生成哪些文件：

```powershell
python C:\Users\Freeman\plugins\step0-env-setup\scripts\step0_env_setup.py plan-files
```

如果想查看可用服务器 profile：

```powershell
python C:\Users\Freeman\plugins\step0-env-setup\scripts\step0_env_setup.py profiles
```

## 3. 新项目生成后需要重点修改哪些文件

插件初始化后，新项目里会出现一组标准文件。最常改的是：

```text
config\step0_env.yaml
config\step0_r_packages.tsv
config\step0_conda_fallback.tsv
docs\setup\STEP0_ENV_SETUP_RUNBOOK.md
```

其中：

- `config\step0_env.yaml` 记录远端服务器、远端项目路径、conda 路径、env 名称、连接频率限制等核心配置。
- `config\step0_r_packages.tsv` 记录优先通过 R 内部安装的 R 包清单。
- `config\step0_conda_fallback.tsv` 记录 R 内部安装失败后才尝试的 conda fallback 包清单。
- `docs\setup\STEP0_ENV_SETUP_RUNBOOK.md` 是该项目自己的第 0 步环境配置 runbook。

生成后建议先读 runbook，再根据项目和服务器实际情况修改配置。

## 4. 在 Codex 新对话中如何直接用自然语言调用

如果插件已经在当前账号的 Codex 插件 marketplace 中注册，打开任意新项目对话后，可以直接说：

```text
使用 step0-env-setup 初始化当前项目，profile 用 gx4，env name 用 st1
```

也可以说：

```text
用 step0_env_setup 给这个新服务器生成第0步远端 conda/R 环境配置
```

或者：

```text
初始化 remote conda/R step0 环境配置，env name 用 st1
```

Codex 会根据插件里的 `skills/step0-env-setup/SKILL.md` 识别这个请求，并调用：

```text
scripts\step0_env_setup.py
```

如果自然语言没有触发，也可以直接运行 CLI 命令。自然语言触发不是魔法，它依赖本机/本账号已经正确注册插件。

## 5. 什么是 Codex 插件 marketplace 注册

这里的 marketplace 不是 GitHub，也不是网页商店。它只是当前电脑当前账号下的一个本地索引文件，用来告诉 Codex：

```text
这个账号有哪些本地插件，以及插件目录在哪里。
```

默认路径通常是：

```text
C:\Users\<用户名>\.agents\plugins\marketplace.json
```

在当前电脑上，这个文件是：

```text
C:\Users\Freeman\.agents\plugins\marketplace.json
```

它的核心内容如下：

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

其中：

- `"name": "step0-env-setup"` 是插件名。
- `"path": "./plugins/step0-env-setup"` 表示插件目录相对于用户主目录的位置。
- 对 Windows 用户来说，它通常对应：

```text
C:\Users\<用户名>\plugins\step0-env-setup
```

注册 marketplace 的意思，就是创建或更新这个 `marketplace.json` 文件。

## 6. 换一台电脑或换一个账号时如何安装

### 6.1 克隆插件仓库

在新电脑或新账号中打开 PowerShell：

```powershell
mkdir $HOME\plugins
git clone https://github.com/VinFreeman/step0-env-setup.git $HOME\plugins\step0-env-setup
```

如果这台机器已经配置好 GitHub SSH，也可以用：

```powershell
git clone git@github.com:VinFreeman/step0-env-setup.git $HOME\plugins\step0-env-setup
```

### 6.2 创建 marketplace 目录

```powershell
mkdir $HOME\.agents\plugins
```

### 6.3 创建或更新 marketplace.json

文件路径：

```text
$HOME\.agents\plugins\marketplace.json
```

内容：

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

如果 `marketplace.json` 已经存在，不能简单覆盖整个文件。应该只把 `step0-env-setup` 这一项加入 `plugins` 数组，避免删除其他已注册插件。

### 6.4 重启 Codex 或打开新对话

Codex 通常需要重新打开或新建对话，才能重新发现插件。之后就可以在任意项目中直接说：

```text
使用 step0-env-setup 初始化当前项目
```

### 6.5 不注册 marketplace 时的替代方式

即使不注册 marketplace，也能通过命令行使用插件：

```powershell
python $HOME\plugins\step0-env-setup\scripts\step0_env_setup.py init --project L:\new_project --profile gx4 --env-name st1
```

区别是：

```text
注册 marketplace = Codex 能通过自然语言识别并调用插件。
不注册 marketplace = 仍然能手动运行 Python CLI。
```

## 7. GitHub SSH 认证和仓库推送

### 7.1 GitHub 账号身份

这台电脑已配置的 Git 全局身份是：

```text
VinFreeman <251407536@qq.com>
```

新电脑可以用下面命令设置：

```powershell
git config --global user.name "VinFreeman"
git config --global user.email "251407536@qq.com"
```

验证：

```powershell
git config --global user.name
git config --global user.email
```

### 7.2 passphrase 是什么

`passphrase` 是 SSH 私钥的本地加密密码。

- 设置 passphrase：更安全，但每次使用私钥时可能需要输入密码或配置 ssh-agent。
- 不设置 passphrase：使用更方便，但私钥文件必须保管好，不能泄露。

当前这台电脑上为 GitHub 创建的 SSH key 没有设置 passphrase。

### 7.3 新电脑配置 GitHub SSH 的基本流程

生成 SSH key：

```powershell
ssh-keygen -t ed25519 -C "251407536@qq.com" -f $HOME\.ssh\id_ed25519_github
```

如果不想设置 passphrase，提示输入 passphrase 时直接回车。

查看公钥：

```powershell
Get-Content $HOME\.ssh\id_ed25519_github.pub
```

复制输出内容，到 GitHub 添加：

```text
GitHub -> Settings -> SSH and GPG keys -> New SSH key
```

添加完成后测试：

```powershell
ssh -T git@github.com
```

看到类似下面信息，说明认证成功：

```text
Hi VinFreeman! You've successfully authenticated, but GitHub does not provide shell access.
```

这个测试命令有时 exit code 不是 0，但只要出现上面这句话，就表示 SSH 认证成功。

## 8. GitHub 上新建仓库时 README、.gitignore、license 的位置

README、`.gitignore`、license 的勾选项只会出现在 GitHub 新建仓库页面，不会出现在 SSH key 页面。

新建仓库页面：

```text
https://github.com/new
```

仓库名：

```text
step0-env-setup
```

建议：

- `Add a README file` 不勾选。
- `.gitignore` 不选择。
- `license` 不选择。

原因是本地仓库已经有这些文件或相关结构。如果 GitHub 初始化时又创建一套文件，首次 push 可能出现远端和本地历史不一致的问题。

## 9. 日常更新插件仓库的标准流程

进入插件仓库：

```powershell
cd C:\Users\Freeman\plugins\step0-env-setup
```

先同步远端：

```powershell
git pull
```

查看状态：

```powershell
git status --short
```

修改文件后运行测试：

```powershell
python scripts\test_step0_env_setup.py
```

再用临时目录做真实初始化验证：

```powershell
python scripts\step0_env_setup.py init --project C:\Users\Freeman\AppData\Local\Temp\step0-test --profile gx4 --env-name st1
python scripts\step0_env_setup.py validate --project C:\Users\Freeman\AppData\Local\Temp\step0-test
```

确认无误后提交：

```powershell
git add .
git commit -m "feat: improve step0 env setup"
git push
```

## 10. 仓库结构和每个部分负责什么

```text
.codex-plugin\plugin.json
```

Codex 插件清单，定义插件名称、版本、描述、技能目录和界面信息。

```text
skills\step0-env-setup\SKILL.md
```

Codex 自然语言触发入口。想让 Codex 更容易识别某些说法，就改这里。

```text
scripts\step0_env_setup.py
```

核心 CLI。负责 `init`、`validate`、`profiles`、`plan-files`、`package` 等命令。

```text
scripts\test_step0_env_setup.py
```

插件测试。每次修改后都应该运行。

```text
templates\
```

生成到新项目中的模板文件。比如远端 setup 脚本、check 脚本、R 包安装脚本、runbook。

```text
profiles\gx4.yaml
profiles\generic-linux.yaml
```

服务器 profile。新增服务器时优先新增这里，而不是直接硬改模板。

```text
schemas\step0_env.schema.json
```

配置文件结构约束。新增配置字段时应同步更新 schema。

```text
docs\
```

插件架构、扩展、发布和使用说明。

## 11. 如何新增一个服务器 profile

例如要新增一个服务器 profile，名字叫：

```text
my-hpc
```

建议新建：

```text
profiles\my-hpc.yaml
```

内容可参考：

```text
profiles\gx4.yaml
profiles\generic-linux.yaml
```

profile 中应该记录：

- `remote_alias`
- `remote_host`
- `remote_user`
- `remote_port`
- `remote_root`
- `conda_dir`
- `env_name`
- `env_prefix`
- SSH/SCP 连接频率限制
- 默认 CPU、内存、并发限制
- 是否需要特殊 conda、R、编译器、网络策略

新增后运行：

```powershell
python scripts\step0_env_setup.py profiles
```

确认新 profile 能被列出来。

然后用临时项目测试：

```powershell
python scripts\step0_env_setup.py init --project C:\Users\Freeman\AppData\Local\Temp\step0-my-hpc-test --profile my-hpc --env-name st1
python scripts\step0_env_setup.py validate --project C:\Users\Freeman\AppData\Local\Temp\step0-my-hpc-test
```

## 12. 如何增强生成的新项目文件

如果想让每个新项目都多生成一个文件，流程是：

1. 在 `templates\` 中新增模板文件。
2. 在 `scripts\step0_env_setup.py` 中把这个模板加入生成清单。
3. 如果文件依赖新配置字段，同步更新 `schemas\step0_env.schema.json`。
4. 更新 `docs\ARCHITECTURE.md` 或 `docs\EXTENDING.md`。
5. 更新测试 `scripts\test_step0_env_setup.py`。
6. 运行测试和临时项目初始化验证。

不要只改某一个新项目里的文件，然后忘记同步回插件仓库。通用逻辑应该沉淀到插件仓库。

## 13. 如何修正环境安装逻辑

远端环境配置的核心逻辑通常在：

```text
templates\run\step0\setup.sh
templates\run\step0\step0_env_lib.sh
templates\scripts\setup\install_r_packages_step0.R
templates\scripts\setup\validate_step0.R
```

修改原则：

- conda 第一阶段只做 bootstrap，不把 Seurat、monocle3、CellChat 等重包塞进初始 solve。
- R 包优先在 R 内部逐个安装，每个包单独日志。
- 失败包记录到状态文件，不能让一个包阻塞整个环境配置。
- conda fallback 也要逐个包执行，避免一次大 solve 卡死。
- 所有长任务都要有日志、状态文件、失败记录和可监控入口。
- 远端脚本避免复杂一行命令，尽量写成可独立执行的脚本。

## 14. 如何增强自然语言触发能力

如果发现新对话里说某句话时 Codex 没有触发插件，可以修改：

```text
skills\step0-env-setup\SKILL.md
```

重点改两处：

- `description`：让触发描述覆盖更多表达方式。
- `Natural Language Use`：增加用户可能会说的中文/英文示例。

例如可以加入：

```text
请用 step0 插件给这个项目配置远端 R 环境
把当前项目初始化成可复用的远端 conda/R step0 workflow
新服务器环境配置第0步，用 gx4 profile
```

修改后重新打开 Codex 或新建对话，让技能列表刷新。

## 15. 如何发布一个更新版本

建议每次稳定改动都提交到 GitHub：

```powershell
cd C:\Users\Freeman\plugins\step0-env-setup
git status --short
python scripts\test_step0_env_setup.py
git add .
git commit -m "feat: describe the change"
git push
```

如果想生成一个便携 zip：

```powershell
python scripts\step0_env_setup.py package --output dist\step0-env-setup.zip
```

这样即使另一台电脑暂时没有 git，也可以直接复制 zip 解压使用。

## 16. 常见问题

### 16.1 SSH key 页面为什么没有 README、.gitignore、license

因为那是 GitHub 的 SSH key 管理页面，只负责添加公钥。README、`.gitignore`、license 只在新建仓库页面出现。

### 16.2 `git push` 报 Repository not found

常见原因：

- GitHub 上还没有创建这个仓库。
- remote URL 写错。
- 当前 SSH key 没有权限。

检查：

```powershell
git remote -v
ssh -T git@github.com
```

### 16.3 自然语言没有触发插件

可能原因：

- 插件没有注册到当前账号的 marketplace。
- Codex 还没有重新加载插件。
- `SKILL.md` 触发描述不够明确。

解决：

- 检查 `$HOME\.agents\plugins\marketplace.json`。
- 确认插件目录在 `$HOME\plugins\step0-env-setup`。
- 重启 Codex 或新建对话。
- 必要时直接用 CLI。

### 16.4 新电脑没有 GitHub SSH

先用 HTTPS 克隆：

```powershell
git clone https://github.com/VinFreeman/step0-env-setup.git $HOME\plugins\step0-env-setup
```

以后需要 push 时，再配置 SSH 或 GitHub token。

## 17. 推荐长期工作方式

长期建议遵循这个原则：

```text
插件仓库维护通用能力。
新项目只改项目配置。
新服务器优先新增 profile。
踩坑后把修正沉淀回插件模板和 runbook。
每次修改插件都运行测试、临时初始化验证、提交并推送。
```

这样以后新项目、新电脑、新账号、新服务器，都可以从同一个 `step0-env-setup` 仓库开始，不再重复整理第 0 步环境配置。
