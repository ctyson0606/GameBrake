# zh-TW translations for the progress page

Each entry is a `## <hash>` line and the translation of one displayed unit.
`scripts/progress.sh --untranslated` lists what is missing or orphaned.

## c846901838885f2176babbed232d011afdef89e4
想玩的衝動和真的開始玩之間，什麼都沒有隔著：雙擊一下，距離立刻消失，等到意識到代價時，這一局已經開始了。封鎖整台電腦的工具，連工作用的電腦也一併拿走；而意志力正是已經失靈的那一樣。缺少的是衝動和遊玩之間一段刻意的間隔，只套用在選定的應用程式上，而且每一局都重新收一次。

## bedcde58d8fceca9acb214d9e51952737a021b32
v1 已完成，並且每天在用。GameBrake.Core 放 reducer 和兩個 store，GameBrake.Windows 放 watcher、enforcer 和把它們接起來的 engine，GameBrake.Tray 放圖示和選單。50 個測試通過，其中 29 個不需要 Windows、也不需要真實的程序。端對端腳本 15 項全部通過。

## a4ca00163d0d481676e3f28c025fa54325cbb1a6
十條驗收標準全部完成。其中兩條需要人來判斷，而不是腳本：

## b2d25bdf4adab91c887cd67d936b961bd6fd784b
AC7，在一次真實的 Windows 重新開機中量測。冷卻在 17:36:48 開始計算，期限是 17:41:48；電腦在 17:37:28、也就是冷卻開始 40 秒後重新開機，系統匣程式在開機 81 秒後自行回來，到 17:41:05 仍顯示冷卻中、剩 43 秒。state.json 從 17:36:48 之後沒有被改寫，所以生效的正是重新開機前寫下的那個檔案。

## f71718f4fe062b9fd6f86505c8b6d7f0c31dcef5
AC8，在倒數移進圖示之後由使用者判定。只靠工具提示不夠：它顯示在螢幕上時會凍結，這是 Windows 殼層的行為而不是這裡的缺陷，所以再怎麼更新文字也沒有用。

## d861c9c55d18014776394a33cc171b39856b9169
它能攔住當初為之而寫的那款遊戲，保護的是一個執行檔而不是兩個。有效的條目是 VALORANT-Win64-Shipping.exe，config.json 裡只放它。第一次使用時 VALORANT.exe 也被保護，兩者在幾乎同時的期限上相隔 16 毫秒各被收了一次冷卻，當時在這裡被記成「一次等待」而不是兩次。再次使用才發現那只是描述了某一次啟動，而不是這種設定本身：兩個都保護時，使用者在等完第一次冷卻之後又被擋了一次。只保護 VALORANT.exe 時，遊戲完全不會被擋。兩者都不需要另外解釋：兩個條目就是兩個 id，因此是兩個獨立的冷卻，只有兩個程序剛好處在同一階段時才看起來像一次等待；而 Terminate 只結束一個程序、從不結束它的整個程序樹，所以結束啟動鏈的第一環，遊戲還是會繼續跑。每款遊戲一個條目，而且要是真正擁有這一局的那個執行檔。

## a86456a803fbc1b49a4354290f79c1c540aa5953
安裝在 %LOCALAPPDATA%\Programs\GameBrake，並由 Run 登錄機碼啟動，所以和建置輸出無關。那裡現在放的是 dist/ 裡的單一檔案，取代了 2026-09-12 之前整包複製的 bin/Release/net10.0-windows 裡的 11 個檔案。這次更換不需要修改 Run 機碼，也沒有動它：它原本就存著新檔案接手的那個絕對路徑。任何改動，只有再次複製那一個檔案之後才會進到日常使用。

## 78229b61e55d36df3ea178528a891c22c786df05
2026-08-23 的安全審查讀過每一個原始碼檔案，找到一件值得修的事：單一實例的 mutex 可以被這個工作階段裡的任何東西搶走，之後系統匣程式每次啟動都會一聲不響地結束。現在它會先確認是否真的有另一個 GameBrake 程序存在，才讓出位置。已建置、測試、安裝，並且是對著已安裝的執行檔確認，而不是建置輸出。

## 9443132ba12b787f3e4e8934c93cb5c178b84a77
審查沒有找到其他需要處理的事。沒有網路相關的程式碼，除了 System.Management 之外沒有第三方相依；manifest 是 asInvoker；唯一碰到的登錄機碼是 HKCU Run，其值有正確加上引號；反序列化是用 System.Text.Json 對應到不含多型的 record；唯一一個 Process.Start 呼叫使用固定路徑。這個工具能看到的範圍很廣，但它保留的東西是零——見 METHOD.md，那裡已把這一點寫成規則。

## 5a26f50fcce2f2bfd5ec10e17611a25b7c1fad38
這個 repository 現在能向沒讀過原始碼的人說明自己。README.md、README.zh-TW.md 和 README.zh-CN.md 涵蓋：這個工具是什麼、四個階段以及其中兩個值得知道的特性、如何建置、如何打包成一個自含的檔案並複製到它自己的位置、未簽章的檔案第一次啟動時會遇到的 SmartScreen 警告、config.json 的每一個鍵，以及為什麼要保護的是遊戲本體執行檔而不是啟動器。裡面的一切都是從原始碼讀出來的，而不是從這個檔案。授權為 MIT。

## 812e6837c5e08848a63bdd2e7a8f832ee99241f3
已批准的 v1 規格——問題、目標、非目標、驗收標準、資料和 API 合約，以及記錄下來的假設 A1 到 A6——在 SPEC.md 裡。它在 2026-10-01 從這個檔案搬過去，當時框架給了規格一個獨立的檔案。

## 3af2970882486cccefe20772172a319fcb2d6702
「不用特地去找就看得到剩餘時間」沒有任何自動化的東西能判斷；engine 測試只檢查文字和倒數（A_refused_launch_says_so_and_says_how_long_is_left、Remaining_time_counts_down_without_any_event_arriving），而 TrayIconArt 沒有測試。在 d4c5377 和 2dfb261 之後由使用者判定

## f3dc151c953d4384c5748892e97cee7304ab9fd8
先用著。300 秒是不是對的數字、使用者模式的阻力夠不夠（N7），這些是關於使用者的問題，只有實際使用才能回答。

## 5530dbc022ed4c29d3cf87383943530e796aea44
如果其中任何一個的答案是否定的，下一步已經決定並寫好了：更長的冷卻只是改一個設定值，而強化就是 N7 底下的 SYSTEM 服務。

## 8038f73bbec72d9ca081c25bfef77aa8f252e569
沒有阻擋進度的問題。

## 09f3b18848d923a58505ce15fb01c7a057f224db
那兩個 Valorant 的行為曾短暫被當成待解問題寫在這裡，但它們不是。兩個條目收兩次冷卻，以及保護的是啟動鏈第一環時攔不住遊戲，這兩件事都正是資料合約和 Terminate 的決定所說會發生的。把一個已有記載的後果寫成謎團，只會引人去實測一件兩個段落外就寫著的事。

## 8a76ea2485d856f208b44a43362296ef7a4877a3
有兩項刻意延後：

## 18dcebbea9bb77548b91c780df1c5678f0c6b419
網址／網站的冷靜期（N1）。延後，不是否決。它能不能沿用同一個 reducer，還沒有研究過。

