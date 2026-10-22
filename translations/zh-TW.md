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

## fb7a7cdc21c4d02195309aab8da82ba00b67ff5a
G1 使用者選定的 Windows 執行檔，每次啟動都會被打斷，並在一段冷卻時間內（預設 300 秒）無法執行。

## 06989b8a28576a4a0900332e318867ea9e3de19a
G2 冷卻按每一局遊玩收取——不是一輩子一次，也不是一天一次。

## 72e5cec46f6d109f30287054d9400858402a003b
G3 受保護的清單隨時可以修改；任何執行檔都可以，不限於遊戲。

## 66e4581cbd2c7598e091ac7a953cc2fedffc180e
G4 不在清單上的東西完全不受影響。

## c44803396ddfe85d04af23c733f705e89f9bddf4
G5 隨 Windows 工作階段一起啟動，不需要手動開啟。

## 6561cdb72e1ed681f1b585c136a8abdc058e5ca6
G6 等完冷卻之後，會得到一段有時限的啟動許可；讓它過期，就要重新等一次冷卻。

## 678856e79c0ed6b45655acd5f1bc43727007875b
AC1 保護 C:\Windows\System32\charmap.exe 時，啟動它後，視窗出現 2 秒內就會被關閉。測試對象刻意選用一個普通的 Win32 執行檔：這條標準在實測前原本寫的是 notepad.exe，但它在 Windows 11 上是一個應用程式執行別名，會讓 AC1 通過，而它本該關掉的視窗卻還開著。見 GOTCHAS.md。

## 4c272055a8dd5e92280ce12351b753eee52058c2
AC2 冷卻期間再嘗試啟動，同樣會被關閉，而且不會延長剩餘時間。

## 93a639576a2ebfe4cd0c3da246454f01648832c7
AC3 冷卻結束後，在寬限時間內啟動會成功，並可以一直執行下去。

## d89ee4bc541f161c93bf5511f73b14ce99a0cd41
AC4 寬限時間到期都沒有啟動，就回到起點：下一次啟動要收一次完整的冷卻。

## 156da6e49631966d0ed8a17c856fc7031989500a
AC5 結束一局已被允許的遊玩後再重新啟動，會重新收一次冷卻。

## 3e8eee1e0ad760afc3aa656b6fab49615a66e0bb
AC6 在以上每個時間點，未受保護的應用程式都能正常啟動。

## 1157a134266577d63c641ca6528ebfa27b632e03
AC7 冷卻中途重新開機不會清除它——剩餘時間在工具和 Windows 都重新啟動之後仍然保留。

## 1808823f2adb67113ac6db58fa56f97dae894dfd
AC8 不用特地去找，就能看到剩餘時間。

## 092cd41381457ce6e06046b3d2793cfa9a31eee1
AC9 沒有任何程式在啟動時，CPU 使用量低到量不出來。

## 2800d8bddd0119dfccaebf012f5d8db9e1031f3c
AC10 reducer 由測試驅動，過程不涉及任何 Windows API，也沒有真實的程序。

## 8f753071905f116e751aea36e08e361952c98eff
判斷邏輯的那一半通過了（ : 29 個通過； : 17 個通過，包括 First_launch_is_terminated_and_starts_the_cooldown 和 A_protected_launch_is_terminated_and_the_cooldown_is_written_to_disk），但 2 秒內關閉真實程序的那一半沒有執行：因為 GameBrake.Tray 正在執行，所以 4 個 WindowsProcessWatcherTests 被拒絕執行，另一項也沒有執行，見 Known Annoyances。依 4c1ad4f 之前已標記完成，該 commit 說十條全部完成

## 6171ec2135541bf54e7c3af3720bb11db4cd4984
並且通過，涵蓋 Retrying_during_the_cooldown_is_terminated_and_does_not_move_the_deadline 以及它在 engine 層的版本，用的是假的 terminator；真實程序的版本放在 e2e 裡，沒有執行

## 607f4d0254891ffaba40b5153254e1e55c1b32b3
並且通過，涵蓋 Launch_inside_the_grace_window_is_allowed_and_runs、A_permitted_session_is_never_interrupted 和 A_permitted_launch_is_left_running_and_followed，用的是假的 watcher

## 7d07caeee3ee7a424dcf7683065a73244fc6996e
並且通過，涵蓋 reducer 和 engine 裡的 A_lapsed_grace_window_costs_a_full_cooldown_again，用的是注入的時鐘

## 431b449a9539fc75102a4788344ae949f5edb66c
並且通過，涵蓋 Quitting_and_relaunching_is_charged_a_fresh_cooldown 和 Quitting_returns_to_idle_so_the_next_launch_is_charged_again；真實的結束事件（WindowsProcessWatcherTests）沒有執行，原因同 AC1

## 32be2de42d52c9a21f6b8eca300f20bbe7f55219
並且通過，涵蓋 An_unprotected_executable_matches_nothing 和 An_unprotected_launch_is_not_touched_and_writes_nothing；真實的 msinfo32 檢查放在 e2e 裡，沒有執行

## edaaa3ce8311b9b35579a5e2f9c997714afdb3a5
檔案的那一半通過了（ 和 ：A_cooldown_charged_before_a_restart_is_still_owed_after_one、A_deadline_survives_the_round_trip_to_the_exact_instant、A_new_engine_over_the_same_file_still_owes_what_the_last_one_charged），但「撐過 Windows 重新開機」無法在這裡用指令執行；實測的那次重新開機記在 Current Focus，於 4c1ad4f 標記完成

## 3af2970882486cccefe20772172a319fcb2d6702
「不用特地去找就看得到剩餘時間」沒有任何自動化的東西能判斷；engine 測試只檢查文字和倒數（A_refused_launch_says_so_and_says_how_long_is_left、Remaining_time_counts_down_without_any_event_arriving），而 TrayIconArt 沒有測試。在 d4c5377 和 2dfb261 之後由使用者判定

## 0199265153a2f77cc0e106c4bfa45711c657015c
在使用者正在執行的已安裝版本上（pid 15272，閒置，沒有啟動任何東西），相隔 60 秒讀了兩次 TotalProcessorTime：60.0 秒內 CPU 用量 0 毫秒，相對於 e2e 用的 1% 門檻是單核心的 0.000%；只讀取，沒有重新啟動任何東西

## 4cdb4aa826b000f35aac14d8ee6315a32b9a2627
29 個通過，Passed! Failed 0。GameBrake.Core 的目標是 net10.0 而不是 net10.0-windows，所以它碰不到任何 Windows API，而 ReducerTests 和 StorageTests 都不會啟動程序

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
