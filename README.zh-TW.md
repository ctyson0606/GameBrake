<!-- Hero -->
<div align="center">
  <h1>GameBrake</h1>
  <p><b>替你選定的遊戲踩煞車的 Windows 系統匣程式</b>：一啟動就立刻關掉並開始冷卻，等完冷卻才能執行。</p>
  <p>
    <img alt="platform: Windows 10 | 11" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-4d6bfe">
    <img alt=".NET 10" src="https://img.shields.io/badge/.NET-10-4d6bfe">
    <img alt="admin rights: none" src="https://img.shields.io/badge/admin%20rights-none-brightgreen">
    <img alt="license: MIT" src="https://img.shields.io/badge/license-MIT-blue">
  </p>
  <p>🌏 <a href="./README.zh-CN.md">简体中文</a> · 繁體中文 · <a href="./README.md">English</a></p>
</div>

<!-- Screenshot placeholder: commit the image at docs/screenshot.png, then remove this comment pair.
<p align="center"><img src="docs/screenshot.png" alt="GameBrake 的系統匣圖示正在倒數" width="480"></p>
-->

想玩的衝動和真的開始玩之間，什麼都沒有隔著：雙擊一下距離就沒了，等你意識到代價時，這一局已經開始。GameBrake 把這段距離重新打開。它賣的是阻力，不是強制——它用你自己的帳號執行，工作管理員就能關掉它，而關掉它本身就是一次停頓。

## ✨ 功能

- **只攔你選的**：清單上的任何執行檔都可以，不限遊戲；其他一切完全不受影響。
- **每一局收一次冷卻**：每次開始一局都要等一次，不是一輩子一次，也不是一天一次。
- **寬限時間**：冷卻結束後有一段時間允許啟動；錯過了，下一次啟動又要重新等。
- **重新開機也不會清掉**：期限以絕對時間存在磁碟上，冷卻中途重開 Windows 不會清除。
- **倒數畫在圖示上**：一個逐漸消失的圓環加上剩餘分鐘數，等待時是紅色，允許啟動時變綠色。
- **隨時修改**：用系統匣選單，或直接改 `config.json`，存檔後立刻重新載入。
- **不需要系統管理員權限**：建置和執行時都不要求。

## 🚀 安裝