## 99fe51598a36bfa9418bf585b7aaa51d1ac24f2b
強化為 SYSTEM 服務（N7）。只有在實際使用中發現使用者模式的阻力不夠時才重新考慮——這是關於使用者的問題，不是程式碼的問題。

## 38b35d992a15ce300ce2dce434f5084f9c0a6d64
註明有兩個目標沒有任何驗收標準覆蓋

## 0a724d620235ff38a35f76baacd92b3d51633512
依實際執行的指令記錄驗收狀態，以及 kit 0.6.0 的安裝

## 025593cb71c59fd4dc2d21e23f77913ccaddf282
安裝進度頁：stub、TRANSLATION、空白的段落

## cbb0a9aa2885e28526ea44f3491962aa3b606fa9
更新 SparkForge 到 0.6.0

## 68670002d27966a8a5b59396498556cbd3c86795
更新 SparkForge 到 0.2.1

## 319dddf6cd59743be426cfa5e25f25ae64d6d2b7
更新 SparkForge 到 0.2.0，並把規格搬到 SPEC.md

## 736732815d030426c62e26df3a5e70b051aa39ec
發佈一個自含的檔案，取代一個裝了 11 個檔案的資料夾

## c11a59926039f5614048baf6907bbac988f93b4e
不再把一個已有記載的後果稱為謎團

## 4bf319f100ab6683bc6d85b63bd826e49bc2c9fb
註明 Valorant 的啟動順序已經消失，而不只是沒人再問

## c13c212295c79da7888c7221c080973f99a99457
修正 Valorant 的條目，它把一次啟動描述成了一種習慣

## 77dfac5be40f4998280ec9401c7f8e276d9235d4
記錄 README，以及它在加入過程中違反的規則

## 4cfef67d6b5e2b737e480cd5ae56a9f30da3e790
用三種語言說明這是什麼，以及採用什麼授權

## 28ff7cffffd9e292268e1d8d7af7ce0a0c3cf2c2
驗證第二份副本，而不是相信一個沒人負責的名字

## cfa8be3c005700ca4d37c62263000c884abdaf19
更新 memory，並清掉六條已經不再成立的說法

## 7d75aaf41584a90454c09d708ad74a7d53b1d58f
記錄第一次真正攔住了一款遊戲

## 3f2fd1f5eba0e8fc1891875d61b6b9619ecc39fb
在一次真實的重新開機中完成 AC7，十條標準也因此全部完成

## 19e7d6c5432fc5cf18eeaa938a2bb480dcfe9fd6
完成 AC8，並改為不再從建置輸出執行

## b7b5741e40da926cb96cec120d3e28dc6ed84c33
加入設定和狀態的 store，完成 AC7 中磁碟的那一半

## 03d03ef8d0969ff30ce1e6822a9d21c4dc812dd3
判斷邏輯的那一半通過了（`dotnet test tests/GameBrake.Core.Tests`：29 個通過；`dotnet test tests/GameBrake.Windows.Tests --filter "FullyQualifiedName!~WindowsProcessWatcherTests"`：17 個通過，包括 First_launch_is_terminated_and_starts_the_cooldown 和 A_protected_launch_is_terminated_and_the_cooldown_is_written_to_disk），但 2 秒內關閉真實程序的那一半沒有執行：因為 GameBrake.Tray 正在執行，`dotnet test` 拒絕執行它的 4 個 WindowsProcessWatcherTests，而 `scripts/e2e.ps1` 也沒有執行，見 Known Annoyances。依 4c1ad4f 之前已標記完成，該 commit 說十條全部完成

## c60255732f2b48aefe6c373f63f4800baaaa2f54
`dotnet test tests/GameBrake.Core.Tests` 和 `dotnet test tests/GameBrake.Windows.Tests --filter "FullyQualifiedName!~WindowsProcessWatcherTests"` 通過，涵蓋 Retrying_during_the_cooldown_is_terminated_and_does_not_move_the_deadline 以及它在 engine 層的版本，用的是假的 terminator；真實程序的版本放在 e2e 裡，沒有執行

## a405c37b0620bb5a39ff10d5278a855cdaf02c68
`dotnet test tests/GameBrake.Core.Tests` 和 `dotnet test tests/GameBrake.Windows.Tests --filter "FullyQualifiedName!~WindowsProcessWatcherTests"` 通過，涵蓋 Launch_inside_the_grace_window_is_allowed_and_runs、A_permitted_session_is_never_interrupted 和 A_permitted_launch_is_left_running_and_followed，用的是假的 watcher

## 0a62202c34969c58850531808334fc34ce25f437
`dotnet test tests/GameBrake.Core.Tests` 和 `dotnet test tests/GameBrake.Windows.Tests --filter "FullyQualifiedName!~WindowsProcessWatcherTests"` 通過，涵蓋 reducer 和 engine 裡的 A_lapsed_grace_window_costs_a_full_cooldown_again，用的是注入的時鐘

## 913a5523583d5ec8665fc65b8aa6951e4cc914c5
`dotnet test tests/GameBrake.Core.Tests` 和 `dotnet test tests/GameBrake.Windows.Tests --filter "FullyQualifiedName!~WindowsProcessWatcherTests"` 通過，涵蓋 Quitting_and_relaunching_is_charged_a_fresh_cooldown 和 Quitting_returns_to_idle_so_the_next_launch_is_charged_again；真實的結束事件（WindowsProcessWatcherTests）沒有執行，原因同 AC1

## e1f53727875ea7f386507b682f8dbd2691725433
`dotnet test tests/GameBrake.Core.Tests` 和 `dotnet test tests/GameBrake.Windows.Tests --filter "FullyQualifiedName!~WindowsProcessWatcherTests"` 通過，涵蓋 An_unprotected_executable_matches_nothing 和 An_unprotected_launch_is_not_touched_and_writes_nothing；真實的 msinfo32 檢查放在 e2e 裡，沒有執行

## 030284606d9bd2ccdcd27b915b4bf4491ad54560
檔案的那一半通過了（`dotnet test tests/GameBrake.Core.Tests` 和 `dotnet test tests/GameBrake.Windows.Tests --filter "FullyQualifiedName!~WindowsProcessWatcherTests"`：A_cooldown_charged_before_a_restart_is_still_owed_after_one、A_deadline_survives_the_round_trip_to_the_exact_instant、A_new_engine_over_the_same_file_still_owes_what_the_last_one_charged），但「撐過 Windows 重新開機」無法在這裡用指令執行；實測的那次重新開機記在 Current Focus，於 4c1ad4f 標記完成

## ebdf49f9616518f1233dd3410a93abceff981e7a
`Get-Process GameBrake.Tray` 在使用者正在執行的已安裝版本上（pid 15272，閒置，沒有啟動任何東西），相隔 60 秒讀了兩次 TotalProcessorTime：60.0 秒內 CPU 用量 0 毫秒，相對於 e2e 用的 1% 門檻是單核心的 0.000%；只讀取，沒有重新啟動任何東西

## 41a09931ed3ad608f20553fcdcbed560d36725c5
`dotnet test tests/GameBrake.Core.Tests`：29 個通過，Passed! Failed 0。GameBrake.Core 的目標是 net10.0 而不是 net10.0-windows，所以它碰不到任何 Windows API，而 ReducerTests 和 StorageTests 都不會啟動程序

