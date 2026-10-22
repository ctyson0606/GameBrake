<!-- Hero -->
<div align="center">
  <h1>GameBrake</h1>
  <p><b>给你选定的游戏踩刹车的 Windows 托盘程序</b>：一启动就立刻关掉并开始冷却，等完冷却才能运行。</p>
  <p>
    <img alt="platform: Windows 10 | 11" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-4d6bfe">
    <img alt=".NET 10" src="https://img.shields.io/badge/.NET-10-4d6bfe">
    <img alt="admin rights: none" src="https://img.shields.io/badge/admin%20rights-none-brightgreen">
    <img alt="license: MIT" src="https://img.shields.io/badge/license-MIT-blue">
  </p>
  <p>🌏 简体中文 · <a href="./README.zh-TW.md">繁體中文</a> · <a href="./README.md">English</a></p>
</div>

<!-- Screenshot placeholder: commit the image at docs/screenshot.png, then remove this comment pair.
<p align="center"><img src="docs/screenshot.png" alt="GameBrake 的托盘图标正在倒数" width="480"></p>
-->

想玩的冲动和真的开始玩之间，什么都没有隔着：双击一下距离就没了，等你意识到代价时，这一局已经开始。GameBrake 把这段距离重新打开。它卖的是阻力，不是强制——它用你自己的账户运行，任务管理器就能关掉它，而关掉它本身就是一次停顿。

## ✨ 功能

- **只拦你选的**：列表上的任何可执行文件都可以，不限游戏；其他一切完全不受影响。
- **每一局收一次冷却**：每次开始一局都要等一次，不是一辈子一次，也不是一天一次。
- **宽限时间**：冷却结束后有一段时间允许启动；错过了，下一次启动又要重新等。
- **重启也不会清掉**：期限以绝对时间存在磁盘上，冷却中途重启 Windows 不会清除。
- **倒数画在图标上**：一个逐渐消失的圆环加上剩余分钟数，等待时是红色，允许启动时变绿色。
- **随时修改**：用托盘菜单，或直接改 `config.json`，保存后立刻重新加载。
- **不需要管理员权限**：构建和运行时都不要求。

## 🚀 安装