前提：Windows 10 或 11（x64），以及建置用的那台電腦上的 [.NET SDK 10.0](https://dotnet.microsoft.com/download)。建置出來的檔案自帶 .NET，在沒裝 .NET 的電腦上也能跑。

**方式一 · 單一自含檔案**

```powershell
git clone https://github.com/ctyson0606/GameBrake.git
cd GameBrake
powershell -ExecutionPolicy Bypass -File scripts/pack.ps1

$target = "$env:LOCALAPPDATA/Programs/GameBrake"
New-Item -ItemType Directory -Force $target
Copy-Item "dist/GameBrake.Tray.exe" $target -Force
Start-Process "$target/GameBrake.Tray.exe"
```

然後在系統匣圖示上按右鍵，勾選 **Start with Windows**，這樣隨你登入啟動的是安裝好的那份，而不是建置輸出。

**方式二 · 直接從原始碼執行**

<details>
<summary>不想安裝、只想試一下時用這個</summary>

```powershell
dotnet run --project src/GameBrake.Tray
```

</details>

**驗證**

```powershell
Get-Process GameBrake.Tray
```

會列出一個程序，通知區域也會出現它的圖示。未簽章的檔案第一次啟動時會顯示 **Windows 已保護您的電腦**：選 **其他資訊** → **仍要執行**。

## 🕹️ 使用

### 選擇要攔的程式

在系統匣圖示上按右鍵，選 **Protect an application...**，再選一個 `.exe`。選單會列出每個受保護的項目和它目前的階段。

### 啟動時會發生什麼

```text
idle      --launch-->        terminate the process; start a cooldown
cooling   --launch-->        terminate again; the remaining time is NOT extended
cooling   --time passes-->   unlocked, for a grace window
unlocked  --launch-->        allowed; runs as long as you like
unlocked  --grace expires--> back to idle; the next launch pays in full again
running   --you quit-->      back to idle; the next session pays a fresh cooldown
```

寬限時間從冷卻的期限算起，而不是從工具發現期限已過的那一刻，所以睡過整段冷卻也不能把它拉長。

### 更新你的那份

改動只有重新打包、重新複製後才會進到日常使用：先從系統匣選單結束程式，再把方式一的最後五行跑一次，然後啟動它。

### 解除安裝

從系統匣選單結束程式，取消勾選 **Start with Windows**，再刪除 `%LOCALAPPDATA%\Programs\GameBrake` 和 `%APPDATA%\GameBrake`。

## 🎮 保護遊戲本體，不是啟動器

啟動器和遊戲是不同的執行檔；要攔的是遊戲。很多啟動器從登入起就常駐，根本沒有「啟動」可以攔。

有些遊戲會依序跑好幾個執行檔，只有其中一個才是對的。Valorant 從 `VALORANT.exe` 接著啟動 `VALORANT-Win64-Shipping.exe`：只保護 `VALORANT-Win64-Shipping.exe`。

- **兩個都保護**：兩個項目就是兩個獨立的冷卻，等完第一個還要再等一次。
- **只保護啟動器**：結束程序只會結束那一個，不會結束它的子程序，所以遊戲照樣執行。

**每款遊戲一個項目，而且要是真正擁有這一局的那個執行檔。**

## 💾 設定

`%APPDATA%\GameBrake\config.json` 可以自己改；存檔後 GameBrake 會重新載入。

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

| 項目 | 值 |
| --- | --- |
| `cooldownSeconds` | 啟動被擋之後要等多久；所有項目共用一個值 |
| `graceWindowSeconds` | 冷卻結束後許可維持多久 |
| `autostart` | 對應 **Start with Windows** 的勾選 |
| `protected[].id` | 任意 UUID；狀態以它為鍵，所以執行檔搬家後可以改指向，不會把冷卻清掉 |
| `protected[].executable` | 完整路徑，比對不分大小寫；反斜線要寫成 `\\` |
| `protected[].displayName` | 選單和通知裡顯示的名稱 |
| `protected[].enabled` | `false` 等同於這個項目不存在 |
| 檔案格式錯誤 | 會跳出對話框說明，修好之前什麼都不保護 |
| `%APPDATA%\GameBrake\state.json` | 工具自己的檔案：重新開機後仍有效的期限 |

## 🛠️ 開發與測試

還原、建置、執行：

```powershell
dotnet restore
dotnet build
dotnet run --project src/GameBrake.Tray
```

測試，接著是端對端檢查：

```powershell
dotnet test
powershell -ExecutionPolicy Bypass -File scripts/e2e.ps1
```

安裝用的單一檔案：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pack.ps1
```

- **跑 `dotnet test` 之前先結束系統匣程式**：執行中的那份會在 watcher 看到之前就把測試對象關掉，失敗看起來就像 watcher 壞了。
- **`dotnet test` 會開關真正的 `charmap.exe` 視窗**，這樣攔截才是被測試過的，而不是假設的。
- **`scripts/e2e.ps1` 會覆寫真正的 `%APPDATA%\GameBrake`**，因為工具就是在那裡讀設定；有真實資料要先備份。

C# 在建置時就會做型別檢查，目前沒有設定 linter。

## 📦 專案結構

```text
src/GameBrake.Core/
src/GameBrake.Windows/
src/GameBrake.Tray/
tests/
scripts/pack.ps1
scripts/e2e.ps1
GameBrake.slnx
```

- `src/GameBrake.Core/`：reducer——整個冷卻規則寫成一個純函式——以及兩個檔案 store；目標是單純的 `net10.0`，所以呼叫 Windows API 會直接編譯失敗；
- `src/GameBrake.Windows/`：WMI 程序監看器、結束程序的元件，以及把它們接到 reducer 的 engine；
- `src/GameBrake.Tray/`：系統匣圖示、選單、畫出來的倒數和開機自動啟動，本身不含任何規則；
- `tests/`：測試，大部分既不碰 Windows 也不碰真實程序；
- `scripts/pack.ps1`：產生 `dist/` 裡的單一自含檔案；
- `scripts/e2e.ps1`：對著真正的系統匣程式跑的端對端檢查；
- `GameBrake.slnx`：方案檔。

`METHOD.md`、`STATE.md` 和 `GOTCHAS.md` 記錄了這些決定背後的理由，包括實測後發現和預期不同的那些。

## ⚠️ 相容性與限制

- **GameBrake 啟動時已經在跑的程式，這一局不會被管**；登入時自己啟動的程式會搶先一步，直到重新開機。已經欠下的冷卻在重開後仍然有效。
- **不支援 Microsoft Store 和 Game Pass 的程式**：它們的路徑帶著版本號，每次更新都會變。
- **不會打斷已經開始的一局**，也不限制總遊玩時間；它只對每一局的開始收費。
- **不防篡改**：`config.json` 和執行檔對任何以你身分執行的程式都是可寫的。同樣的權限本來就能關掉它。
- **只支援執行檔**：不攔網站或網址。

## ❓ 常見問題

| 症狀 | 怎麼做 |
| --- | --- |
| 受保護的遊戲還是開起來了 | 改保護它啟動鏈裡的另一個執行檔：真正擁有這一局的那個 |
| 要等兩次 | 同一款遊戲兩個項目就是兩個冷卻；只留一個 |
| 第一次啟動出現 **Windows 已保護您的電腦** | 檔案沒有簽章；**其他資訊** → **仍要執行** |
| 對話框說 `config.json` 格式錯誤 | 修好 JSON；修好之前什麼都不保護 |
| `dotnet test` 的 watcher 測試失敗 | 先結束系統匣程式 |
| 跑完 `scripts/e2e.ps1` 後設定變了 | 它會覆寫 `%APPDATA%\GameBrake`；把先前備份的放回去 |

## 📄 授權

MIT，見 [LICENSE](LICENSE)。
