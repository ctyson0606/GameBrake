# GameBrake

[English](README.md) · [繁體中文](README.zh-TW.md) · **简体中文**

一个 Windows 系统托盘工具，在「想玩」和「开始玩」之间，硬塞进一段刻意的等待。

想玩的冲动和真的玩下去之间，其实什么都没有隔着——双击一下，距离就没了，等你察觉到
代价的时候，这一场已经开始了。GameBrake 把那道间隔重新撑开。当你启动一个被你放上
刹车的程序，它会立刻被关掉，并开始倒数冷却。等完了，你会得到一段短短的窗口期，在那
段时间内启动就会被放行。不在清单上的东西，完全不受影响。

它卖的是摩擦力，不是强制力。它以你自己的用户身份运行，可以从任务管理器关掉——这是
刻意的设计决定，不是疏漏。关掉它这个动作，本身就是一次停顿。

---

## 运作方式

每个受保护的程序在四个阶段之间移动：

```
idle      --launch-->        terminate the process; start a cooldown (default 300 s)
cooling   --launch-->        terminate again; the remaining time is NOT extended
cooling   --time passes-->   unlocked, for a grace window (default 300 s)
unlocked  --launch-->        allowed; runs as long as you like
unlocked  --grace expires--> back to idle; the next launch pays in full again
running   --you quit-->      back to idle; the next session pays a fresh cooldown
```

上面那四个阶段名称，就是 `state.json` 里实际会写进去的值。逐行读作：

- `idle`（闲置）遇到启动：终止该进程，开始冷却（默认 300 秒）。
- `cooling`（冷却中）遇到启动：再次终止，而且剩余时间**不会**被延长。
- `cooling` 等到时间到：进入 `unlocked`，并持有一段宽限期（默认 300 秒）。
- `unlocked`（放行中）遇到启动：允许，之后想跑多久都可以。
- `unlocked` 的宽限期过完却没去启动：回到 `idle`，下次启动重新付满整段冷却。
- `running`（运行中）你自己关掉游戏：回到 `idle`，下一场重新付一段新的冷却。

有两个性质值得知道：

- **冷却会撑过重启。** 在冷却中间重启 Windows 并不会把它清掉。截止时间是以绝对时间
  写在磁盘上的文件里。
- **宽限期是从冷却的截止时间起算**，而不是从工具「发现它过期」的那一刻起算。所以让
  电脑睡过整段冷却，并不能把宽限期撑长成一个绕道。

剩余时间直接画在托盘图标上：一圈逐渐消耗的环，中间是剩下的分钟数，等待中是红色，可
以启动了就转成绿色。

---

## 需求

