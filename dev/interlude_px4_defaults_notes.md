# 作業計画: 間章「PX4の既定の設定を確かめる」

教材を作る側の作業メモ。読者向けではない。判断の原文は [`dev/qa_log.md`](qa_log.md) の2026-11-22の行にある。

作成: 2026-11-22

## 1. 目的と位置づけ

- **きっかけ**: 作者がフェーズ5（Position modeで操縦桿を操作）で機体を壁にぶつけたところ、機体は逆さまに落ちた。そのあともプロペラが止まらず、地面に向かって推力を出し続けた。この状態は、強制のディスアームまで続いた。
- **目的**: PX4の既定の設定は、使う人の期待どおりとは限らないので、思い込まずに確かめられるようになる。具体的には、次の4つ。
  - シミュレーションで想定と違う動きを見つける
  - パラメータで直す
  - なぜ既定で無効かを理解する
  - シミュレーションの前に、PX4の資料から予見できなかったかを考察する
- **位置づけ**: 任意の間章で、前提はフェーズ5。リポジトリ全体のゴールとは無理にそろえない。
  - 寄り道なので、フェーズ5を含むほかのページからはリンクしない。
  - ほかの間章にも依存しない（実機の事情も、この間章の中で書く）。
- **題とファイル**: 仮に「間章: PX4の既定の設定を確かめる ― 傾きによる故障の検知を例に」（`docs/interlude_px4_defaults.md`）。完成後に見直す。
- **読む順番**: 下書きのうちは、READMEの「読む順番」に加えない（学習計画の6節の既存の決まり）。

## 2. 書き方の決まり

- 「不具合」の語を使わず、「想定と違う動き」と書く。誰の想定かを書き分ける。操縦者は「墜落したら止まる」と想定していたが、PX4は文書どおりに動いていた。
- 公式に由来する情報と、推定を書き分ける。推定は禁止しないが、推定だと分かる形で書く。とくに2節の自動のディスアームと着陸の検知は、「実験の結果」「公式の見解（文書・ソース）」「推定」の3つを、読者が区別できる形で書く（2026-11-22、ユーザー指示）。
- 作者は墜落の後、QGCでの止め方が分からず、PX4のシェルでディスアームした（2026-11-22、ユーザーの回答。導入の段落に書く）。
- PX4の文書（CC BY 4.0。`docs/en/contribute/licenses.md` の12行）を和訳して載せるときは、ページの末尾の出典に、ライセンスと訳した旨を書き、`LICENSE` の3節の第三者の一覧に足す。
- 導入では、作者が試して気づいた経緯を正直に書く。読者の追体験は勧めるが、必須にしない。

## 3. 構成（Q19）

| 節 | 中身 | 確かめ方 |
|---|---|---|
| 1. 導入 | 作者の経緯。想定と違う動きの説明 | ユーザーの画面（追体験の手順の見た目） |
| 2. 仕組み | 故障の検知（`FD_FAIL_R`・`_P`・`_TTRI`）。場面ごとの扱い（アームの前・離陸の直後・飛行中）。飛行の打ち切りの回路遮断器（`CBRK_FLIGHTTERM`）。自動のディスアーム | ソースと文書（4節） |
| 3. 逆さまで始める（対比） | `PX4_GZ_MODEL_POSE` でロールを180°にして起動し、アームを拒まれることを確かめる | 画面なしの起動 |
| 4. 今の値を確かめる | 次の3つの層を順に見る。(1) 今の機体の値（`param show`・QGCのパラメータの画面）、(2) 機体の設定のファイルの `param set-default`、(3) パラメータの一覧の定義の既定値。シミュレーションでは、変えた値が `parameters.bson` に残る | 画面なしの起動 |
| 5. 設定を変えて試す | `CBRK_FLIGHTTERM=0`（再起動が要る）。墜落の後にモーターが止まることを確かめ、元に戻す | 墜落そのものはユーザーの画面。止まることの表示は、故障の注入で墜落させて画面なしで確かめた（8-3節） |
| 6. なぜ既定で無効か | 公式の文の和訳と、打ち切りの働き。推定は書き分ける。代わりの手段（角度の調整・キルスイッチ）は説明だけ | 文書 |
| 7. 止める手段 | 主の手順は、QGCの Flight Status のドロップダウンの Emergency Stop（飛行中と判定されているときに出る。強制のディスアーム）。PX4のシェルの `commander disarm -f` は、同じ命令を送る代わりの手段として、注意書き程度に触れる。キルスイッチは文書の説明だけ（送信機を使わないため）（2026-11-22、ユーザー判断。QA表のQ11の決定を改めた） | QGCの文書とソース。表示はユーザーの画面 |
| 8. 予見できたかの考察 | この事例では `safety.md` の該当の節を読めば予見できた。フェーズ0〜5では、その節を読む機会がなかった。シミュレーションの前に調べる公式の文書の範囲を、理由とともに名指しする（網羅はしない） | 文書 |