前提：Windows 10 或 11（x64），以及构建用的那台电脑上的 [.NET SDK 10.0](https://dotnet.microsoft.com/download)。构建出来的文件自带 .NET，在没装 .NET 的电脑上也能运行。

**方式一 · 单个自包含文件**

```powershell
git clone https://github.com/ctyson0606/GameBrake.git
cd GameBrake
powershell -ExecutionPolicy Bypass -File scripts/pack.ps1

$target = "$env:LOCALAPPDATA/Programs/GameBrake"
New-Item -ItemType Directory -Force $target
Copy-Item "dist/GameBrake.Tray.exe" $target -Force
Start-Process "$target/GameBrake.Tray.exe"
```

然后在托盘图标上右键，勾选 **Start with Windows**，这样随你登录启动的是安装好的那份，而不是构建输出。

**方式二 · 直接从源码运行**

<details>
<summary>不想安装、只想试一下时用这个</summary>

```powershell
dotnet run --project src/GameBrake.Tray
```

</details>

**验证**

```powershell
Get-Process GameBrake.Tray
```

会列出一个进程，通知区域也会出现它的图标。未签名的文件第一次启动时会显示 **Windows 已保护你的电脑**：选 **更多信息** → **仍要运行**。

## 🕹️ 使用

### 选择要拦的程序

在托盘图标上右键，选 **Protect an application...**，再选一个 `.exe`。菜单会列出每个受保护的条目和它当前的阶段。

### 启动时会发生什么

```text
idle      --launch-->        terminate the process; start a cooldown
cooling   --launch-->        terminate again; the remaining time is NOT extended
cooling   --time passes-->   unlocked, for a grace window
unlocked  --launch-->        allowed; runs as long as you like
unlocked  --grace expires--> back to idle; the next launch pays in full again
running   --you quit-->      back to idle; the next session pays a fresh cooldown
```

宽限时间从冷却的期限算起，而不是从工具发现期限已过的那一刻，所以睡过整段冷却也不能把它拉长。

### 更新你的那份

改动只有重新打包、重新复制后才会进到日常使用：先从托盘菜单退出程序，再把方式一的最后五行运行一次，然后启动它。

### 卸载

从托盘菜单退出程序，取消勾选 **Start with Windows**，再删除 `%LOCALAPPDATA%\Programs\GameBrake` 和 `%APPDATA%\GameBrake`。

## 🎮 保护游戏本体，不是启动器

启动器和游戏是不同的可执行文件；要拦的是游戏。很多启动器从登录起就常驻，根本没有“启动”可以拦。

有些游戏会依次运行好几个可执行文件，只有其中一个才是对的。Valorant 从 `VALORANT.exe` 接着启动 `VALORANT-Win64-Shipping.exe`：只保护 `VALORANT-Win64-Shipping.exe`。

- **两个都保护**：两个条目就是两个独立的冷却，等完第一个还要再等一次。
- **只保护启动器**：结束进程只会结束那一个，不会结束它的子进程，所以游戏照样运行。

**每款游戏一个条目，而且要是真正拥有这一局的那个可执行文件。**

## 💾 设置

`%APPDATA%\GameBrake\config.json` 可以自己改；保存后 GameBrake 会重新加载。

```json
{
  "cooldownSeconds": 300,
  "graceWindowSeconds": 300,
  "autostart": true,
  "protected": [
    {
      "id": "3f2a6c18-9d41-4f0e-9b8a-1c5d7e2b4a90",
      "executable": "C:\\Program Files\\Foo\\game.exe",
      "displayName": "Foo",
      "enabled": true
    }
  ]
}
```

| 项目 | 值 |
| --- | --- |
| `cooldownSeconds` | 启动被拦之后要等多久；所有条目共用一个值 |
| `graceWindowSeconds` | 冷却结束后许可维持多久 |
| `autostart` | 对应 **Start with Windows** 的勾选 |
| `protected[].id` | 任意 UUID；状态以它为键，所以可执行文件搬家后可以改指向，不会把冷却清掉 |
| `protected[].executable` | 完整路径，匹配不分大小写；反斜杠要写成 `\\` |
| `protected[].displayName` | 菜单和通知里显示的名称 |
| `protected[].enabled` | `false` 等同于这个条目不存在 |
| 文件格式错误 | 会弹出对话框说明，修好之前什么都不保护 |
| `%APPDATA%\GameBrake\state.json` | 工具自己的文件：重启后仍有效的期限 |

## 🛠️ 开发与测试

还原、构建、运行：

```powershell
dotnet restore
dotnet build
dotnet run --project src/GameBrake.Tray
```

测试，接着是端到端检查：

```powershell
dotnet test
powershell -ExecutionPolicy Bypass -File scripts/e2e.ps1
```

安装用的单个文件：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pack.ps1
```

- **运行 `dotnet test` 之前先退出托盘程序**：运行中的那份会在 watcher 看到之前就把测试对象关掉，失败看起来就像 watcher 坏了。
- **`dotnet test` 会打开和关闭真正的 `charmap.exe` 窗口**，这样拦截才是被测试过的，而不是假设的。
- **`scripts/e2e.ps1` 会覆盖真正的 `%APPDATA%\GameBrake`**，因为工具就是在那里读设置；有真实数据要先备份。

C# 在构建时就会做类型检查，目前没有配置 linter。

## 📦 项目结构

```text
src/GameBrake.Core/
src/GameBrake.Windows/
src/GameBrake.Tray/
tests/
scripts/pack.ps1
scripts/e2e.ps1
GameBrake.slnx
```

- `src/GameBrake.Core/`：reducer——整个冷却规则写成一个纯函数——以及两个文件 store；目标是单纯的 `net10.0`，所以调用 Windows API 会直接编译失败；
- `src/GameBrake.Windows/`：WMI 进程监视器、结束进程的组件，以及把它们接到 reducer 的 engine；
- `src/GameBrake.Tray/`：托盘图标、菜单、画出来的倒数和开机自启，本身不含任何规则；
- `tests/`：测试，大部分既不碰 Windows 也不碰真实进程；
- `scripts/pack.ps1`：生成 `dist/` 里的单个自包含文件；
- `scripts/e2e.ps1`：对着真正的托盘程序运行的端到端检查；
- `GameBrake.slnx`：解决方案文件。

`METHOD.md`、`STATE.md` 和 `GOTCHAS.md` 记录了这些决定背后的理由，包括实测后发现和预期不同的那些。

## ⚠️ 兼容性与限制

- **GameBrake 启动时已经在运行的程序，这一局不会被管**；登录时自己启动的程序会抢先一步，直到重启。已经欠下的冷却在重启后仍然有效。
- **不支持 Microsoft Store 和 Game Pass 的程序**：它们的路径带着版本号，每次更新都会变。
- **不会打断已经开始的一局**，也不限制总游玩时间；它只对每一局的开始收费。
- **不防篡改**：`config.json` 和可执行文件对任何以你身份运行的程序都是可写的。同样的权限本来就能关掉它。
- **只支持可执行文件**：不拦网站或网址。

## ❓ 常见问题

| 症状 | 怎么做 |
| --- | --- |
| 受保护的游戏还是开起来了 | 改为保护它启动链里的另一个可执行文件：真正拥有这一局的那个 |
| 要等两次 | 同一款游戏两个条目就是两个冷却；只留一个 |
| 第一次启动出现 **Windows 已保护你的电脑** | 文件没有签名；**更多信息** → **仍要运行** |
| 对话框说 `config.json` 格式错误 | 修好 JSON；修好之前什么都不保护 |
| `dotnet test` 的 watcher 测试失败 | 先退出托盘程序 |
| 运行完 `scripts/e2e.ps1` 后设置变了 | 它会覆盖 `%APPDATA%\GameBrake`；把之前备份的放回去 |

## 📄 许可证

MIT，见 [LICENSE](LICENSE)。