## 2b1f179c35527a0af8e7931fb683f18a48a9a665
按 SparkForge 的 README 格式改寫 README

## f8aaea6c6928407b92d21d7389b52b6459535a0b
更新 SparkForge 到 0.7.0，加上 readme skill 的 stub 和分派行

## 18a371dac3dbf876784d8374bd6e85a4ac6e8ac9
把進度頁翻譯成繁體中文

## 607e02ae95f70320dbe264a01f48a27a858a9b96
更新 SparkForge 到 0.6.3，並完成進度頁需要手動做的步驟

## 2a1267149828857da29760ba3bb43e5029e2b081
置中的開頭、照 kit 順序排列的 emoji 段落、取自 Environment facts 的指令，並拿掉沒有任何東西保持同步的測試數字。

## c431dc84b1699c3332f56430b48d1eecfefc1fc0
kit/ 透過 update-kit.sh 更新；kit/ 以外的部分照 kit/project-requirements.txt 列出的補上：進度頁的 stub、TRANSLATION 那一行、AGENTS.md 裡的翻譯例外和進度頁說明，以及空白的 Acceptance status、Milestones 和 Components 標題。

## 476ca219f2003abb5b4003b3d2a1d2b6974b8c64
update-kit.sh 不再卡在登入提示：它會在幾秒內失敗，並印出 SSH 格式的網址。這次更新也是 0.2.0 帶來的自我複製更新器第一次真正執行。

## 8fcd678a79eea683b75d9d3ecf673914986cbeae
kit/ 透過這個專案自己的 update-kit.sh，經由 SSH 從 SparkForge 取得，這是它第一次從真正的遠端拉到真正的改動。其餘部分手動複製一次，因為 update-kit.sh 只寫 kit/：腳本變成指向 kit/scripts/ 的 stub、入口檔案提到 SPEC.md、AGENTS.md 加入邊做邊寫 memory 的規則、新的 Environment facts 註解和 SPEC.md 匯入、METHOD.md 換上新的分類、STATE.md 加了 Upstream 段落。這個專案自己的標題、facts 和規則沒有改變。

## 6658920833e260385e49bb98f42fdc1d003b612a
v1 規格一字不改地從 STATE.md 搬到 SPEC.md。關於路徑檢查漏掉 scripts/e2e.ps1 的註記刪掉了：上游已經修好，並隨這次更新到來，現在兩個 .ps1 路徑都會檢查。

## f3f7664a351e08fe1944c63a43c54eebcc98d9f0
回報的阻力在安裝，不在使用：系統匣選單本來就能加入程式、勾選自動啟動，但要拿到一份能用的版本，得 clone、建置、整包複製 bin/Release，還要讓十一個檔案保持在一起，其中任何一個不見都是看不出症狀的失敗，直到某次啟動沒被攔下。scripts/pack.ps1 會把單一自含檔案發布到 dist/，如果 dist/ 裡除了那個執行檔還有別的東西，腳本就會失敗，這是它唯一的保證。

## c455df3baaf33a48a5a358ee2bc6f8422ca2f62c
這裡是實測而不是估算：未壓縮 111 MB，壓縮後 49.4 MB，而借用電腦上已安裝 .NET 的資料夾版本只有 0.6 MB。壓縮是在量測之前就打開的，而且不管結果如何都會保留，這個順序是錯的——五次啟動看不出成本（到 managed Main 的中位數 92 毫秒，資料夾版本是 102 毫秒）是運氣，不是證明。那個數字量的是 Main 第一行取得 mutex 的時間，和 watcher 何時開始運作毫無關係。

## d77fe3c6cd0ec27f60b6a6fd16a591ddea8ead22
發布的檔案保留 GameBrake.Tray.exe 這個名字。縮短成 GameBrake.exe 比較好看，但會弄壞單一實例檢查，因為它比對的是程序名稱：改名後的那份和舊的已安裝版本互相看不到，於是兩個都跑、兩個都監看、兩個都寫 state.json。要讓名字可以安全地改，就得改那個檢查，而除了好看之外沒有更好的理由要求這麼做。

## 0298917e2d7844bbd5bdde2a07be49fe86edcdb8
%LOCALAPPDATA%\Programs\GameBrake 裡的已安裝版本現在就是那一個檔案。Run 機碼不需要修改也沒有動，因為它本來就存著新檔案接手的路徑。是對著已安裝的執行檔驗證，而不是建置輸出：charmap 在 358 毫秒後被結束，冷卻期間再試一次是 799 毫秒後，兩次之後 cooldownEndsAt 完全相同——AC2 是實際觀察到的，不是從 reducer 測試推論出來的。config.json 和 state.json 事先備份並還原了。

## 07ceb08bf6bd04cd650caeb4203d34c2f746ec7e
沒有安裝程式、沒有開始功能表項目、沒有出現在「新增或移除程式」，也沒有簽章，所以在新電腦上第一次啟動都會出現 SmartScreen。三份 README 都說明了這點，並寫出新的步驟：執行腳本、複製一個檔案、勾選 Start with Windows。

## a60a800dd4ee0b4483eb6adaa32446f1a936172a
METHOD 加入這次掙來的規則：發布出去的產物不是測試跑過的那個產物。dotnet test 和 e2e.ps1 跑的都是 Debug 輸出，所以 runtime pack、原生函式庫的自我解壓和壓縮，都落在整套測試的另一邊。同樣的區分之前已經決定了單一實例修正，那次是對著已安裝的執行檔確認的；這是它第二次決定什麼算證據。這個缺口也記成一個麻煩事，因為沒有任何自動化的東西能補上它。

## a42e6b51d799a74592206a5be0f863a4bf7e6379
AGENTS.md 加了一個 pack 鍵，這超出了被要求的範圍，所以在這裡點名。它不在框架列出的鍵裡，但沒人列出的建置指令，就是下一個 session 不知道存在的建置指令，而 STATE.md 聲稱 Environment facts 已經完整。

## 9c64e4bea7cd00ca83031c62c659a0970b4f1e0f
check.sh 通過。dotnet test 通過 50 個，照規定先結束了系統匣程式。e2e.ps1 沒有重跑：它跑的是 Debug 建置，而 src/ 和 tests/ 都沒有改動。

## 40fa3d19a5917a0f8e783bd8f52fb453262e5861
使用者對上一個 commit 提出反對，而且是對的。兩個項目被收兩次冷卻，並不是需要重現的未知行為：兩個設定項目就是兩個 id，而 BrakeEngine 以 id 為鍵存狀態，所以它們是兩個獨立的冷卻，只有在兩個程序剛好處在同一階段時才會重合。一旦其中一個結束、另一個繼續跑，它們就分開了，結束的那個下次啟動就要重新收費。保護啟動鏈的第一環會失敗，原因就寫在 ProcessEnforcer 本身：只結束一個程序，從不結束它的整棵程序樹。

## 57ed99ef08139f01ee8295c26903076dea95dcb2
兩者都是在寫下這段之前到原始碼裡確認過的，而不是憑記憶從合約裡回想。

