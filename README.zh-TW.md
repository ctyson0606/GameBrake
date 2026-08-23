# GameBrake

[English](README.md) · **繁體中文** · [简体中文](README.zh-CN.md)

一個 Windows 系統匣工具，在「想玩」和「開始玩」之間，硬塞進一段刻意的等待。

想玩的衝動和真的玩下去之間，其實什麼都沒有隔著——雙擊一下，距離就沒了，等你察覺到
代價的時候，這一場已經開始了。GameBrake 把那道間隔重新撐開。當你啟動一個被你放上
煞車的程式，它會立刻被關掉，並開始倒數冷卻。等完了，你會得到一段短短的視窗期，在那
段時間內啟動就會被放行。不在清單上的東西，完全不受影響。

它賣的是摩擦力，不是強制力。它以你自己的使用者身分執行，可以從工作管理員關掉——這
是刻意的設計決定，不是疏漏。關掉它這個動作，本身就是一次停頓。

---

## 運作方式

每個受保護的程式在四個階段之間移動：

```
idle      --launch-->        terminate the process; start a cooldown (default 300 s)
cooling   --launch-->        terminate again; the remaining time is NOT extended
cooling   --time passes-->   unlocked, for a grace window (default 300 s)
unlocked  --launch-->        allowed; runs as long as you like
unlocked  --grace expires--> back to idle; the next launch pays in full again
running   --you quit-->      back to idle; the next session pays a fresh cooldown
```

上面那四個階段名稱，就是 `state.json` 裡實際會寫進去的值。逐行讀作：

- `idle`（閒置）遇到啟動：終止該行程，開始冷卻（預設 300 秒）。
- `cooling`（冷卻中）遇到啟動：再次終止，而且剩餘時間**不會**被延長。
- `cooling` 等到時間到：進入 `unlocked`，並持有一段寬限期（預設 300 秒）。
- `unlocked`（放行中）遇到啟動：允許，之後想跑多久都可以。
- `unlocked` 的寬限期過完卻沒去啟動：回到 `idle`，下次啟動重新付滿整段冷卻。
- `running`（執行中）你自己關掉遊戲：回到 `idle`，下一場重新付一段新的冷卻。

有兩個性質值得知道：

- **冷卻會撐過重新開機。** 在冷卻中間重開 Windows 並不會把它清掉。截止時間是以絕對
  時間寫在磁碟上的檔案裡。
- **寬限期是從冷卻的截止時間起算**，而不是從工具「發現它過期」的那一刻起算。所以讓
  電腦睡過整段冷卻，並不能把寬限期撐長成一個繞道。

剩餘時間直接畫在系統匣圖示上：一圈逐漸消耗的環，中間是剩下的分鐘數，等待中是紅色，
可以啟動了就轉成綠色。

---

## 需求