- Windows 10 或 11（x64）。只支持 Windows，没有其他平台。
- 构建需要 [.NET SDK 10.0](https://dotnet.microsoft.com/download) 或更新版本。已在
  SDK 10.0.400 上验证过。
- 不需要管理员权限。构建时和运行时都不会要。

---

## 获取与构建

```bash
git clone https://github.com/ctyson0606/GameBrake.git
cd GameBrake

dotnet restore
dotnet build -c Release
```

产生的可执行文件在：

```
src/GameBrake.Tray/bin/Release/net10.0-windows/GameBrake.Tray.exe
```

想先跑跑看、不安装任何东西：

```bash
dotnet run --project src/GameBrake.Tray
```

通知区域会出现一个图标，在上面点右键就是菜单。

---

## 安装一份自己的

构建输出在你 clone 的目录里，所以任何重新构建或清理都会动到你每天在用的那一份。把它
复制到一个属于它自己的位置：

```powershell
$source = "src/GameBrake.Tray/bin/Release/net10.0-windows"
$target = "$env:LOCALAPPDATA/Programs/GameBrake"

New-Item -ItemType Directory -Force $target
Copy-Item "$source/*" $target -Recurse -Force

Start-Process "$target/GameBrake.Tray.exe"
```

接着在托盘图标上点右键，勾选 **Start with Windows**。这会把一个绝对路径写进
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`，值名称是 `GameBrake`，所以随着
登录启动的是那份「已安装」的副本，而不是构建输出。

> **更新。** 你构建出来的改动，要重复做一次上面的复制，才会真的进到日常使用。先从菜
> 单退出工具，否则文件会被占用。

卸载的方式：从菜单退出，取消勾选 **Start with Windows**（或直接删掉那个 `Run` 值），
然后删除 `%LOCALAPPDATA%\Programs\GameBrake` 和 `%APPDATA%\GameBrake`。

---

## 选择要刹什么

最省事的方式是用托盘菜单：**Protect an application…**，然后挑一个 `.exe`。

它背后的文件是 `%APPDATA%\GameBrake\config.json`，这个文件属于你，可以手动编辑。你一
保存，工具就会重新加载。

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

| 键 | 含义 |
| --- | --- |
| `cooldownSeconds` | 被拦下之后要等多久。是一个全局值，不是每个程序各自一个。 |
| `graceWindowSeconds` | 冷却结束后，那份许可持续多久。 |
| `autostart` | 对应 **Start with Windows** 的勾选状态。 |
| `protected[].id` | 任何 UUID。状态是以它为键，所以程序搬家后可以改路径，而不会把欠着的冷却一笔勾销。 |
| `protected[].executable` | **完整路径**，比对时不分大小写。JSON 里反斜杠要写成 `\\`。 |
| `protected[].displayName` | 菜单和通知里显示的名称。 |
| `protected[].enabled` | `false` 等同于这条根本不存在。 |

最外层就这四个键，没有别的。如果文件坏掉，GameBrake 会弹一个对话框说明，并且在你修好
之前**什么都不保护**——它不会偷偷退回默认值，也不会把坏掉的文件读成「没有欠任何冷
却」。

工具还会写 `%APPDATA%\GameBrake\state.json`。那个文件属于工具，里面放的是那些会撑过重
启的截止时间。

### 保护游戏本体，不要保护启动器

启动器和游戏是两个不同的可执行文件，要刹哪一个由你决定。刹游戏本体。

很多启动器（例如 Riot Client）会把自己写进 `Run` 键，从登录起就常驻，所以根本没有一次
「启动」可以拦——按下 *Play* 只是唤醒既有的进程，不是开一个新的。保护启动器的结果，
只是把它的辅助进程杀掉，而游戏照跑不误。

有些游戏会跑一串可执行文件，而那一串里面只有一环是该抓的。Valorant 是 `VALORANT.exe`
带起 `VALORANT-Win64-Shipping.exe`：请只保护 `VALORANT-Win64-Shipping.exe`，其他都不
要。两个一起保护试过了，会在你已经等完第一次冷却之后，再被罚第二次。只保护
`VALORANT.exe` 则完全拦不住游戏。

这两件事都是工具的运作方式直接推得出来的，所以任何这样分成好几个可执行文件的游戏都会
如此。两条项目就是两份各自独立的冷却——它们看起来像「只等一次」，只发生在两个进程刚好
处于同一个阶段的时候，而只要其中一个结束、另一个还在跑，就不再是同一个阶段了。另外，
终止只会结束那一个进程，不会结束它的子进程，所以把一串里的第一环关掉，游戏本身根本没
被碰到。**一个游戏一条项目，而且要挑那个真正撑着这一场的可执行文件。**

所以，如果一个被保护的游戏照样启动了，或是让你等了两次，先去换那一串里的另一个可执行
文件，再下「工具坏了」的结论。托盘菜单会列出每一条被保护的条目和它现在的阶段，那是看
出「到底是哪一个被罚」最快的方法。

---

## 开发

```bash
# 构建
dotnet build
# 50 个测试
dotnet test
# 15 项端到端检查
powershell -ExecutionPolicy Bypass -File scripts/e2e.ps1
```

跑之前有三件事要知道：

1. **跑 `dotnet test` 之前先退出托盘程序。** 正在运行的那一份会比测试里的监视器更快把
   测试对象杀掉，失败看起来就会像是监视器从来没起过作用。
2. **`dotnet test` 会真的开关 `charmap.exe` 窗口**，因此多花大约八秒。这是「拦截真的被
   测过」而不是「假设它会动」的代价。
3. **`scripts/e2e.ps1` 会覆写真正的 `%APPDATA%\GameBrake`**，因为那正是它要测的工具会去
   读的位置。里面有真的东西请先复制一份出来。

没有独立的类型检查步骤——C# 在构建时就会做类型检查——也还没有配置任何 linter。

### 项目结构

| 项目 | 里面是什么 |
| --- | --- |
| `src/GameBrake.Core` | reducer——整套冷却策略，写成一个纯函数——以及两个文件存储。目标框架是纯 `net10.0`，所以想伸手去碰 Windows API 会直接编译失败，而不是靠人自己记得别碰。 |
| `src/GameBrake.Windows` | WMI 进程监视器、终止器，以及把它们接到 reducer 上的引擎。 |
| `src/GameBrake.Tray` | 托盘图标、菜单、画出来的倒数，以及开机自启。本身不持有任何策略。 |
| `tests/` | 50 个测试，其中 29 个既不碰 Windows 也不碰真实进程。 |

---

## 已知限制

- **GameBrake 启动时已经在跑的东西，这一轮都不会被动到。** 会自己在登录时启动的程序会
  赢过托盘的竞争，然后在你重启之前一直是豁免的。已经欠着的冷却仍然会撑过重启，所以这
  不是逃掉冷却的路——但它是「一场全新的、免费的」开场的路。
- **Microsoft Store 和 Game Pass 的应用不在范围内。** 它们的路径带着一段会随每次更新改
  变的版本号，完整路径比对撑不过那个。
- **它不会打断已经开始的一场**，也不管你总共玩多久。它课的是每一次「开场」的税。
- **它不防篡改。** `config.json` 和可执行文件本身，任何以你身份运行的东西都能写，而工
  具也可以从任务管理器关掉。这是交易条件，不是另一个漏洞：同样的访问权限，本来就已经
  足以关掉它。
- **不处理网站或网址。** 只处理可执行文件。

---

## 设计笔记

这个 repository 里的 `METHOD.md`、`STATE.md` 和 `GOTCHAS.md` 记着上面这些决定背后的理
由——包括那些实际量过之后，结果和预期不一样的。动任何东西之前值得先读。

---

## 许可

MIT。见 [LICENSE](LICENSE)。