## 2f214007c494d1414c0882afc3664872a8b01714
所以那兩個 Open Questions 撤回了，段落裡說明了它們為什麼不該放在那裡。把一個已有記載的後果寫成謎團，會讓下一個讀者去量測一件兩個段落外就寫著的事，而且要重現它，還得讓這位使用者再付一次冷卻、再被擋一次。

## f379b13745ab1fc8e60abf96a48b6cdeee613b76
A4 現在帶著可操作的形式：每款遊戲一個項目，而且要是真正擁有這一局的那個執行檔。README 把「兩種行為都還不清楚」換成了真正的原因，這正是一個遊戲由啟動鏈組成的陌生人需要的。

## dec46b75ee451279174042b896dbc476131be0e1
完整保留下來的是修正本身。舊的說法——兩個都保護沒問題、仍然只是一次等待——是錯的，不管是誰的設定造成的都必須拿掉，而從中掙來的 METHOD 規則依然成立：看過一個循環，不等於描述了行為。

## 39379a80e97fc4c25382264db158402f315c15d8
check.sh 通過。

## edafe5385c59fbfe3a8b50f41ab6a0719749c039
第二次被擋背後有兩種可能——遊戲打開後又被關掉，或者根本沒打開而又收了一次新的冷卻——指向不同的原因，而沒有人記下發生的是哪一種。再問一次也找不回來。STATE 現在寫明了這點，讓下一個讀者去重現它，而不是再花一個問題問它。

## 456903ff3b22ea0199bab5e133fe3eb732f8722b
這是使用中回報的，而且和這個 repository 從第一次攔住這條啟動鏈以來的說法矛盾。VALORANT.exe 和 VALORANT-Win64-Shipping.exe 都保護時，使用者在等完第一次冷卻之後又被擋了一次。只保護 VALORANT.exe 時，遊戲完全不會被擋。config.json 裡只該有 VALORANT-Win64-Shipping.exe，現在它就是這樣。

## f9f1d6eb25b236b1cf458e9d9a3053f7cb47239d
之前寫的並不是錯誤的量測。兩個執行檔確實在幾乎同時的期限上相隔 16 毫秒各被收了一次。錯在把它寫成「一次等待而不是兩次」，這是在描述這種安排，而不是描述被觀察的那一次啟動；它看起來像個發現，是因為旁邊放著一個真實的量測。METHOD 加入規則：看過一個循環，不等於描述了行為。這個工具的整個主題就是下一次啟動會發生什麼，所以第一次啟動是最不能證明什麼的循環——這和關於繞過成本的規則問的是同一個問題，只是問的對象換成了觀察。

## 0bbae4281be1bab8299c4119eb5490cfb2626968
兩種機制都沒有解釋清楚，紀錄裡也沒有去猜。兩者都放進 Open Questions，並附上能釐清它們的量測：在發生的當下讀 state.json，而不是事後，並找出第二次被擋的那一刻是哪個項目在冷卻。已知 Riot Client 會啟動不是它子程序的程序，這可能是、也可能不是第二個問題的形態；它被記成一個猜測，就只是猜測。

## 3161258f945ec7eced23f3b2d1f7d9973ac3cc10
三份 README 現在都說要保護那個執行檔，而且只保護它，並加上陌生人需要的通則：如果受保護的遊戲還是開起來了，或者讓你等了兩次，先試試它啟動鏈裡的另一個執行檔，再下結論說工具壞了；看系統匣選單就知道實際被收費的是哪個項目。

## 7ea22d1aa4b06470b78cbaf5599a4c2935255f0f
重讀整份 STATE.md 又發現一行過時的內容，和這些都無關：state.json 裡有四個孤立的項目和一個有效的，而不是檔案說的兩個。

## 182f4003f208a5fe72a69a9c567dff1d34bf1429
check.sh 通過。src/ 和 tests/ 都沒有改動。

## afc0cce3f770f23cc1bc66521126d55648ced574
應要求更新 memory，涵蓋三份 README 和授權。

## 9ea2d7f441a14ed612ae822b29bfa25d438a61fc
METHOD 加入一條慣例，由一個拒絕了初稿的檢查掙來：翻譯文字，不翻譯讀者會複製的行。程式碼區塊裡的內容，除了只有註解的行之外，在每個翻譯版本裡都必須一模一樣，因為那部分是被複製到終端機，而不是被閱讀的；一個被翻譯掉的指令，壞掉的對象正是最沒能力和原文比對的讀者。所以狀態圖在三個檔案裡都保持同一種語言——這裡本來就該如此，因為那四個階段名稱就是 state.json 裡存的值——在下面用文字解讀它；需要翻譯的註解移到自己的一行，檢查本來就豁免這種行。

## 6d11154db167ebbe5643d21054f9e6cc567e0094
STATE 記錄了 README 涵蓋的內容、工具現在採用 MIT、為什麼是三個檔案而不是一個檔案加上將來翻譯的承諾，以及為什麼要有授權：沒有授權的 repository 在法律上可能不能被重用，這比任何人的本意都嚴格，而且純粹是因為漏寫而造成的。Next Steps 裡關於打包的段落現在說明，安裝步驟寫在 README 裡，而不是只在這個檔案裡。

## 0c3328fe6e6709ec4dd1b0c6edcd49876a4dc640
一個新的麻煩事，是這次改動造成的，而不是發現的。README 引用了三個數字——50 個測試、其中 29 個不需要 Windows、15 個端對端檢查。寫的時候是實際數出來的，不是從 STATE.md 抄的，但只要加一個測試，三個檔案就全錯了，而 check.sh 只會比對翻譯版本彼此，從不和測試套件比對。和 TrayIconArt 是同一類缺口。

## ff53c4e288c341cb9075f23c3611f08dedb3768d
GOTCHAS 加入一個 heredoc 失敗，標明原因未查明：八 KB 的內容透過帶引號的 heredoc 交給 cat，回傳「unexpected EOF」而且什麼都沒寫，而含有同樣可疑字元的三行卻順利通過。沒有去追查界線，因為替代做法毫無成本，條目也照實這麼說，而不是暗示有一個量測過的大小限制讓人可以據此設計。

## 71c92007b03b6b90c7f231da4e611b4fbb11d017
重讀了整份 STATE.md，而不只是這個 session 動過的段落。裡面沒有任何內容被 README 推翻：沒有一行說 repository 沒有文件，而 AGENTS.md 本來就預期會有用使用者語言寫的 README。第 12 行的測試和 e2e 數字依據的是上一次執行測試套件的結果，這個 session 沒有重跑，所以這裡沒有更新它們。

## f907481cd04cfd2d3471152b34b39d4db8763480
在這之前，這個 repository 只能向願意讀 METHOD.md 和原始碼的人說明自己。README 涵蓋了工具做什麼、四個階段以及其中兩個值得知道的特性、如何建置、把建置輸出複製到它自己的位置並讓 Run 機碼指向那份、config.json 的每個鍵，以及為什麼要保護的是遊戲本體而不是啟動器。英文、繁體中文和簡體中文，互相連結。

## c3fa1fe00e404d26f77b034b076693b16a20e418
裡面的一切都是從原始碼讀出來的，而不是從記憶或 STATE.md：設定鍵來自 Configuration.cs，兩個檔案路徑來自 GameBrakePaths.cs，Run 值的名稱來自 Autostart.cs，狀態機來自 Reducer.cs。兩個數字是實際數出來的，不是引用的——50 個 [Fact]，沒有 theory 也沒有 inline data，其中 29 個在 GameBrake.Core.Tests；scripts/e2e.ps1 裡有 15 個 Check 呼叫。