- Windows 10 或 11（x64）。只支援 Windows，沒有其他平台。
- 建置需要 [.NET SDK 10.0](https://dotnet.microsoft.com/download) 或更新版本。已在
  SDK 10.0.400 上驗證過。
- 不需要系統管理員權限。建置時和執行時都不會要。

---

## 取得與建置

```bash
git clone https://github.com/ctyson0606/GameBrake.git
cd GameBrake

dotnet restore
dotnet build -c Release
```

產生的執行檔在：

```
src/GameBrake.Tray/bin/Release/net10.0-windows/GameBrake.Tray.exe
```

想先跑跑看、不安裝任何東西：

```bash
dotnet run --project src/GameBrake.Tray
```

通知區域會出現一個圖示，在上面按右鍵就是選單。

---

## 安裝一份自己的

建置輸出在你 clone 的目錄裡，所以任何重新建置或清理都會動到你每天在用的那一份。把它
複製到一個屬於它自己的位置：

```powershell
$source = "src/GameBrake.Tray/bin/Release/net10.0-windows"
$target = "$env:LOCALAPPDATA/Programs/GameBrake"

New-Item -ItemType Directory -Force $target
Copy-Item "$source/*" $target -Recurse -Force

Start-Process "$target/GameBrake.Tray.exe"
```

接著在系統匣圖示上按右鍵，勾選 **Start with Windows**。這會把一個絕對路徑寫進
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`，值名稱是 `GameBrake`，所以隨
著登入啟動的是那份「已安裝」的複本，而不是建置輸出。

> **更新。** 你建置出來的改動，要重複做一次上面的複製，才會真的進到日常使用。先從選
> 單結束工具，否則檔案會被佔用。

移除的方式：從選單結束，取消勾選 **Start with Windows**（或直接刪掉那個 `Run` 值），
然後刪除 `%LOCALAPPDATA%\Programs\GameBrake` 和 `%APPDATA%\GameBrake`。

---

## 選擇要煞什麼

最省事的方式是用系統匣選單：**Protect an application…**，然後挑一個 `.exe`。

它背後的檔案是 `%APPDATA%\GameBrake\config.json`，這個檔案屬於你，可以手動編輯。你一
存檔，工具就會重新載入。

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

| 鍵 | 意義 |
| --- | --- |
| `cooldownSeconds` | 被擋下之後要等多久。是一個全域值，不是每個程式各自一個。 |
| `graceWindowSeconds` | 冷卻結束後，那份許可持續多久。 |
| `autostart` | 對應 **Start with Windows** 的勾選狀態。 |
| `protected[].id` | 任何 UUID。狀態是以它為鍵，所以程式搬家後可以改路徑而不會把欠著的冷卻一筆勾銷。 |
| `protected[].executable` | **完整路徑**，比對時不分大小寫。JSON 裡反斜線要寫成 `\\`。 |
| `protected[].displayName` | 選單和通知裡顯示的名稱。 |
| `protected[].enabled` | `false` 等同於這筆根本不存在。 |

最外層就這四個鍵，沒有別的。如果檔案壞掉，GameBrake 會跳一個對話框說明，並且在你修好
之前**什麼都不保護**——它不會偷偷退回預設值，也不會把壞掉的檔案讀成「沒有欠任何冷
卻」。

工具還會寫 `%APPDATA%\GameBrake\state.json`。那個檔案屬於工具，裡面放的是那些會撐過重
新開機的截止時間。

### 保護遊戲本體，不要保護啟動器

啟動器和遊戲是兩個不同的執行檔，要煞哪一個由你決定。煞遊戲本體。

很多啟動器（例如 Riot Client）會把自己寫進 `Run` 鍵，從登入起就常駐，所以根本沒有一次
「啟動」可以攔——按下 *Play* 只是喚醒既有的行程，不是開一個新的。保護啟動器的結果，
只是把它的輔助行程殺掉，而遊戲照跑不誤。

有些遊戲會跑一串執行檔，而那一串裡面只有一環是該抓的。Valorant 是 `VALORANT.exe` 帶起
`VALORANT-Win64-Shipping.exe`：請只保護 `VALORANT-Win64-Shipping.exe`，其他都不要。兩
個一起保護試過了，會在你已經等完第一次冷卻之後，再被罰第二次。只保護 `VALORANT.exe`
則完全擋不住遊戲。這兩件事目前都還不知道原因。

所以，如果一個被保護的遊戲照樣啟動了，或是讓你等了兩次，先去換那一串裡的另一個執行
檔，再下「工具壞了」的結論。系統匣選單會列出每一筆被保護的項目和它現在的階段，那是看
出「到底是哪一個被罰」最快的方法。

---

## 開發

```bash
# 建置
dotnet build
# 50 個測試
dotnet test
# 15 項端到端檢查
powershell -ExecutionPolicy Bypass -File scripts/e2e.ps1
```

跑之前有三件事要知道：

1. **跑 `dotnet test` 之前先結束系統匣程式。** 正在執行的那一份會比測試裡的監看者更快
   把測試對象殺掉，失敗看起來就會像是監看者從來沒作用過。
2. **`dotnet test` 會真的開關 `charmap.exe` 視窗**，因此多花大約八秒。這是「攔截真的被
   測過」而不是「假設它會動」的代價。
3. **`scripts/e2e.ps1` 會覆寫真正的 `%APPDATA%\GameBrake`**，因為那正是它要測的工具會
   去讀的位置。裡面有真的東西請先複製一份出來。

沒有獨立的型別檢查步驟——C# 在建置時就會做型別檢查——也還沒有設定任何 linter。

### 專案結構

| 專案 | 裡面是什麼 |
| --- | --- |
| `src/GameBrake.Core` | reducer——整套冷卻策略，寫成一個純函式——以及兩個檔案儲存體。目標框架是純 `net10.0`，所以想伸手去碰 Windows API 會直接編譯失敗，而不是靠人自己記得別碰。 |
| `src/GameBrake.Windows` | WMI 行程監看者、終止者，以及把它們接到 reducer 上的引擎。 |
| `src/GameBrake.Tray` | 系統匣圖示、選單、畫出來的倒數，以及開機自動啟動。本身不持有任何策略。 |
| `tests/` | 50 個測試，其中 29 個既不碰 Windows 也不碰真實行程。 |

---

## 已知限制

- **GameBrake 啟動時已經在跑的東西，這一輪都不會被動到。** 會自己在登入時啟動的程式會
  贏過系統匣的競速，然後在你重開機之前一直是豁免的。已經欠著的冷卻仍然會撐過重開機，
  所以這不是逃掉冷卻的路——但它是「一場全新的、免費的」開場的路。
- **Microsoft Store 和 Game Pass 的應用程式不在範圍內。** 它們的路徑帶著一段會隨每次更
  新改變的版本號，完整路徑比對撐不過那個。
- **它不會打斷已經開始的一場**，也不管你總共玩多久。它課的是每一次「開場」的稅。
- **它不防篡改。** `config.json` 和執行檔本身，任何以你身分執行的東西都能寫，而工具也可
  以從工作管理員關掉。這是交易條件，不是另一個漏洞：同樣的存取權限，本來就已經足以關
  掉它。
- **不處理網站或網址。** 只處理執行檔。

---

## 設計筆記

這個 repository 裡的 `METHOD.md`、`STATE.md` 和 `GOTCHAS.md` 記著上面這些決定背後的理
由——包括那些實際量過之後，結果和預期不一樣的。動任何東西之前值得先讀。

---

## 授權

MIT。見 [LICENSE](LICENSE)。