8節で名指しする範囲の候補（Q9。中身はClaudeの判断に任された。変えるときはユーザーに提案する）:

- `config/safety.md` の全体（フェールセーフ・故障の検知・緊急のスイッチ・自動のディスアーム・アームの前提）
- `advanced_config/prearm_arm_disarm.md`
- `advanced_config/flight_termination.md`
- パラメータの一覧の「Circuit Breaker」「Failure Detector」の群
- 使う機体の設定のファイル

## 4. 確かめた事実（PX4 v1.17.0、`~/PX4-Autopilot`）

| 事実 | 出どころ |
|---|---|
| `FD_FAIL_R` の既定は60°（0で無効、最大180）。説明に、飛行中は `CBRK_FLIGHTTERM` が0なら打ち切り、離陸のときはそれに関係なくロックダウン（ディスアーム）と書かれている | `src/modules/commander/failure_detector/failure_detector_params.c` の45〜61行 |
| `FD_FAIL_R_TTRI` の既定は0.3秒 | 同じファイルの93行 |
| 傾きの故障は、アームの点検で「Attitude failure detected」として落ちる | `src/modules/commander/HealthAndArmingChecks/checks/failureDetectorCheck.cpp` の40〜68行 |
| 傾きの判定は、姿勢の制御が有効なモードのときだけ動く（ディスアームの状態で、アームの前に判定されるかは実験で確かめる） | `src/modules/commander/failure_detector/FailureDetector.cpp` の56行 |
| アームから `COM_LKDOWN_TKO`（既定3秒）と `COM_SPOOLUP_TIME`（既定1秒）を足した時間の間は、故障の検知でディスアーム。過ぎると、`CBRK_FLIGHTTERM` が121212なら警告だけ、それ以外なら打ち切り | `src/modules/commander/failsafe/failsafe.cpp` の620〜631行、`commander_params.c` の792〜805行と862行 |
| `CBRK_FLIGHTTERM` の既定は121212（打ち切りを無効）。変えたら再起動が要る | `src/lib/circuit_breaker/circuit_breaker_params.c` の72〜86行 |
| `COM_DISARM_LAND` の既定は2秒 | `src/modules/commander/commander_params.c` の227行 |
| `PX4_GZ_MODEL_POSE` は `x,y,z,roll,pitch,yaw` を受け取る | `ROMFS/px4fmu_common/init.d-posix/px4-rc.gzsim` の115〜128行 |
| 機体の設定のファイルが、故障の検知の値を上書きすることがある（例: gz用の8011番のオムニコプター〈`8011_gz_omnicopter` の117〜118行〉は `FD_FAIL_R`・`_P` を0）。x500（4001番）には上書きが無い | `ROMFS/px4fmu_common/init.d-posix/airframes/` |
| シミュレーションのパラメータは、インスタンスのフォルダの `parameters.bson` に保存され、次の起動に残る | `ROMFS/px4fmu_common/init.d-posix/rcS` の67〜80行 |
| 文書: 飛行中の故障の検知の対応は、既定で無効。離陸の間は、つねにディスアーム。Acroモードでは働かない | `docs/en/config/safety.md` の277〜304行、`docs/en/advanced_config/flight_termination.md` の62〜69行 |
| 文書: 既定で無効の理由として見つかったのは、ジオフェンスの節の「本質的に危険なため、`CBRK_FLIGHTTERM` で無効にしてある」の1文だけ | `docs/en/config/safety.md` の177行 |
| 公式の資料どうしの食い違い: パラメータの定義は、`CBRK_FLIGHTTERM` を121212にすると故障の検知とFMUの喪失による打ち切りを無効にし、「RCの喪失・データリンクの喪失・ジオフェンス・離陸の故障の検知には影響しない」と書く。上の177行（ジオフェンスの節）の文と食い違う。6節では、177行の文を「故障の検知による打ち切りが既定で無効な理由」として和訳せず、「故障の検知による打ち切りを直接の対象にした理由の文は、公式の文書に見つからない」と扱う（2026-11-22、セッションのレビューの指摘L5） | `src/lib/circuit_breaker/circuit_breaker_params.c` の74〜78行 |
| 文書: 飛行の打ち切りは、すべての制御を止め、出力をフェールセーフの値にする。再起動まで戻せず、回復の方法は無い。起きたら、すぐに電池を外す。キルの操作とは、再起動まで続く点が違う | `docs/en/advanced_config/flight_termination.md` の1〜34行 |
| 文書: Position modeと自動のモードでは、アームとディスアームのスイッチは飛行中に無視され、着陸を検知した後にだけ使える。飛行中にディスアームできるのは、Manual・Acro・Stabilized | `docs/en/config/safety.md` の368〜390行 |
| 文書: キルスイッチは、すべてのモーターの出力をすぐ止める（飛んでいれば落ちる）。既定では、5秒以内に戻せば再開し、過ぎるとディスアーム（`COM_KILL_DISARM`） | `docs/en/config/safety.md` の354〜366行 |
| 着陸の検知（マルチコプター）: 地面に着いたと判定する条件に「推力が低い」が含まれ、上昇の速さを制御するモード（Position mode等）では「降りる指令が出ている」も要る。着陸と判定されないと、`COM_DISARM_LAND` の自動のディスアームは働かない。逆さまの機体は上がろうとして推力を上げ続け、着陸と判定されなかった、というのは推定（未確認） | `src/modules/land_detector/MulticopterLandDetector.cpp` の159〜297行 |
| QGC v5.1.5: 飛行の状態の表示（Flight Status）のドロップダウンに、Arm・Disarm・Emergency Stop がある。Disarmは地上だけ。Emergency Stopは飛行中にディスアームする操作で、「機体は落ちる」と注意がある | QGCの文書 `docs/en/qgc-user-guide/fly_view/fly_view_toolbar.md`（タグ `v5.1.5`）の18〜34行。`fly_view.md`・`fly_tools.md` には記述が無い |
| QGC v5.1.5のソース: ディスアームの要求は、機体がアーム中で飛行中（PX4から受け取った状態）なら「EMERGENCY STOP」の確認になり、そうでなければ通常の「Disarm」になる。Emergency Stopは `MAV_CMD_COMPONENT_ARM_DISARM` を、強制の値 21196 を付けて送る（`commander disarm -f` と同じ強制のディスアーム）。表示の条件には、作りの上の選択肢 `guidedBarShowEmergencyStop`（`_hideEmergenyStop`）も含まれる。7節を書くときに、標準のQGCで表示されることを確かめて一言添える | QGCの `src/FlyView/GuidedActionsController.qml` の125・128・362〜368行、`src/Vehicle/Vehicle.cc` の2081〜2089行（タグ `v5.1.5`）。PX4側は `src/modules/commander/Commander.cpp` の962行で21196を強制として扱う |