## 9bb947b93e5a45a2a2bd91f84376df9fc2e4bf77
check.sh 本來就有一條這方面的規則，並抓到了初稿：讀者從程式碼區塊複製出來的行，在每個翻譯版本裡都必須一模一樣，而狀態圖和建置指令後面的註解都被翻譯了。現在狀態圖在三份裡都保持英文，這本來就是對的，因為那四個名稱就是 state.json 裡實際存的值，下面用文字解讀；指令的註解移到自己的一行，這正是檢查本來就允許的例外。然後故意讓檢查失敗——在簡體版改一個字——再讓它通過，所以確定它能回報兩種答案。

## c224e25baf9a5a82bcea373cce9fc3ffb1d41e67
MIT，反正這裡本來就沒有保留什麼。

## b9910151adc15405ed7ab8c9858ce0cce2944d3c
dotnet build -c Release 成功，執行檔就在 README 印出的路徑上。dotnet test 和 scripts/e2e.ps1 沒有執行：系統匣程式正在跑，README 自己也記錄了這會讓四個整合測試失敗，而 e2e 腳本會覆寫真正的 %APPDATA%\GameBrake。兩者都照實記錄下來，而不是繞過去。

## 4d63703dff207967cc0d7c565da9015fdcf92de0
對整個專案的安全審查找到一件要處理的事。單一實例檢查把「mutex 名稱被佔用」當成「我的另一份正在執行」，這是猜測而不是事實：具名物件沒有擁有者，工作階段裡任何東西都能先佔走這個名稱。只要幾行程式佔住它然後睡著，之後每次啟動都會一聲不響地結束，沒有系統匣圖示，什麼也看不出來。

## db1de051fb68c52a0abfeee53eee126a05354ee4
這在這裡比在別處更要緊。N7 接受工具可以被關掉，理由是關掉它是一個刻意的動作，而那個動作本身就是它在賣的停頓。這個繞過只要付一次，之後就悄無聲息，等於用零持續成本買到永久豁免，而它失敗的樣子和一個沒人啟動過的工具一模一樣。METHOD.md 現在把這個區分寫成規則：問一個繞過第二次要付出什麼。

## 4584f45ad6e5df2073762fe305668cc76970272b
修正改成直接問那個名稱原本只是代替的問題。如果不存在第二個 GameBrake 程序，就沒有衝突可言，於是系統匣程式照常啟動，佔著名稱的那個可以繼續佔著。程序名稱是從正在執行的程序讀出來的，而不是寫死的，所以就算替執行檔改名，也不會讓這個檢查悄悄變成永遠比對不到任何東西。

## 0d4ce20263379a72aa65e9ff91306336f71c9bda
是對著已安裝的執行檔驗證的，而不是建置輸出。先做對照組，顯示名稱是空著的，然後讓佔位程式佔住它，系統匣程式照樣啟動並保持運作：兩種答案都觀察到了，所以確定這個探測能回報任何一種。50 個測試通過。Release 建置後複製到 %LOCALAPPDATA%\Programs\GameBrake，那才是日常實際執行的版本。

## 9d4dbf13eb34c8aba2592a1e126b8c94a7ab780d
審查中沒有其他需要處理的事。STATE.md 記錄了檢查過什麼，以及保留而不修的三個低風險發現；METHOD.md 加入整台電腦可見性的不變條件、從磁碟而不是從開場快照讀 memory 和 git 狀態的規則，以及第一條反模式：命名空間化 mutex 這個不算修正的修正。

## e72d145eea1c0a995bf8a32faa5c7cb975a00085
應要求更新 memory。是重讀整份 STATE.md，而不只是這個 session 動過的段落，才發現這些——這正是那條規則的用意：它說還不存在任何碰到 Windows 的東西、還有兩條標準沒完成、45 個測試通過、主程式還不存在，而這些都就寫在反駁它們的段落上方幾行。測試數字和 AC9 的措辭也更正了，三個重疊的決策段落現在合併成一個講設計、一個講使用後改變了什麼。

## 84f9a414436c398616a2e820eeb49dcc7806ac11
METHOD 加入兩條規則並修正第三條。掃描規則變成檢查規則，因為同一種失敗換了外貌出現兩次：一個 pattern 根本不可能比對到的 grep，以及一個列出必須存在的鍵、因此永遠察覺不到多出來的鍵的斷言。新增：先量測障礙再設計繞過它，起因是差點為了一個其實一直都授予 PROCESS_TERMINATE 的反作弊而放寬完整路徑比對。新增：當某樣東西看起來什麼都沒做時，去觀察它而不是推理它，起因是三個回報有三個互不相關的原因，沒有一個能靠推論得出。

## 7b02906631253384e1959bc50bf413780abb15ce
修正後啟動 Valorant，它被關掉了，state.json 第一次同時有兩個執行檔的冷卻項目。它們相隔 16 毫秒被收費，因為啟動鏈從 VALORANT.exe 接著啟動 VALORANT-Win64-Shipping.exe，而兩個都受保護；期限重合，所以是一次等待而不是兩次。

## f5be326d65b8ecc2182a2a246ebe1f96508af769
看見 WMI 不肯描述的程序

## 8aba86e9499e60f64d5e8aaefee20248dbb91f83
Valorant 啟動時毫髮無傷，原因是它從來沒被看見。Vanguard 讓 Win32_Process 對遊戲執行檔回報 null 的 ExecutablePath，watcher 丟掉了每一個叫不出名字的啟動，所以 state.json 從來沒有任何這款遊戲的項目。

## 816e39d299619c849ee993777a6c4e2971370589
先檢查的是能不能結束程序，因為如果程序事後結束不了，偵測的修正就一文不值。兩個 Valorant 執行檔都授予 PROCESS_TERMINATE；只有 Vanguard 自己的服務拒絕，而那個本來就不需要結束。

## 418963f6988e10acf5669d28e1589a9f423af480
這個修正讓 A4 保持完整。Process.MainModule 在這些程序上會失敗，因為讀取模組需要 PROCESS_VM_READ，但 QueryFullProcessImageName 只需要 PROCESS_QUERY_LIMITED_INFORMATION，這個有授予，而且它會回傳真正的完整路徑。另一個選擇是把比對放寬到只看檔名，那會為了一個其實只是選錯 API 的問題，換來一個更差的工具。

## 0ddff558c911065a198d2d1608b8e8aa70305e30
另外記錄下來、而且因為修不了所以沒修的：Riot 啟動器會把自己以背景模式放進 Run 機碼，所以它從登入起就常駐，依 A5 不受管轄，按下 Play 只是喚醒它而不是啟動它。要保護遊戲執行檔，不是啟動器。

## f19f935a31e380b30ef7086c1d367145015521c4
是實測，不是論證。冷卻在 17:36:48 開始計算，期限是 17:41:48；電腦在 17:37:28、也就是開始 40 秒後重新開機；系統匣程式在開機 81 秒後自行回來；到 17:41:05 仍顯示冷卻中、剩 43 秒。state.json 從 17:36:48 之後沒有被改寫，所以生效的正是重新開機前寫下的那個檔案。期限被遵守而不是被重設，剩餘時間在重新開機期間照樣倒數。

