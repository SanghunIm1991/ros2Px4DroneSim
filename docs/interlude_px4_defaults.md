# 間章: PX4の既定の設定を確かめる ― 故障の検知と自動のディスアームを例に

[学習計画](learning_plan.md) の間章（任意・寄り道）。PX4には、数千のパラメータがあり、どれにも既定の値がある。既定の値は、多くの場合よく考えられているが、使う人が「当然こう動くだろう」と思っている動きと、いつも同じとは限らない。この章では、筆者がシミュレーションで出会った想定と違う動き（墜落して逆さまになった機体のプロペラが、止まらずに回り続けた）を例に、その理由をPX4の文書とソースで調べ、パラメータで直し、なぜその機能が既定で無効なのかを考え、最後に「シミュレーションの前に、資料から予見できなかったか」を振り返る。

- 想定環境: [環境構築](setup_px4_gazebo.md) を終えたWSL2のUbuntu 24.04
- 前提: [フェーズ5](phase5_collision_prevention.md)（壁のワールド、QGCの仮想ジョイスティック、Position mode、PX4のシェルでの `param set` を使う）
- 所要の目安: 1コマ（読むだけなら40分。追体験と設定を変えて試す節を行うなら、シミュレーションの起動の時間が加わる）
- 必須の範囲: なし（任意の章）。1節の追体験と、5節の設定を変えて試す手順は任意（表示の例と読み方だけでも読める）
- 前提（親プロジェクト）: なし

名前の手がかり: 既定は、英語の default〈指定しないときに使われる値〉の訳語である。

> **この章の位置づけ**: PX4の安全の機能の設定を勧める手順書ではない。既定の値を、思い込みでなく確かめる方法を、1つの例で練習する読み物である。PX4についての事実は、この教材で使うPX4 v1.17の公式の文書とソース（v1.17.0）に基づく。PX4の文書（CC BY 4.0）の文を訳して載せた箇所は、「公式の文書の訳」と書いて区別した（出典と、`LICENSE` の3節の第三者の一覧に記載した）。この章では、**公式の文書とソースに書かれていること**、**筆者が実験で確かめたこと**、**筆者の推定**を、本文の中で書き分ける。
>
> **期待する結果の出どころ**:
>
> - **画面なしで起動したPX4で確かめたもの**（2026-11-22は `gz_x500`、2026-11-27は4013番）: 2-3節・3節・4-1節・5-1節・5-2節・7-2節のT1の表示。ほかのシミュレーションと混ざらないように、インスタンスの番号・作業フォルダ等を変え、QGCをつながずに（そのために `NAV_DLL_ACT` を0にした）、PX4の外から送るコマンドで表示を取った。4-1節の手順の機体は `gz_x500_lidar_2d_walls` なので、`param show` の最後の行の使っているパラメータの数と、角括弧の中の番号は、機体によって変わりうる。2-3節・5-2節では、壁にぶつける代わりに、**故障の注入**（試験のために、わざとモーターなどの故障を起こすPX4の機能。`failure` のコマンド）で飛行中にモーターを2つ止めて墜落させ、モードはPosition modeではなくHold（離陸のコマンドの後のモード）だった。この章の手順（QGCをつなぎ、Position modeで壁にぶつける）とは、起動の仕方も、墜落のさせ方も違う。5-1節〜5-3節の、起動し直しても値が残ることと、元に戻す `param set` の表示、次の起動で `+` が消えることは、2026-11-27に、同じ方法で、この章と同じ機体の設定の番号（4013番。ワールドは壁の無い既定のもの）で確かめた。
> - **PX4 v1.17.0のファイルで確かめたもの**: 4-2節の `grep` の表示。
> - **想定したもの**: 1節・5節・7節のGazeboとQGCの画面の様子（筆者の観察、PX4のソース、QGroundControl v5.1.5の文書とソースから想定した）。
> - **筆者の環境で観察したもの**: 1節の導入の経緯（フェーズ5の9節の課題1で、壁にぶつけたとき）。
> - **実行ごとに変わる部分**: 時刻（`timestamp`）、姿勢の向き（`Yaw`）、モーターの出力と推力の細かな値、`param show` の角括弧の中の番号（パラメータの通し番号。この章では読まない）。

この章で使うターミナルは、次のとおりである。

| ターミナル | 動かすもの | 仮想環境 `~/px4-venv` |
|---|---|---|
| T1 | PX4のシミュレーションとPX4のシェル | 使う |
| T2 | QGroundControl | 使わない |
| T5 | 機体の設定のファイルを探すコマンド（4-2節だけ） | 使わない |