## 5. これから確かめること

- [x] 3節: 逆さまで起動したときのアームの応答（2026-11-22、承認を得て画面なしで1回起動。インスタンス7・使い捨ての作業フォルダ・`GZ_PARTITION`。QGCなしのため作業フォルダで `NAV_DLL_ACT` を0にした。手順書の条件〈QGCをつなぐ〉とは違う）。結果は8-1節
- [x] 4節: `param show` の表示の形（同じ起動で確かめた。8-1節）。`parameters.bson` は作業フォルダにでき、`param save` の後の値が次の起動に残ることは8-3節で確かめた
- [x] 5節: `CBRK_FLIGHTTERM=0` で再起動したあと、墜落の後にモーターが止まること（2026-11-22、故障の注入で墜落させて確かめた。8-3節）
- [x] 2節: 墜落の後、着陸と判定されないことと、推力の指令が最大のままのこと（8-3節）
- [x] 7節: `commander disarm -f` の表示（8-1〜8-3節）
- [ ] 4節: `param show-for-airframe` の意味を、`param.cpp` の `do_show_for_airframe` で確かめる（8-2節）
- [x] 6節: 既定で無効の理由が、`safety.md` の177行のほかに公式の文書にあるかを読んだ（`safety.md` のフェールセーフ・故障の検知・緊急のスイッチ・アームとディスアームの節、`prearm_arm_disarm.md`、`flight_termination.md`）。理由を直接述べた文は177行だけ。打ち切りの重さ（戻せない・回復の方法が無い）は `flight_termination.md` にある（2026-11-22）
- [x] 7節: QGCに、空中でもモーターを止める操作があるかを確かめた。ある（Flight Statusのドロップダウンの Emergency Stop）。手順書に足すことをユーザーに提案する（2026-11-22）
- [ ] 7節: 墜落の後、QGCのFlight Statusが「Flying」のままで、ドロップダウンに Emergency Stop が出ること（ユーザーの画面）
- [ ] 墜落の追体験の手順（フェーズ5のワールドと操作）と見た目は、ユーザーの画面で確かめる