## 1e914e230db03d0aea83f2fbf42bfb61d4675b7d
之前一次同樣的測試看起來像失敗，其實不是。那次開機時檔案總管當掉了，而 Run 項目是由檔案總管啟動的，通知區域也屬於它，所以什麼都沒啟動。事件記錄裡寫得很清楚。

## ea46dcd3439dac20b104ae9f6591cd7134f6232f
這次測試暴露了一個缺口，而這裡沒有修：開機到系統匣程式出現之間大約八十幾秒，受保護的程式啟動不會被攔。已經欠下的冷卻仍然有效，所以這不是逃掉冷卻的方法，但它是一個免費開始新一局的方法。要堵住它，就得在使用者工作階段之前執行，那就是這個專案決定不做的服務。

## 58c35315e2e6590b6a67366741ce2f4d17cab523
AC8 達成，是倒數移進圖示之後從實際使用判斷的。單靠工具提示不行：它顯示時會凍結，這是 Windows 殼層的行為而不是這個工具的問題，所以再怎麼更新文字都沒用。

## a3563a4870758789be17905aa187623384eda014
發布到使用者自己的程式資料夾，並讓自動啟動指向那裡。自動啟動記錄的是絕對路徑，而 bin/Debug 底下的路徑，只要一次 dotnet clean，就會變成一個悄悄不再回來的工具。這是複製出來的資料夾，不是安裝程式；安裝程式依然刻意不做。

## 761f09812332f292879baf44b7943ae7fb8e4ee3
AC7 現在是唯一還沒完成的標準，而它需要有人實際重新開機。

## 9d6e4937f6da5433d2a9c32e0c3b74b23d6c9903
把倒數畫進系統匣圖示

## 99ae6389dc9b81ccd53ba2992f9063aed3b33dcc
使用中回報：工具提示顯示時會凍結。殼層只在通知圖示的工具提示出現時讀一次，之後再也不讀，所以數字會停住，直到滑鼠移開再回來。為了這個去做一個自訂的提示視窗，會是一大堆脆弱的機制換來一個更差的答案，所以倒數改放進圖示，圖示會原地重畫，完全不需要滑鼠。

## 05f898762af91fcee80ee56d56860779fc32cf92
要讓它清楚可讀，花了三輪，還做了一個把每種狀態都畫到檔案裡的預覽，因為殼層要的是 16 像素，而這個尺寸毫不留情。紅底上的半透明圓環看不見。兩位數字糊成一團：59 和 28 讀不出來，5 和 9 很清楚。不到一分鐘時什麼都不顯示，留下一個空圓盤，看起來像壞掉的圖示。而按整段冷卻比例縮放的圓環每秒只動三分之一個百分點，這正是原本的抱怨換了個樣子。

## 5461d838632bf23d9ab47b75c480f72240aac3cf
現在的做法：用一位數字顯示分鐘，數 5 4 3 2 1 然後變綠，圓環像時鐘一樣掃過目前這一分鐘內的秒數。精確數字留在工具提示和選單裡。

## c40ba9d42ff34c64e97eba03ff3d1e91b78e1b1a
不要把計算出來的冷卻寫進 config.json

## e590277c4e33c8813c75260ffe4a9b505156d390
是實際使用時發現的。Configuration.Cooldown 是只有 getter 沒有 setter 的屬性，所以它被序列化寫出，讀回時又被丟掉。config.json 最後多了一個看起來像冷卻設定的東西，就放在真正的設定旁邊，卻什麼作用都沒有。手動改它而不是改 cooldownSeconds，什麼都不會變，工具會一聲不響地繼續用舊的值。

## 6592332b0fa2980a0464b3513501ff3b2b27fa88
本來應該抓到它的測試用的是 Assert.Contains，它只能察覺少了某個鍵，永遠察覺不到多出來的鍵。現在它斷言完整的鍵集合，另外還有一個測試會把儲存的設定來回讀寫一次，讓只寫不讀的屬性立刻失敗。

## cecb5ee8b1ea6c55f4fa32172247f98c40fbd0f6
另外，整合測試會和一份正在執行的產品搶測試對象。在一秒的 WMI 輪詢間隔內啟動又結束的程序完全不會產生建立事件，所以失敗看起來像是 watcher 從沒看到啟動，指向了錯誤的東西。現在 fixture 會在系統匣程式執行時拒絕執行，並說明原因。

## 36d16d267e005661d38ec3272857e4210bfb28ed
用推導取得 e2e 的系統匣路徑，而不是寫死某台電腦的路徑

## 1ffdc8321213911945698fce72804089160d7d97
推送前做了一次隱私檢查。scripts/e2e.ps1 帶著一個絕對路徑，這等於把一台電腦的目錄結構公開給讀這個 repository 的人，而且在其他每份 clone 上都會壞。現在它改從 PSScriptRoot 取得。改完重跑：15 項全部通過。

## c457ff2ec7f61309d90f2ab55f4bdba36a3fdc87
第一次做那個修改時把檔案弄壞了。透過內嵌 python heredoc 寫入的 Windows 路徑少了一層跳脫，所以 bin 的序列變成退格字元，net10.0 的序列變成換行。GOTCHAS.md 和 METHOD.md 的前兩條都是從這裡來的：路徑用正斜線寫，而且不要相信一個從沒被證明能比對到任何東西的掃描，因為那個路徑還在專案裡時，兩次 grep 都說它是乾淨的。

## 3993a0fbe883752c142d9d4133cba1436c464fe7
專案裡和任何 commit 裡都沒有其他憑證、家目錄或電腦名稱。

## ff32bdb52e170d5385a9de90871c2bbdf7001a4c
加入系統匣主程式，並對著它執行驗收標準

## ad553cf0d651f50aac883c5a5303222fc75329cf
Next Steps 第 1 項。GameBrake.Tray 負責圖示、選單和氣球提示；它驅動的連接邏輯放在 BrakeEngine 裡，藏在 IProcessWatcher 和 IProcessTerminator 後面，所以可以用假的 watcher 和測試控制的時鐘來測。有十三個測試這樣做。忘記儲存狀態，或忘記追蹤被允許的程序，否則就要等到真正的遊戲才會發現。

## 6910207cc2aa70e5214ca3225e9cb7c8a95769af
狀態是在結束程序之前寫入，而不是之後。如果程序在兩者之間死掉，冷卻仍然欠著；反過來的順序會把它弄丟，而弄丟冷卻正是最要緊的失敗。

## 98ec2f1dbd55a04708ce985ab3d8db447e82554d
scripts/e2e.ps1 用縮短的冷卻驅動建置好的系統匣程式跑過所有標準：15 項全部通過。它的第一版回報 AC7 失敗，那是腳本的問題而不是工具的。十五秒的冷卻比重新啟動那一段花的時間還短，所以工具合理地往下走了，而檢查把它讀成遺失。現在它的每一次等待都從檔案裡的期限推導出來。

## 6949f32fc5cae3bc1e5ae3947b2cd035150c7f02
AC7 照字面寫的是重新開機，AC8 問的是一個數字是不是在人會看的地方。兩者都不能用腳本完成，都記為未完成。