ターミナルの番号は、[READMEの「ターミナルの番号」](../README.md#ターミナルの番号)のとおり、T1〜T4がどの手順書でも同じプログラムで、T5以降がそのページの作業用である。この章では、Agent（T3）と中継（T4）を使わないので、T3とT4は開かない。打つコマンドの前に `pxh> ` を付けて書くが、`pxh>` はPX4のシェルのプロンプトなので打たない。

## 0. 学習目標と完了条件

この章を読み終えたら、次ができる状態を目指す。

1. 墜落して逆さまになった機体のプロペラが、既定の設定では止まらない理由を、故障の検知・飛行の打ち切りの回路遮断器・着陸の検知の3つで説明できる（2節）。
2. 同じ故障の検知が、アームの前・アームの直後・飛行中で、違う扱いになることを説明できる（2節・3節）。
3. 今の機体で効いているパラメータの値を、PX4のシェルで確かめ、それが機体の設定のファイルの上書きか、定義の既定値かをたどれる（4節）。
4. パラメータを変えて、墜落の後にモーターが止まるようにでき、元に戻せる（5節）。
5. その機能が既定で無効な理由について、公式の文書に書かれていることと、書かれていないことを区別して説明できる（6節）。
6. 墜落した機体を、QGCから止められる（7節）。
7. シミュレーションの前に、どの公式の文書を読めば、この動きを予見できたかを説明できる（8節）。

**完了条件**: 10節の4つの問いに、答えを見ずに答えられる。

## 1. 想定と違う動き

### 1-1. 筆者が出会ったこと

[フェーズ5](phase5_collision_prevention.md) の9節の課題1では、衝突防止を無効にしたまま（`CP_DIST` が−1）、Position modeで機体を壁に向かって飛ばし、ぶつかることを確かめる。筆者がこの課題を試したとき、機体は壁にぶつかって、逆さまに地面へ落ちた。ここまでは予想どおりだった。

予想と違ったのは、その後である。逆さまになった機体のプロペラは、止まらずに回り続け、地面に向かって機体を押しつけていた。筆者は「墜落したら、モーターは止まるもの」と思い込んでいた。QGCの画面で止める方法も分からず、PX4のシェルで強制的にディスアームして、ようやく止まった。

これは、PX4の誤りだろうか。この章で調べると分かるとおり、PX4は、公式の文書とソースのとおりに動いていた。想定と違ったのは、筆者の想定のほうである。この章では、この動きを「想定と違う動き」と呼び、誰の想定とどう違ったのかを、順にほどいていく。

### 1-2. 追体験する（任意）

同じ動きを、自分の画面で見ることを勧める。必須ではない（表示の例と読み方だけで、2節以降は読める）。フェーズ5の8節で `CP_DIST` を−1に戻していれば、衝突防止は無効のままである。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl gz_x500_lidar_2d_walls

# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage
```

1. T1に `pxh>` が出たら、衝突防止が無効なことを確かめる（`pxh> param show CP_DIST`）。値が−1でなければ、`pxh> param set CP_DIST -1` にする。
2. QGCで、[フェーズ5](phase5_collision_prevention.md) の5節と同じく仮想ジョイスティックを表示する。[フェーズ1](phase1_first_flight.md) の5-1節と同じく離陸させ、止まったら、上の帯の飛行モードの表示（**Hold**）を押して **Position** を選ぶ（フェーズ5の6-1節と同じ）。
3. 右の操縦桿を上へいっぱいに倒し、前（東）の壁1に向かって飛ばし続ける。

**期待する結果**（想定。筆者の観察とソースから）: 機体は壁1にぶつかって傾き、逆さまに落ちる。落ちた後も、Gazeboの画面でプロペラが回り続け、機体は動かない。QGCの上の帯の飛行の状態の表示は、地上にいるのに **Flying** のままである。

止めるには、QGCの上の帯の飛行の状態の表示（**Flying**）を押し、出てきた一覧から **Emergency Stop** を選んで、確認のボタンを押し続ける（理由と詳しい手順は7節）。止めたら、T1のPX4のシミュレーションを Ctrl+C で止める（逆さまのままでは、次の飛行ができない。理由は3節）。

## 2. 仕組み: 故障の検知と、3つの場面

### 2-1. 故障の検知

PX4には、機体の異常を見張る部品がある。**故障の検知**（Failure Detector）は、`commander`（PX4の状態を管理するモジュール）の中にあり、機体の傾きが大きすぎないか、モーターやESC（モーターの速さを制御する部品）に異常が無いか、などを見張る。

この章の主役は、傾きの見張りである。ソース（`failure_detector_params.c`）と公式の文書（Safety の Failure Detector の節）によると、次の2つのパラメータで決まる。

| パラメータ | 既定値 | 意味 |
|---|---|---|
| `FD_FAIL_R` | 60 | ロール（左右の傾き）の限界（°）。0で、この見張りを無効にする |
| `FD_FAIL_P` | 60 | ピッチ（前後の傾き）の限界（°） |
| `FD_FAIL_R_TTRI`・`FD_FAIL_P_TTRI` | 0.3 | 限界を超えた状態が、何秒続いたら故障とみなすか |

傾きが60°を超えた状態が0.3秒続くと、故障の検知は「姿勢の故障」の印を立てる。逆さま（ロール180°）は、もちろん限界を超えている。ただし、この見張りは、機体が宙返りすることを想定したモード（Acro等）では働かない（公式の文書）。ソースでは、姿勢の制御が有効なモードのときだけ見張る作りになっている（`FailureDetector.cpp`）。

### 2-2. 印が立った後の扱いは、場面で違う

印が立った後、PX4が何をするかは、場面で違う。ソース（`failsafe.cpp` と `failureDetectorCheck.cpp`）と公式の文書から、次の3つに分けられる。

| 場面 | 扱い | 決めているもの |
|---|---|---|
| アームの前 | アームの点検で落ち、アームを拒む | 故障の検知の点検 |
| アームの直後（既定では約4秒の間） | ディスアームする（公式の文書は、これをロックダウンと呼ぶ） | `COM_SPOOLUP_TIME`（既定1秒）と `COM_LKDOWN_TKO`（既定3秒）の和 |
| それより後（飛行中） | `CBRK_FLIGHTTERM` が既定の121212なら、**警告だけ**。0なら、**飛行の打ち切り** | `CBRK_FLIGHTTERM` |

2行目は、離陸の直後にひっくり返った機体を止めるためのものである。公式の文書は、離陸の間のこの扱いを、`CBRK_FLIGHTTERM` に関係なく、つねに有効と書いている。ソースでは、時間はアームした時刻から数える。

3行目の **飛行の打ち切り**（Flight termination）は、すべての制御を止め、出力をフェイルセーフの値（あらかじめパラメータで決めておく、出力の値。モーターなら止める値）にする動作である（6節）。ここでの「フェイルセーフの値」は出力の値のことで、[フェーズ0](phase0_drone_px4.md) の9-2節のフェイルセーフ（異常のときに、Return等へ切り替える動作）とは別の意味である。`CBRK_FLIGHTTERM` は、この打ち切りを止めておくための **回路遮断器**（circuit breaker）のパラメータである。回路遮断器は、PX4で「安全のための仕組みを、わざと無効にしておく」ためのパラメータの名前の付け方で、決められた特別な値（ここでは121212）を入れると、その仕組みが無効になる。既定値が121212なので、**既定では、飛行中に機体がひっくり返っても、故障の検知は警告するだけで、モーターを止めない**。これが、1節の「想定と違う動き」の1つめの理由である。

### 2-3. 自動のディスアームが働かなかった理由

PX4には、着陸したら自動でディスアームする機能もある（`COM_DISARM_LAND`。既定では、着陸を検知してから2秒）。逆さまに落ちた機体は、地面にいるのに、なぜこれでも止まらなかったのか。

ソース（`MulticopterLandDetector.cpp`）によると、マルチコプターの **着陸の検知**（Land Detector）は、「地面に着いた」と判定する条件に、**推力の指令が低いこと** を含む。さらに、Position modeのように上昇の速さを制御するモードでは、**降りる指令が出ていること** も条件になる。

筆者の実験（画面なしの起動。壁ではなく、故障の注入でモーターを止めて墜落させ、モードはHold）では、逆さまに落ちた後の値は次のとおりだった。

```text
pxh> listener vehicle_thrust_setpoint
    xyz: [0.00000, 0.00000, -1.00000]
pxh> listener vehicle_land_detected
    landed: False
    in_descend: False
    has_low_throttle: False
```

（抜粋。どちらも、出力のうち関係する行だけを載せた。）

`xyz` の3つめは、機体から見た上下の推力の指令で、負が上向きである。−1は、上向きに最大を意味する。機体は「元の高さへ戻ろう」として推力を最大にしていると考えられる（筆者の推定）。逆さまなので、その推力は地面へ押しつける向きになる。推力が低くないので、`has_low_throttle` は False で、着陸とは判定されない（`landed: False`）。着陸と判定されないので、`COM_DISARM_LAND` の自動のディスアームも働かない。これが、2つめの理由である。

この2つをまとめると、次のようになる。

| 筆者の想定 | 実際のPX4（公式の文書・ソース・筆者の実験） |
|---|---|
| ひっくり返ったら、PX4がモーターを止める | 飛行中のひっくり返りは、既定では警告だけ（2-2節） |
| 地面に落ちたら、着陸とみなして止まる | 推力が最大のままなので、着陸と判定されない（2-3節） |

なお、壁にぶつけたPosition modeでも同じ判定になるかは、条件（推力が低いこと）が同じなので、同じ結果になると筆者は推定している（Position modeで墜落させた後の値は、画面なしでは確かめていない）。

## 3. 対比: 逆さまで始めたらアームできるか

2-2節の表の1行目と2行目を、自分で確かめる。機体を最初から逆さまに置いて起動し、アームを試す。PX4は、起動のときの機体の位置と向きを、環境変数 `PX4_GZ_MODEL_POSE` で受け取る（`x,y,z,ロール,ピッチ,ヨー` の6つ。角はラジアン。起動のスクリプト `px4-rc.gzsim`）。ロールにπ（3.14159）を入れると、逆さまになる。

この節では、壁の無いワールドの機体（`gz_x500`）を使う。1-2節で起動していたら、T1を Ctrl+C で止めておく。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

PX4_GZ_MODEL_POSE="0,0,0.3,3.14159,0,0" make px4_sitl gz_x500

# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage
```

QGCがつながってから、T1で、機体の姿勢と、アームの点検の結果を見る。

```text
pxh> listener vehicle_attitude

pxh> commander arm
```

**期待する結果**（抜粋。`Yaw` と `timestamp` は実行ごとに変わる）:

```text
pxh> listener vehicle_attitude
    q: [-0.00004, 0.74305, -0.66924, -0.00000] (Roll: -180.0 deg, Pitch: 0.0 deg, Yaw: -84.0 deg)
pxh> commander arm
WARN  [health_and_arming_checks] Preflight Fail: Attitude failure (roll)
WARN  [commander] Arming denied: Resolve system health failures first
```

ロールは−180°（逆さま）である。アームは拒まれ、理由は「姿勢の故障（ロール）」である。起動の途中から、T1には `Preflight Fail: Attitude failure (roll)` が繰り返し出ている。QGCの飛行の状態の表示も、飛べない状態（**Not Ready**）になる（想定）。2-2節の表の1行目のとおりである。

では、点検を飛ばす強制のアーム（`-f`）なら、どうなるか。

```text
pxh> commander arm -f
```

**期待する結果**:

```text
INFO  [commander] Armed by internal command
WARN  [failsafe] Failsafe activated
INFO  [commander] Disarmed by failsafe
```

アームした直後に、フェイルセーフでディスアームされた。2-2節の表の2行目（アームの直後の約4秒の間は、姿勢の故障でディスアームする）のとおりである。点検を飛ばしても、逆さまのままでは、モーターを回し続けられない。

逆さまで地上にいる機体と、飛行中に逆さまになった機体とで扱いが違うのは、PX4が「アームの前と直後」と「飛行中」を分けているからである（公式の文書とソース）。分けた理由は、文書に書かれていない。筆者は、地上の機体を止めても危険は無いが、飛行中の機体のモーターを止めると機体は必ず落ちるからだ、と考える（推定）。この考えは、6-2節で、既定の理由を推定するときにも使う。

確かめたら、T1を Ctrl+C で止める。`PX4_GZ_MODEL_POSE` は、そのコマンドの行だけで効くので、次に起動するときは、ふつうの向きに戻る。

## 4. 今の値を確かめる

2節の既定値は、公式の文書とソースに書かれた **定義の既定値** である。しかし、自分の機体で今効いている値が、それと同じとは限らない。PX4のパラメータの値は、次の3つの層で決まる。

| 層 | 中身 | 確かめ方 |
|---|---|---|
| ① 今の機体の値 | 実際に効いている値。`param set` やQGCで変えた値は保存され、起動し直しても残る。ただし、使う機体の設定の番号（パラメータ `SYS_AUTOSTART`。`gz_x500_lidar_2d_walls` は4013番、`gz_x500` は4001番）が前回と違うと、その番号・校正・飛行モードの割り当てなどを除いて、既定に戻る（起動のスクリプト `rcS`） | PX4のシェルの `param show`、QGCのパラメータの画面 |
| ② 機体の設定のファイル | 機体ごとに、定義の既定値を上書きする（`param set-default`） | 機体の設定のファイル（`ROMFS/px4fmu_common/init.d-posix/airframes/` 等） |
| ③ 定義の既定値 | ソースのパラメータの定義に書かれた値 | 公式の文書のパラメータの一覧（Parameter Reference） |

①が②と③で決まる、という順番なので、確かめるときは①から見て、気になる値があれば②、③とたどる。

### 4-1. ① 今の機体の値

フェーズ5の機体で起動して、T1で見る。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl gz_x500_lidar_2d_walls
```

```text
pxh> param show CBRK_FLIGHTTERM

pxh> param show FD_FAIL_R

pxh> param show COM_DISARM_LAND
```

**期待する結果**（`param show` を3回打った表示を続けて載せた。角括弧の中の番号は実行ごとに変わる）:

```text
pxh> param show CBRK_FLIGHTTERM
Symbols: x = used, + = saved, * = unsaved
x   CBRK_FLIGHTTERM [232,448] : 121212

 1003/1920 parameters used.
pxh> param show FD_FAIL_R
Symbols: x = used, + = saved, * = unsaved
x   FD_FAIL_R [456,689] : 60

 1003/1920 parameters used.
pxh> param show COM_DISARM_LAND
Symbols: x = used, + = saved, * = unsaved
x   COM_DISARM_LAND [256,472] : 2.0000

 1003/1920 parameters used.
```

行の先頭の記号は、1行目の凡例のとおりである。`x` は、そのパラメータをどこかのモジュールが使っていること、`+` は、既定（②の上書きを含む）と違う値が保存されていること、`*` は、値を変えたが、まだ保存されていないことを示す。`+` も `*` も無ければ、①の値は、②か③の既定のままである。3つとも既定のまま（121212・60・2）で、2節の表の値と合う。

なお、3節で別の機体の設定（`gz_x500`。4001番）で起動したので、フェーズ5で `CP_DIST` を戻し忘れていたとしても、今は既定（−1）に戻っている。PX4は、機体の設定の番号（`SYS_AUTOSTART`）が前回と違うと、その番号・校正・飛行モードの割り当てなどを除いて、パラメータを既定に戻すからである（`rcS`）。逆に、番号が同じかぎり、模型やワールドが違っても、変えた値は残り続ける。

QGCでも、**Q** のアイコン → **Vehicle Configuration** → **Parameters** で、パラメータを名前で探して、値を見られる（フェーズ5の4節）。

### 4-2. ② 機体の設定のファイル

フェーズ5の機体（`gz_x500_lidar_2d_walls`）は、4013番の機体の設定を使い、それは4001番（x500）を読み込み、さらにマルチコプターの共通の設定（`rc.mc_defaults`）を読み込む（それぞれのファイルの中の `. ${R}etc/...` の行が、読み込む先を示す）。これらのファイルに、2節のパラメータの上書きがあるかを探す。

```bash
# T5
cd ~/PX4-Autopilot/ROMFS/px4fmu_common

grep -n "FD_FAIL\|CBRK_FLIGHTTERM\|COM_LKDOWN\|COM_DISARM_LAND" init.d-posix/airframes/4013_gz_x500_lidar_2d init.d-posix/airframes/4001_gz_x500 init.d/rc.mc_defaults
```

**期待する結果**: 何も表示されない（上書きは無い）。

上書きは、ほかの機体の設定にはある。同じ `grep` の対象を、すべての機体の設定に広げると分かる。

```bash
# T5
grep -rn "FD_FAIL_R\|COM_DISARM_LAND" init.d/airframes init.d-posix/airframes
```

**期待する結果**（抜粋）:

```text
init.d/airframes/4016_holybro_px4vision:15:param set-default COM_DISARM_LAND 0.5
init.d/airframes/4061_atl_mantis_edu:31:param set-default COM_DISARM_LAND 0.1
init.d-posix/airframes/8011_gz_omnicopter:118:param set-default FD_FAIL_R 0
```

実機の製品（Holybro PX4 Vision、ATL Mantis EDU）の設定は、着陸の後に自動でディスアームするまでの時間を短くしている。シミュレーションのオムニコプター（どの向きにも推力を出せる機体）の設定は、傾きの見張りを無効にしている（どの向きでも飛べる機体には、傾きの限界が意味を持たないためと考えられる。筆者の推定）。同じ名前のパラメータでも、機体によって既定が違う。

### 4-3. ③ 定義の既定値

定義の既定値と意味は、公式の文書のパラメータの一覧（[Parameter Reference](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/advanced_config/parameter_reference.md)。v1.17）で、名前を探して読む。各パラメータの説明には、値の範囲、単位、再起動が要るか（Reboot required）も書かれている。`CBRK_FLIGHTTERM` は、再起動が要る。

## 5. 設定を変えて試す（任意）

2-2節の表の3行目のとおり、`CBRK_FLIGHTTERM` を0にすれば、飛行中にひっくり返ったとき、飛行の打ち切りでモーターが止まるはずである。1-2節の追体験と同じ手順で、確かめる。

### 5-1. 変えて、起動し直す

4-1節の起動のまま、T1で変える。

```text
pxh> param set CBRK_FLIGHTTERM 0

pxh> param show CBRK_FLIGHTTERM
```

**期待する結果**:

```text
pxh> param set CBRK_FLIGHTTERM 0
  CBRK_FLIGHTTERM: curr: 121212 -> new: 0
pxh> param show CBRK_FLIGHTTERM
Symbols: x = used, + = saved, * = unsaved
x * CBRK_FLIGHTTERM [232,448] : 0

 1003/1920 parameters used.
```

変えた直後は `*`（未保存）である。PX4は、変えた値を自動で保存するが、保存は少し遅れて行われる（ソース `autosave.cpp`。0.3〜2秒）。数秒たってから、もう一度 `param show CBRK_FLIGHTTERM` を打ち、`+`（保存済み）に変わったことを確かめる。すぐに保存したいときは、`pxh> param save` を打つ。筆者は、`*` のままPX4を止めてしまい、起動し直したら121212に戻っていたことがある。

`CBRK_FLIGHTTERM` は、再起動が要るパラメータである（4-3節）。T1を Ctrl+C で止めて、同じコマンドで起動し直す。

```bash
# T1
make px4_sitl gz_x500_lidar_2d_walls
```

起動したら、`pxh> param show CBRK_FLIGHTTERM` で、0のままで、`+` が付いていることを確かめる。

### 5-2. もう一度ぶつける

QGCを閉じていたら、起動する。開いたままなら、起動し直したPX4に自動でつながる。

```bash
# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage
```

1-2節の2と3の操作（仮想ジョイスティックの表示 → 離陸 → Position → 壁1へ）を、もう一度行う。

**期待する結果**（画面の様子は想定。T1の表示は、画面なしの実験〈モーターを止めて墜落させた〉で確かめたもので、抜粋）: 機体が壁にぶつかって大きく傾くと、T1に次が表示され、プロペラが止まる。機体は落ちて、そのまま止まる（傾いた時点で打ち切られるので、逆さまになるとは限らない）。

```text
WARN  [failsafe] Failsafe activated
WARN  [health_and_arming_checks] Preflight Fail: Flight termination active
```

ひっくり返った直後に、飛行の打ち切りが働いた。T1で `pxh> listener actuator_motors` を打つと、`control` の値が0になっている。

ただし、筆者の実験では、打ち切りの後も、機体は **アームのまま** だった（`listener vehicle_status` の `arming_state` が2）。公式の文書のとおり、打ち切りは、ディスアームではなく、出力をフェイルセーフの値にする動作だからである。打ち切りから元に戻す方法は無く、再起動が要る（6節）。T1を Ctrl+C で止める。

### 5-3. 元に戻す

この教材のほかの章は、既定の設定を前提にしている。必ず元に戻す。

```bash
# T1
make px4_sitl gz_x500_lidar_2d_walls
```

```text
pxh> param set CBRK_FLIGHTTERM 121212

pxh> param save
```

**期待する結果**（`param save` は何も表示しない）:

```text
pxh> param set CBRK_FLIGHTTERM 121212
+ CBRK_FLIGHTTERM: curr: 0 -> new: 121212
```

行の先頭の `+` は、変える前の値が、既定と違って保存されていたことを示す（フェーズ5の8節と同じ）。戻した直後に `pxh> param show CBRK_FLIGHTTERM` を打つと、既定と同じ値になったので、`+` はもう付いていない。戻したら、T1を Ctrl+C で止める。次に起動したとき、`param show CBRK_FLIGHTTERM` に `+` が付いていなければ、既定に戻っている。

## 6. なぜ既定で無効なのか

5節のとおり、`CBRK_FLIGHTTERM` を0にすれば、墜落の後にモーターは止まる。では、なぜPX4は、これを既定で無効にしているのか。ここでは、公式の文書に書かれていることと、書かれていないこと（筆者の推定）を分ける。

### 6-1. 公式の文書に書かれていること

公式の文書の Flight Termination Configuration のページは、飛行の打ち切りを、次のように説明している（公式の文書の訳。筆者が訳した）。

> 飛行の打ち切りのフェイルセーフの動作は、制御を元に戻せない形で止め、PWMの出力を、パラメータで決めたフェイルセーフの値にする。
>
> 飛行の打ち切りから回復する方法は無い。作動した後は、できるだけ早く電池を外すべきである。機体を再び使うには、再起動（電源の入れ直し）が要る。

同じページは、打ち切りのフェイルセーフの値を、パラシュートを開く、着陸の脚を出す、エアバッグを膨らませる、といった安全の装置を動かすために使えると説明している。Safety のページの Failure Detector の節も、飛行中の故障の検知は、飛行の打ち切りを作動させるのに使え、それがパラシュートを開くなどの動作につながりうる、と説明し、続けて、飛行中に検知した故障への対応は既定で無効である（`CBRK_FLIGHTTERM` を0にすると有効になる）、と書いている。

つまり、公式の文書から読み取れる事実は、次の3つである。

1. 飛行の打ち切りは、元に戻せない、重い動作である。
2. 打ち切りは、パラシュート等の安全の装置と組み合わせることを想定して説明されている。
3. 飛行中の故障の検知による打ち切りは、既定で無効である。

一方で、「なぜ既定で無効にしたか」を、故障の検知による打ち切りについて直接述べた文は、筆者が調べた範囲（8-2節の範囲）では見つからなかった。Safety のページのジオフェンス（飛行できる範囲の囲い）の節に、「本質的に危険なため、この機能は `CBRK_FLIGHTTERM` で無効にしてある」という1文がある。ただし、パラメータの定義の説明は、`CBRK_FLIGHTTERM` は故障の検知などによる打ち切りを無効にし、ジオフェンスには影響しない、と書いていて、2つの記述は食い違う。そのため、この章では、この1文を、故障の検知についての理由としては扱わない。公式の資料どうしが食い違うこともあるので、食い違いに気づいたら、ソースや実験（5節）で確かめるのがよい。

### 6-2. 筆者の推定

ここからは、6-1節の事実と、3節・5節の実験から、筆者が推定したことである。公式の見解ではない。

- **誤った判定のときの損が大きい**: 打ち切りは、元に戻せず、モーターを止める。もし、強い風や激しい操作で、一時的に60°を超えて0.3秒続いただけなら、機体はまだ立て直せたかもしれない。打ち切りは、その機体を確実に落とす。3節の対比（地上の機体を止めても危険は無いが、飛行中の機体のモーターを止めると必ず落ちる）と同じ考え方である。
- **安全の装置が無い機体では、落ちることは変わらない**: 本当にひっくり返った機体なら、モーターを止めても止めなくても、落ちることは変わらない。打ち切りの価値は、パラシュート等の装置を動かせることにあり、装置の無い機体では、打ち切りの利点は小さい。
- **地上での危険は、別の手段で減らせる**: 墜落の後にプロペラが回り続けるのは危険だが、操縦者のキルスイッチ（実機の送信機）や、7節のQGCの Emergency Stop で止められる。

どれを選ぶかは、機体の用途（パラシュートを積むか、人の近くを飛ぶか、操縦者が常に止められるか）で決まる。`FD_FAIL_R`・`FD_FAIL_P` の角度を調整して、誤った判定を減らす方法もある。この章では、どれが正しいとは決めない。大事なのは、既定の値に、それぞれ理由と代償がある、と知って選ぶことである。

## 7. 止める手段

### 7-1. QGCの Emergency Stop

墜落した機体を止める手段として、まずQGCの **Emergency Stop** を使う。QGroundControl v5.1.5の文書（Fly View の Toolbar のページ）によると、上の帯の飛行の状態の表示（Flight Status）を押して出る一覧に、次の3つがある。

| 操作 | 文書の説明（要約） |
|---|---|
| **Arm** | アームする |
| **Disarm** | ディスアームする。地上にいるときだけ使える |
| **Emergency Stop** | 飛行中にディスアームする。緊急のときだけ使い、機体は墜落する |

手順は、次のとおりである（想定。QGCの文書とソースから）。

1. 上の帯の飛行の状態の表示（墜落の後は **Flying** になっている）を押す。
2. 一覧から **Emergency Stop** を選ぶ。
3. 「すべてのモーターを止める。機体が飛んでいれば墜落する」という意味の警告とともに、確認のボタンが出る。確認のボタンを、受け付けられるまで押し続ける（QGCの安全に関わる操作の確認の仕方）。

**期待する結果**（想定。PX4のソースの、ディスアームの理由の名前から）: プロペラが止まり、T1に `INFO  [commander] Disarmed by external command` が出る（7-2節の、シェルから止めたときの表示と比べる）。

なぜ地上にいるのに **Disarm** ではなく **Emergency Stop** なのか。QGCのソース（`GuidedActionsController.qml`）では、機体が飛行中と判定されているとき、ディスアームの要求を Emergency Stop に切り替える。飛行中かどうかは、PX4から受け取った状態で決まる。2-3節のとおり、PX4は墜落した機体を「着陸した」と判定していないので、QGCも **Flying** と表示し、Emergency Stop を出す（筆者の推定。QGCのソースとPX4の実験の結果を組み合わせたもの）。

筆者が1節で止め方に迷ったのは、この操作が、QGCの文書の飛行の画面の主なページ（Fly View・Fly Tools）ではなく、上の帯（Toolbar）のページにだけ書かれていたためでもある。

> **注意**: Emergency Stop は、空中で使えば機体を落とす操作である。墜落した機体を止めるため以外には使わない。

### 7-2. PX4のシェルから止める

QGCが使えないときは、T1のPX4のシェルで、強制のディスアームができる。

```text
pxh> commander disarm -f
```

**期待する結果**:

```text
INFO  [commander] Disarmed by internal command
```

PX4のシェルから送った命令なので、ディスアームの理由は「internal command」（PX4の中からの命令）と表示される。QGCの Emergency Stop も、同じ強制のディスアームの命令（MAVLinkの `MAV_CMD_COMPONENT_ARM_DISARM` に、強制を表す値21196を付けたもの）を送っている（QGCのソース `Vehicle.cc`、PX4のソース `Commander.cpp`）。どちらで止めても、PX4の中では同じことが起きる。違うのは、命令がPX4の外（QGC）から来たか、中（シェル）から来たかで、表示される理由（external command と internal command）だけである。

### 7-3. 実機のキルスイッチ（説明だけ）

実機では、送信機のスイッチを **キルスイッチ** に割り当てるのが一般的である。公式の文書（Safety の Kill Switch の節）によると、キルスイッチは、すべてのモーターの出力をすぐに止める（飛んでいれば機体は落ちる）。既定では、5秒以内にスイッチを戻せばモーターは再び回り、5秒を過ぎると自動でディスアームする（`COM_KILL_DISARM`）。この教材は送信機を使わないので、試さない。

なお、公式の文書（Safety の Arm/Disarm Switch の節）によると、送信機のアームとディスアームのスイッチは、Position modeや自動のモードでは、飛行中には無視され、着陸を検知した後にだけ働く。2-3節のとおり、墜落した機体は着陸と判定されないので、このスイッチでは止められない可能性がある（筆者の推定。実機でも、シミュレーションでも確かめていない）。キルスイッチは、モードや着陸の判定によらず働く。

## 8. 予見できたか

### 8-1. この事例の振り返り

1節の動きは、シミュレーションの前に、資料から予見できただろうか。答えは「半分はできた」である。公式の文書の Safety のページの Failure Detector の節に、次のことがはっきり書かれている（2-2節・6-1節）。

- 飛行中に検知した故障への対応は、既定で無効である。
- 離陸の間だけは、`CBRK_FLIGHTTERM` に関係なく、つねにディスアームする。

この2行を読んでいれば、「飛行中に逆さまになっても、既定では、PX4が故障の検知でモーターを止めることはない」と予見できた。一方で、同じページの Auto-Disarming Timeouts の節には、着陸を検知したら自動でディスアームする（`COM_DISARM_LAND`）と書かれている。文書だけを読むと、「地面に落ちれば、着陸として2秒後に止まる」と考えるのが自然である。それも働かないことは、着陸の検知の条件（2-3節）をソースで読むか、実験しないと予見できなかった。

それでも予見できなかったのは、この教材のフェーズ0〜5で、このページを読む機会が無かったからである。フェーズ5は、衝突防止のパラメータ（`CP_DIST` 等）だけを調べて、壁に向かって飛ばした。衝突防止が無効のときに壁にぶつかったら何が起きるか、つまり **衝突の後の振る舞い** を決めるパラメータは、衝突防止とは別の場所（安全の設定）にあった。

筆者がこの章を書くために実験したときにも、同じことが起きた。5節の表示を取るための画面なしの実験で、故障の注入（`failure motor off`）でモーターを止めようとしたが、最初は止まらなかった。モーターを止める処理を決めるパラメータ `CA_FAILURE_MODE` の既定が「無視する」（0）だったためである。使う機能の周りのパラメータの既定を、先に確かめていれば防げた。

### 8-2. シミュレーションの前に調べる範囲

PX4の文書は膨大で、すべてを読むことはできない。この章で見た種類の動き（既定で無効な安全の機能、条件つきで働く機能）を予見するには、少なくとも次の範囲を、試す前に読むとよい（PX4 v1.17の文書）。網羅ではなく、この章の事例から見つかった範囲である。

| 文書の範囲 | 読む理由 |
|---|---|
| [Safety Configuration (Failsafes)](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/config/safety.md) の全体（各フェイルセーフ、Failure Detector、Emergency Switches、Arming/Disarming Settings） | 異常のときにPX4が何をするか、その既定と、既定で無効な機能が、まとめて書かれている。この章の事実の多くは、このページにあった |
| [Arm, Disarm, Prearm Configuration](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/advanced_config/prearm_arm_disarm.md) | いつアームでき、いつ自動でディスアームするか（`COM_DISARM_LAND` 等） |
| [Flight Termination Configuration](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/advanced_config/flight_termination.md) | 打ち切りが何をし、何をしないか（元に戻せない・ディスアームではない） |
| [Parameter Reference](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/advanced_config/parameter_reference.md) の Circuit Breaker と Failure Detector の群 | 回路遮断器（既定で安全の仕組みを無効にしているもの）と、故障の検知の値の一覧 |
| 使う機体の設定のファイル（4-2節） | 機体ごとの上書き。文書の既定値と違うことがある |

試す機能（この章では衝突防止、筆者の実験では故障の注入）のページを読むときは、その機能の周り、つまり「その機能が働かなかったとき・働いた後に何が起きるか」を決める設定も、上の範囲から探す。読んでも分からないところや、資料どうしが食い違うところ（6-1節）は、シミュレーションで確かめる。

## 9. まとめ

- 既定の設定では、飛行中にひっくり返った機体のモーターは止まらない。故障の検知は警告するだけで（`CBRK_FLIGHTTERM` が121212）、推力が最大のままなので着陸とも判定されない（`COM_DISARM_LAND` も働かない）。
- 同じ故障の検知でも、アームの前はアームを拒み、アームの直後の約4秒はディスアームし、飛行中は既定で警告だけ、と場面で扱いが違う。
- 今の値は、`param show`（①）→ 機体の設定のファイル（②）→ パラメータの一覧（③）の順にたどる。`+` は保存済み、`*` は未保存。
- `CBRK_FLIGHTTERM` を0にすると、飛行の打ち切りでモーターが止まる。ただし、打ち切りは元に戻せず、ディスアームでもない。試したら元に戻す。
- 既定で無効な理由は、公式の文書には直接書かれていない。打ち切りが重い動作であることは書かれている。
- 墜落した機体は、QGCの Emergency Stop（またはPX4のシェルの `commander disarm -f`）で止める。
- PX4が故障の検知でモーターを止めないことは、Safety のページを読めば予見できた。着陸の検知が働かないことは、ソースや実験で確かめるまで分からなかった。試す機能の「周り」の設定を、試す前に読み、分からないところは確かめる。

## 10. 確かめの問い

1. 既定の設定で、飛行中に機体が逆さまになったとき、モーターが止まらない理由を、2つ挙げよ。
2. 逆さまに置いた機体で `commander arm -f`（点検を飛ばすアーム）をすると、すぐにディスアームされた。どのパラメータで決まる、どの場面の扱いか。
3. `param show` の行の先頭の `*` と `+` は、それぞれ何を示すか。`param set` の直後にPX4を止めると、何が起きうるか。
4. `CBRK_FLIGHTTERM` を0にすることの利点と代償を、公式の文書に書かれていることと、推定とに分けて述べよ。

<details>
<summary>答えの例</summary>

1. (1) 飛行中の故障の検知は、`CBRK_FLIGHTTERM` が既定の121212なので、警告するだけで飛行の打ち切りをしない（2-2節）。(2) 逆さまの機体は推力の指令が最大のままなので、着陸の検知が「推力が低い」の条件を満たさず、着陸と判定されない。そのため `COM_DISARM_LAND` の自動のディスアームも働かない（2-3節）。
2. アームの直後の扱い。`COM_SPOOLUP_TIME`（既定1秒）と `COM_LKDOWN_TKO`（既定3秒）の和の間は、姿勢の故障でディスアームする（2-2節・3節）。
3. `*` は値を変えたが未保存、`+` は既定と違う値が保存済み。保存は少し遅れて行われるので、`*` のまま止めると、変えた値が残らず、次の起動で元の値に戻ることがある。確実に残すには `param save` を使う（5-1節）。
4. 利点: 飛行中にひっくり返ったとき、打ち切りでモーターが止まり、パラシュート等の安全の装置を動かせる（公式の文書）。代償: 打ち切りは元に戻せず、再起動が要り、ディスアームでもない（公式の文書）。誤った判定のときに、立て直せたかもしれない機体を確実に落とす（推定）。安全の装置の無い機体では、利点が小さい（推定）（6節）。

</details>

## 11. 用語集

「元の語」は、用語の元になった英語と、その短い意味である（覚える手がかりにする）。

| 用語 | 説明 | 節 |
|---|---|---|
| 故障の検知 | 元の語: Failure Detector〈故障を見つけるもの〉。`commander` の中で、傾きやESCの異常を見張る部品 | 2-1 |
| 飛行の打ち切り | 元の語: Flight termination〈飛行の終了〉。すべての制御を止め、出力をフェイルセーフの値にする動作。元に戻せない | 2-2・6-1 |
| 回路遮断器 | 元の語: circuit breaker〈電気の回路を切るブレーカー〉。安全の仕組みを、決まった値を入れて無効にしておくためのパラメータ。名前は `CBRK_` で始まる | 2-2 |
| 着陸の検知 | 元の語: Land Detector〈着陸を見つけるもの〉。推力・動き・降りる指令などから、機体が地面にいるかを判定する部品 | 2-3 |
| ロックダウン | 元の語: lockdown〈封鎖〉。アームの直後に姿勢の故障を検知したときに、ディスアームすること（パラメータ `COM_LKDOWN_TKO` の名前に残る） | 2-2 |
| 機体の設定のファイル | 機体ごとに、パラメータの既定を上書きする起動のスクリプト（airframe） | 4-2 |
| Emergency Stop | 元の語: emergency〈緊急〉＋ stop〈止める〉。QGCの、飛行中でもディスアームする操作 | 7-1 |
| キルスイッチ | 元の語: kill switch〈止めるスイッチ〉。送信機のスイッチで、すべてのモーターの出力をすぐに止める | 7-3 |

## 次へ

この章は任意で、ここで一段落する。ほかの章へ進むときは、5-3節のとおり `CBRK_FLIGHTTERM` を既定（121212）に戻してあることを、`pxh> param show CBRK_FLIGHTTERM` で確かめる。

## 出典

この章の技術的な記述は、次の文書とファイルを読んで、自分の言葉でまとめたもの（6-1節の訳だけは、公式の文書の文を訳したもの）。

- PX4 User Guide（v1.17。[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)、Dronecode/PX4）: [Safety Configuration (Failsafes)](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/config/safety.md)（Failure Detector・Attitude Trigger・Kill Switch・Arm/Disarm Switch・Auto-Disarming Timeouts・ジオフェンスの節の `CBRK_FLIGHTTERM` の記述）、[Flight Termination Configuration](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/advanced_config/flight_termination.md)、[Arm, Disarm, Prearm Configuration](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/advanced_config/prearm_arm_disarm.md)、[Parameter Reference](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/advanced_config/parameter_reference.md)。6-1節の引用は、Flight Termination Configuration の冒頭と Overview の節の文を、筆者が日本語に訳したもの（改変あり）
- PX4 v1.17のソース（作成に使った環境に取得したv1.17.0）: [`src/modules/commander/failure_detector/failure_detector_params.c`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/commander/failure_detector/failure_detector_params.c) と `FailureDetector.cpp`（傾きの限界と時間、見張るモード）、[`src/modules/commander/failsafe/failsafe.cpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/commander/failsafe/failsafe.cpp)（場面ごとの扱い）、`src/modules/commander/HealthAndArmingChecks/checks/failureDetectorCheck.cpp`（アームの点検）、`src/modules/commander/commander_params.c`（`COM_LKDOWN_TKO`・`COM_SPOOLUP_TIME`・`COM_DISARM_LAND`）、[`src/lib/circuit_breaker/circuit_breaker_params.c`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/lib/circuit_breaker/circuit_breaker_params.c)（`CBRK_FLIGHTTERM` の既定と影響の範囲）、[`src/modules/land_detector/MulticopterLandDetector.cpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/land_detector/MulticopterLandDetector.cpp)（着陸の判定の条件）、`src/lib/parameters/autosave.cpp`（保存の遅れ）、`src/modules/control_allocator/module.yaml`（`CA_FAILURE_MODE`）、`src/modules/commander/Commander.cpp`（強制のディスアームの値）、[`ROMFS/px4fmu_common/init.d-posix/px4-rc.gzsim`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/ROMFS/px4fmu_common/init.d-posix/px4-rc.gzsim)（`PX4_GZ_MODEL_POSE`）、[`ROMFS/px4fmu_common/init.d-posix/rcS`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/ROMFS/px4fmu_common/init.d-posix/rcS)（機体の設定の番号が前回と違うときに、パラメータを既定に戻すこと）、`ROMFS/px4fmu_common/init.d-posix/airframes/` と `ROMFS/px4fmu_common/init.d/airframes/` の機体の設定
- QGroundControl v5.1.5（文書と、ソースのうち `src/FlyView/GuidedActionsController.qml`・`src/Vehicle/Vehicle.cc`）: [Fly View Toolbar](https://github.com/mavlink/qgroundcontrol/blob/v5.1.5/docs/en/qgc-user-guide/fly_view/fly_view_toolbar.md)（Flight Status の一覧の Arm・Disarm・Emergency Stop）、[Fly Tools](https://github.com/mavlink/qgroundcontrol/blob/v5.1.5/docs/en/qgc-user-guide/fly_view/fly_tools.md)（確認のボタンを押し続けること）。QGroundControlは Apache License 2.0 / GPLv3（QGroundControlの開発者）
- 「期待する結果」のPX4のシェルの表示と、4-2節の `grep` が表示する機体の設定の行: PX4-Autopilot（Copyright (c) 2012 - 2023, PX4 Development Team, BSD 3-Clause License。[全文](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/LICENSE)）の表示とファイル