## 6. 読者に見せないアイデア（Q15）

- `FD_FAIL_R` を小さくし（例: 30°）、`CBRK_FLIGHTTERM=0` のまま激しい操作をすると、飛んでいる機体が打ち切られる（誤判定の危険を体験できる）。文書を膨らませないため、本文には載せない（2026-11-22、ユーザー判断）。

## 7. 案2（機体の諸元から設定する）の状態

- 間章「機体を定義する」を前提にした、新しい間章にする。機体の大きさ（推奨は小型）は、着手するときに決める。
- 目的は、新しい機体を開発するときに、模型とPX4の設定のどこを触るべきかを知ること。値は、推定や実験で決めたものを含めてよい。条件は、実際に試して安定して飛ぶこと。センサの部品は扱わない。
- 着手は案1の後。その前に、間章「機体を定義する」（下書き）を確かめ終える必要がある。

## 8. 確かめた結果（画面なしの起動）

### 8-1. 1回目（2026-11-22）: 逆さまで起動したとき

PX4 v1.17.0、x500（4001番）、`PX4_GZ_MODEL_POSE="0,0,0.3,3.14159,0,0"`。QGCなし（`NAV_DLL_ACT` を0）。Holdのまま。

| 観察 | 結果 |
|---|---|
| 姿勢（`listener vehicle_attitude`） | `Roll: -180.0 deg, Pitch: 0.0 deg` |
| 故障の検知（`listener vehicle_status`） | アームの前から `failure_detector_status: 1`（ロールの故障。`FAILURE_ROLL = 1`）。`pre_flight_checks_pass: False` |
| 起動の途中から | `WARN  [health_and_arming_checks] Preflight Fail: Attitude failure (roll)` が出る |
| `commander check` | `INFO  [commander] Preflight check: FAILED` |
| `commander arm` | `WARN  [health_and_arming_checks] Preflight Fail: Attitude failure (roll)` と `WARN  [commander] Arming denied: Resolve system health failures first`。アームされない（`arming_state: 1`） |
| `commander arm -f`（点検を飛ばす強制のアーム） | `Armed by internal command` の直後に `WARN  [failsafe] Failsafe activated` と `INFO  [commander] Disarmed by failsafe`。ディスアームの理由は14（`failsafe`。`src/lib/events/enums.json`）。離陸の直後の時間（`COM_LKDOWN_TKO` + `COM_SPOOLUP_TIME`）の扱い（`failsafe.cpp` の620〜624行）と合う |
| 着陸の検知（ディスアームの状態） | `landed: True`（ディスアームの間は、条件にかかわらず着陸の扱い。`!_armed`） |
| 値（`param show`） | `x   FD_FAIL_R [456,689] : 60` の形。記号は `x = used, + = saved, * = unsaved`。`FD_FAIL_P` 60、`CBRK_FLIGHTTERM` 121212、`COM_LKDOWN_TKO` 3.0000、`COM_DISARM_LAND` 2.0000（どれも定義の既定値のまま） |
| `param show-for-airframe` | 既定値から変わった値を、`param set-default` の形で表示した（`MAV_SYS_ID 8`・`NAV_DLL_ACT 0`・`UXRCE_DDS_KEY 8`）。ただし、8-2節で、変えた値が表示されない場合が見つかった。4節に使うかは、意味を確かめてから決める |
| 後片付け | PX4と `claude_d1` のGazeboを止め、どちらも残っていない。作業フォルダに `parameters.bson` ができた |