## 58e71af91fea7dd8ab97ca1c291813fe82da915e
AGENTS.md 的 Environment facts 現在完整了，包括 dev 和 e2e，每一項都實際執行過。

## 6dbfe4128def5017997fa32cb605b47f15e14b29
加入程序監看器和結束程序的元件

## 5f1b913ebc9fa4f0a7a9cb617641d97776c9b5b1
Next Steps 第 1 和第 2 項，建立在探測確定下來的機制上。GameBrake.Windows 的目標是 net10.0-windows，兩者都放在這裡；Core 保持與平台無關，這樣 reducer 就碰不到這些東西。

## b7e9c0a4bc1231040853448684fd1226d8d0e43b
啟動事件來自 __InstanceCreationEvent WITHIN 1，因為以事件為基礎的 Win32_ProcessStartTrace 不允許使用者模式程序使用。結束事件不靠第二個訂閱：那會讓 AC9 在意的輪詢加倍，去回答一個本來就能精確回答的問題，因為唯一有意義的結束，是這個工具允許的程序的結束，而它的身分在被允許的那一刻就已經知道了。一個在被追蹤之前就結束的程序仍然會被回報，否則那個程式就會卡在執行中的階段，之後的任何啟動都不會被收費。

## 4f614312061d07e76753f77564ff7118089e32e2
Terminate 只結束一個程序，從不結束它的程序樹，所以從啟動器開的遊戲不會把啟動器一起帶走。

## 1acd32b5828cc410a94ce1a5190bbd6e43995227
有四個測試是對著真實程序跑的，包括以真實時間期限測的 AC1。它們連續四次執行都通過了，現在 dotnet test 會開關真正的視窗大約八秒，這記成一個麻煩事。

## e591a3e9714c0f2d866c953f29374e43f06d7ede
記錄 watcher 探測量到了什麼，以及它弄壞了什麼

## 64c4b19aa6a874de018bb2d08ef402f6fb8bcc5b
照 Next Steps 說的，在建造程序監看器之前先探測它。三個發現，都連同數字寫進了 GOTCHAS.md。

## 6a92a37633d3b0b96201121548e982fa2207324b
機制確定了：Win32_ProcessStartTrace 在沒有提權時會被拒絕，所以路線是 __InstanceCreationEvent WITHIN 1，它可以用，而且帶有 ExecutablePath。一個普通執行檔的偵測時間中位數是 347 毫秒，AC1 允許 2 秒。更短的 WITHIN 間隔量出來反而更慢，所以維持 1。

## ce4c4479312cea17f7ea9fa7d933c4fdf8e9d5c7
這次弄壞了兩件事，現在都是阻擋進度的 Open Questions。AC1 指定的是 notepad.exe，它在 Windows 11 上是一個應用程式執行別名：保護它在 System32 的路徑，比對到的是一個會自己結束的 stub，而真正的封裝程序繼續開著視窗。AC1 會在什麼都沒做的情況下通過。另外，封裝的應用程式，包括 Game Pass，所在的路徑帶著每次更新都會變的版本號，完整路徑比對撐不過去。

## bb7c23e6fbf84839475e6b99a1812d4d41458b43
閒置成本記為尚未確定。把 CPU 歸到這個訂閱頭上，得到的是負的差值，所以成本低於背景 WMI 活動的雜訊下限。那不等於零，AC9 不能靠它。

## 658c31c0f903eb8cf2c8fd75cd2fe592144e50b9
Next Steps 第 1 項。GameBrake.Core 現在在 reducer 旁邊加了 Storage/：config.json 照使用者寫的樣子讀取，state.json 帶著絕對期限，撐過程序的重新啟動。

## 69ac6c18391644050ce96c124c65ea4c99b099fb
時間點一律寫成以 Z 結尾的 UTC，這是資料合約記載的格式，也是手動讀檔的人不用計算就能理解的格式。讀取時用的是通用的解析器，所以被改成帶本地時差的檔案，代表的仍然是同一個時刻。

## bd7d414d3e4ca81c92989644b25fc7221efc6c2f
損壞的檔案會拋出錯誤，而不是退回空值。把損壞的狀態讀成什麼都不欠，會讓弄壞它成為一次逃掉所有冷卻最便宜的方法；把損壞的設定讀成什麼都不保護，會在不聲不響中解除工具的作用。state.json 先寫到暫存檔再移到目標位置，所以斷電不會留下寫了一半的檔案。

## 8586f9b4e9e5e7d45ac6dd683cf23a2373e8cae6
AC7 照字面寫的是重新開機，那仍然需要一個主程式。現在涵蓋的是不需要主程式就能做到的兩半。

## 9715f4df7de6ff7c1311c8bde3c274e8355e1694
建立方案骨架，並建好冷卻的 reducer

## 00eb662c9db2381a5b0147cc9b705dbdc532967b
Next Steps 第 1 和第 3 項。GameBrake.Core 把整個冷卻規則寫成一個純函式，GameBrake.Core.Tests 涵蓋每一條關於規則而不是關於 Windows 的驗收標準。

## 53a56b008b7df788cfe92c86befd5bcde3ee2724
Core 的目標是 net10.0 而不是 net10.0-windows。AC10 要求 reducer 在不涉及任何 Windows API 的情況下可以測試，而以中立框架為目標，會讓呼叫 Windows API 變成編譯錯誤，而不是一件要記住的事。

## 9a80d58aa5aebb15e4a612255894a9b9360fc50c
reducer 裡有兩個決定值得知道。過期在檢查事件之前先處理，所以決定永遠不取決於 Tick 有沒有準時到達：否則一次落在兩個 tick 之間的啟動，或一台在整段冷卻期間都在睡眠的電腦，會被拿去和一個早已過去的期限比較。而程序結束只在執行中的階段才有意義，因為結束一次啟動本身就會產生一個結束事件，如果理會它，冷卻會在收費的那一刻就被退還。

## af5ea4a696ea0a92604aca6adf686e9748487ecb
AGENTS.md 的 Environment facts 現在有 install、test 和 build，每一項都實際執行過。dev 和 e2e 保持空白，因為還沒有東西可以執行；typecheck 和 lint 是 none，後者記成一個麻煩事。

## 873710bd5933d81c088f0b63a36079dcd7afbf6c
把批准的 v1 規格記錄在 STATE.md

## 71998551af60f17307b8368f72059f3864827649
Bootstrap 第 4 到 6 步。規格門以 project 深度執行，結果已經批准：問題、目標、非目標、驗收標準，以及資料和 API 合約。

## 729437ca49af4a94462c4aeabc3d8bd648308255
兩個決定決定了其餘的工作。冷卻換來的是有時限的許可，而不是無限期的許可，所以不能早上先把冷卻付掉，讓一整天都不受管。而工具保持在使用者模式：它賣的是停頓，不是一道牆。

## 8a64ed87101f285e5e24f969935926bde0be94d7
AGENTS.md 的 Environment facts 刻意保持空白。技術選型已經定了，但還沒有任何專案檔案，所以寫在那裡的任何指令都是沒人執行過的說法。

## 05a37faf17f6dc36d1515cfb84be495c1017dcd3
METHOD.md 保持空白。這個專案還沒踩到任何坑。

## 981ac86d88d1d52f99ae064058ab40607b5eb3b5
加入硬性規則：檔案用英文，對話用使用者的語言

## 2427e83d82dac84cabe5eab3e201549b7b5e222b
SparkForge 上游的規則。寫進檔案的一切——程式碼、識別名稱、commit 訊息，以及三個 memory 檔——都用英文。和使用者對話用什麼語言由他們決定。這是為了防止 memory 檔累積成兩種語言，因為那只會越積越多。

## d71be5322d22c74a649bcaba50ad834399fb8f3f
採用 SparkForge

## 420d4d81df02aa7c69f391592c15e729d8efab4f
M1: v1 — 冷卻煞車

## 8c850fc4125ce5be821b913b94b77564431d1455
G1 (M1) 使用者選定的 Windows 執行檔，每次啟動都會被打斷，並在一段冷卻時間內（預設 300 秒）無法執行。

## f0ba3dd13cf2a93592c92b7cf7061688e1b4e838
WMI 監看器會回報每一個程序啟動；用完整路徑比對清單，受保護的程序會立刻被結束。期限在結束程序之前就寫進 state.json，所以重新開機也清不掉，剩餘分鐘數畫在系統匣圖示上。

## 449918c49919ffbd77d2531dd57acef08f9e2d82
G2 (M1) 冷卻按每一局遊玩收取——不是一輩子一次，也不是一天一次。

## 09fbe7acfc5868709ec1dc5c626c7a054490953b
reducer 在一局開始時收取冷卻，程序結束時把程式放回閒置，所以下一局又要付一次。整套規則是一個純函式，不靠 Windows 就能測試。

## eae1d6435e2cdf0168e8bd2aeef27cac9fa7b5f8
G3 (M1) 受保護的清單隨時可以修改；任何執行檔都可以，不限於遊戲。

## 98f4ef33939011367345cdd3643f560ad72ca570
系統匣選單可以把任何 .exe 加進清單，config.json 也能手動修改；存檔的那一刻就會重新載入。

## 43ecfdc65e9de4441e404182fed79791774b7b86
G4 (M1) 不在清單上的東西完全不受影響。

## 6ab60bc95dc493711c8f4c84eedd33421b228f20
只有完整路徑相符才會採取行動，其他東西一律不碰；沒有程式在啟動時，系統匣程式一分鐘內的 CPU 用量低到量不出來。

## 7371abad9c30bf7dff83c86e22e5bc378f84c779
G5 (M1) 隨 Windows 工作階段一起啟動，不需要手動開啟。

## bffd8901c9f5992a96dc6cbe55c0b635886d0c06
勾選 Start with Windows 會把已安裝那份的路徑寫進 HKCU 的 Run 機碼，所以登入時系統匣程式就會啟動。

## 247d43f30fbd424ca60abdb7d62ab10584ad7699
G6 (M1) 等完冷卻之後，會得到一段有時限的啟動許可；讓它過期，就要重新等一次冷卻。

## f04402a3608f986877be4de39027e180dc16025c
期限過後，reducer 從期限本身起算開一段寬限時間；在寬限時間內的啟動會放行並持續追蹤，過了之後的啟動要付一次完整的冷卻。

## b6e9e86f36d5f72a3415245a9f4beb2a151c7ae3
AC1 (G1) 保護 C:\Windows\System32\charmap.exe 時，啟動它後，視窗出現 2 秒內就會被關閉。測試對象刻意選用一個普通的 Win32 執行檔：這條標準在實測前原本寫的是 notepad.exe，但它在 Windows 11 上是一個應用程式執行別名，會讓 AC1 通過，而它本該關掉的視窗卻還開著。見 GOTCHAS.md。

## 2cc4a562edb1d518bad509f026c52ec67190b15f
AC2 (G1) 冷卻期間再嘗試啟動，同樣會被關閉，而且不會延長剩餘時間。

## 1e7255017544c9419c5a1d24c2027cd42aff7319
AC3 (G6) 冷卻結束後，在寬限時間內啟動會成功，並可以一直執行下去。

## a3051adaab3d15c679e32d69b1cd0a101534266a
AC4 (G6) 寬限時間到期都沒有啟動，就回到起點：下一次啟動要收一次完整的冷卻。

## 47f037960d2b9d529d90b81a8095ef19be0815c7
AC5 (G2) 結束一局已被允許的遊玩後再重新啟動，會重新收一次冷卻。

## 85a887b676ee9353b6e4a00a8d670b8379c8fb11
AC6 (G4) 在以上每個時間點，未受保護的應用程式都能正常啟動。

## a685bc2d350c6b7f5b1f96b65507bd566a4f5b99
AC7 (G1) 冷卻中途重新開機不會清除它——剩餘時間在工具和 Windows 都重新啟動之後仍然保留。

## 95dd96870f2e7d77eee8b0ba76d22fed693da595
AC8 (G1) 不用特地去找，就能看到剩餘時間。

## 3323bcb9293e7ea9e9d94e4cbc67cf85eef6c262
AC9 (G4) 沒有任何程式在啟動時，CPU 使用量低到量不出來。

## 3e45fa5e597627e3619d0a58d56a6ebced4fa877
AC10 (G2) reducer 由測試驅動，過程不涉及任何 Windows API，也沒有真實的程序。

## 4679e819dbe26e1b6d3d402a59f30d44bc3f95c8
更新 SparkForge 到 0.7.2：bootstrap 改看 SPEC.md，並先確定程式碼在哪裡

## 61e645fee8cb6ab031070479df4c1bf9057bcaa8
更新 SparkForge 到 0.7.1，並翻譯時間線和完整的證據

## f8513976206981aa11965b8f3c57664347472110
0.6.3 把 commit 標題和說明也算成翻譯單位，0.7.1 讓每句證據保持完整，所以原本繞著缺口寫的九段證據翻譯都換掉了。

## a9f9bd175115ed9c0f3315fdd2ac15a43e92d095
核心

## 4f9b0362f0ee3e69a6128b3bb275d9cd15d9cc5e
冷卻規則寫成一個純函式，以及設定檔和狀態檔

## 1058cb39495f234073a350a5f6ce881068d2dadd
Windows 層

## 10db70565c5f2f916ece89b832f21b49f384f276
程序監看器、結束程序的元件，以及把它們接到規則上的 engine

## 6123ca91a0bd656e71a09848d69db191aa5abc53
系統匣

## c4b302cbf4f57995bb9846c810c19f6791850529
圖示、選單、畫出來的倒數和開機自動啟動

## 7633ddf7397cb40c681baa3deb8e6527a750e266
把驗收標準連到它們的目標，並說明每個目標是怎麼做到的

## b8d64ccd4d31b67b7a4cffaba210753382dd9275
更新 SparkForge 到 0.8.0：進度頁改成功能清單，以及 How 和 Parts 的例外規則

## 4ca7389078588ab67d345c7dc8241f215f7e0601
每條驗收標準都註明它驗證的目標，每個目標註明它的里程碑，並帶著一行 How 和它用到的部分；三個元件也列出來了。根據原始碼和既有紀錄起草，使用者在 2026-10-25 以進度頁樣板的形式看過。G3 和 G5 仍然沒有驗收標準，所以頁面說無法判斷它們。

## 6b7e71f8d0681f32d45e3bcbec5e01afda0bfa00
更新 SparkForge 到 0.8.2：需求清單固定用 LF 換行，以及把「none」顯示為沒有指令