分かったこと: 逆さまの機体は、ふつうのアームを拒まれる（公式の文書のとおり）。点検を飛ばしても、離陸の直後の時間のうちに、フェールセーフでディスアームされる。

メモ: `msg/versioned/VehicleStatus.msg` の `ARM_DISARM_REASON_*` の番号は、0〜5は `enums.json` と同じだが、6番以降が1つずれる（メッセージにある6の `SAFETY_BUTTON` が `enums.json` に無いため。例: メッセージでは11が故障の検知、`enums.json` では10）。`enums.json` の13（`rc_button`）と14（`failsafe`）はメッセージに無い。`latest_disarming_reason` の読み方は、`enums.json` に合わせる（手順書に書くときに、もう一度確かめる）。

### 8-2. 2回目（2026-11-22）: 飛行中にモーターを止めて墜落させる（想定どおりに進まなかった）

承認を得て、画面なしで2回起動した（A: 既定、B: 同じ作業フォルダで再起動）。離陸のコマンドの後のHoldで、高さ約2.5mから `failure motor off -i 1` を送った。

| 観察 | 結果 |
|---|---|
| 故障の注入 | `INFO  [failure_detector] CMD_INJECT_FAILURE, motor 1 off`。`failure_detector_status` の `motor_stop_mask: 1` になったが、モーターの出力（`actuator_motors`）は4つとも約0.73のままで、姿勢も水平のまま（墜落しなかった）。`Stopping motors` の表示も無い |
| 原因（ソース） | 配分のモジュールは、`CA_FAILURE_MODE` が0（既定。Ignore）より大きいときだけ、故障の検知の `motor_stop_mask` でモーターを止める（`src/modules/control_allocator/ControlAllocator.cpp` の715〜726行、`module.yaml` の587〜597行）。ここでも、既定の値が想定と違った |
| `CBRK_FLIGHTTERM` を0にした値 | Aの終わりに `param set` で0にし、`param show` は `x * CBRK_FLIGHTTERM ... : 0`（`*` は未保存）。すぐに止めて起動し直したBでは、121212に戻っていた。先に変えた `NAV_DLL_ACT`・`SYS_FAILURE_EN` は残っていた（`importing from 'parameters.bson'`） |
| 原因（ソース） | パラメータは変えると自動で保存されるが、保存は300ms〜2秒遅れる（`src/lib/parameters/autosave.cpp` の60〜70行）。保存の前に止めたので、残らなかったと考えられる（推定）。確実に残すには `param save` を使う |
| `param show-for-airframe` | Bで `SYS_FAILURE_EN 1` は既定（0）から変わっていたのに、表示されなかった。「既定から変わった値をすべて出す」ものではない可能性がある（未確認。4節に使う前に、`param.cpp` の `do_show_for_airframe` を読む） |
| 着陸の検知（飛行中） | `landed: False`・`has_low_throttle: False`・`in_descend: False`（墜落していないので、墜落の後の観察にはならない） |
| 強制のディスアーム（飛行中、高さ約2.5m） | `INFO  [commander] Disarmed by internal command`。理由は3（`command_internal`）。出力は0に。そのあと機体は落ちたと考えられる（観察していない） |
| 後片付け | PX4とGazebo（`claude_d2`）は残っていない |

分かったこと: 4節の材料として、(1) `param show` の `*`（未保存）と、保存の遅れ、(2) 故障の注入も `CA_FAILURE_MODE` の既定で効かないこと、が得られた。墜落の後の観察は、やり直しが要る（再実行は、ユーザーの許可を得てから）。

やり直しの案: 作業フォルダで `CA_FAILURE_MODE=1` にし、前の2つのモーター（`failure motor off -i` の番号で1と3〈1から数える。`FailureInjector.cpp` の68行〉。間章「機体を定義する」の3-2節の番号〈0から数える〉ではモーター0と2で、前右と前左）を止めて、確実に傾かせる。`CBRK_FLIGHTTERM=0` の後に `param save` を実行してから止める。

### 8-3. 3回目（2026-11-22。2回目のやり直し）: 前の2つのモーターを止めて墜落させる

承認を得て、画面なしで2回起動した。作業フォルダで `CA_FAILURE_MODE=1`・`SYS_FAILURE_EN=1`・`NAV_DLL_ACT=0`。離陸のコマンドの後のHoldで、高さ約2.5mから `failure motor off -i 1` と `-i 3`（1から数える番号。3-2節の0から数える番号ではモーター0と2で、前右と前左）を送った。壁との衝突とは原因（モーターの停止）もモード（Position modeでなくHold）も違う。手順書では「墜落の後の振る舞いの観察」として扱う。

**A: 既定（`CBRK_FLIGHTTERM` 121212）**

| 観察（注入の後、約8秒おき） | 結果 |
|---|---|
| 注入の直後 | `WARN  [control_allocator] Stopping motors (1)`、続いて `(5)`。`actuator_motors` の添字0と2（3-2節のモーター0と2。注入の番号では1と3）の出力は `nan`（止めた） |
| 姿勢 | 約12秒後には `Roll: 179.9 deg`（逆さま）。そのあとも約180°のまま |
| 故障の検知 | `failure_detector_status: 17`（ロール1＋ESCの故障16。16は注入でESCが止まった扱いになったもの）。`fd_roll: True` |
| フェールセーフ | `Failsafe activated` の表示は無く、モードはHold（`nav_state: 4`）のまま、アームのまま（`arming_state: 2`）。ソースのとおり、飛行中の故障の検知は警告だけ |
| モーター | 残りの2つ（`actuator_motors` の添字1と3。3-2節のモーター1と3で、後ろの2つ）が回り続けた。出力は `1.00000`・`0.43679`・`0.01500` などと変わり続けた |
| 推力の指令（`vehicle_thrust_setpoint`） | `xyz: [0.00000, 0.00000, -1.00000]`（機体の上向きに最大）。逆さまなので、地面へ押しつける向きになる |
| 着陸の検知 | `landed: False`・`has_low_throttle: False`・`in_descend: False` のまま。`COM_DISARM_LAND` の自動のディスアームは働かない |
| 強制のディスアーム | `INFO  [commander] Disarmed by internal command`。出力は0に。そのあと `Preflight Fail: Attitude failure (roll)`（逆さまのまま） |

作者の観察（逆さまのままプロペラが止まらず、地面に向かって力を出し続け、強制のディスアームまで続いた）と同じ振る舞いになった。提案2の推定（推力を上げ続け、着陸と判定されない）は、この実験で裏づけられた（ただし、壁の衝突ではなく、モーターの停止で墜落させた実験）。

**B: `CBRK_FLIGHTTERM=0`（Aの終わりに `param set` と `param save`。`param show` が `x + CBRK_FLIGHTTERM ... : 0`〈`+` は保存済み〉になり、再起動の後も0だった）**

| 観察 | 結果 |
|---|---|
| 注入の後 | Aと同じく `Stopping motors (5)` |
| 打ち切り | `WARN  [failsafe] Failsafe activated`、続いて `Preflight Fail: Flight termination active`。モードは `nav_state: 13`（打ち切り） |
| モーター | 約9秒後の観察では、残りの2つも `0.00000`（止まった） |
| 姿勢 | `Roll: -180.0 deg`（逆さまに落ちた） |
| アームの状態 | `arming_state: 2`（アームのまま）。打ち切りはディスアームではなく、出力をフェールセーフの値にする（文書のとおり）。最後に `commander disarm -f` でディスアームした |
| 故障の検知 | 打ち切りの後は `failure_detector_status: 16` で、ロールの印が消えた。打ち切りで姿勢の制御が無効になると、故障の検知がロール・ピッチの印を消すため（`FailureDetector.cpp` の56〜68行）。打ち切りのきっかけは、ロール・ピッチ・高さ・外部のどれか（`fd_critical_failure`。`failureDetectorCheck.cpp` の97〜99行）で、ESCの故障16は含まれない。今回はロールがきっかけと考えられる（印が消えたので、表示では直接は見えていない。推定） |
| 後片付け | PX4とGazebo（`claude_d3`）は残っていない |

まとめ: 既定では、逆さまになってもモーターは回り続け、推力の指令は最大のまま、着陸とも判定されない。`CBRK_FLIGHTTERM=0` では、飛行の打ち切りで出力が0になる。ただし、打ち切りの後もアームの状態は変わらない。
