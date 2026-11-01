# フェーズ6-2: 起動して飛ばし、経路が変わるのを見る

[学習計画](learning_plan.md) のフェーズ6の後半の手順書で、この教材の最終ゴールに当たる。[フェーズ6-1](phase6_1_planner_node.md) で用意したNav2の計画器と自作のノード `replan_flight` を、シミュレーションと一緒に起動し、機体を飛ばす。障害物をまだ見ていない向きへの経路を計画して飛び始め、飛行中にLiDARが新しい壁を見つけると、経路が引き直されて、機体が壁を回り込むのを観察する。

- 想定環境: [フェーズ6-1](phase6_1_planner_node.md) を終えたWSL2のUbuntu 24.04
- 所要の目安: 1コマ
- 必須の範囲: 1〜4節（5節の課題は任意）
- 前提（親プロジェクト）: フェーズ6-1と同じ

> **この手順書の位置づけ**: フェーズ6-1の1-1節の図（最終ゴールの構成）の部品を、すべて同時に動かす。仕組み（コストマップ・計画器・アクション・ライフサイクル・TF・時刻）は、フェーズ6-1の2節で説明した。この手順書の中で仕組みを思い出したくなったら、フェーズ6-1の2節と、4-3節のクラス図に戻る。
>
> **期待する結果の出どころ**: （作成中）1-2節のT5の表示、1-3節の表示、3節の `ros2 lifecycle get` の表示は、計画器を単体で起動して（PX4とGazeboは使わず、静的なTFを与えて）確かめたもの（2026-11-01）。ほかの起動・飛行の表示と機体の動きは想定したもので、まだ動かしていない。実際に動かした表示に差し替える予定。

## 0. 学習目標と完了条件

この手順書を終えると、次のことができるようになる。

1. フェーズ6で使う部品（PX4・Agent・中継・計画器・自作のノード・RViz2）を、決まった順に起動できる（1節）。
2. 計画器を、ライフサイクルのコマンドで「設定」してから「有効化」できる（1-3節）。
3. 計画した経路をたどる目標をオフボード制御で機体に送り、飛行中に経路が引き直されるのを、ログとRViz2で確かめられる（2節・3節）。

**完了条件**: 障害物をまだ見ていない向きへの経路を計画して飛び始め、飛行中にLiDARが新しい壁を見つけると、経路が引き直され（RViz2で経路が変わるのが見える）、機体が壁にぶつからずに回り込んで目的地に着き、着陸する（2節・3節）。

この手順書では、8つのターミナルを使う。

| ターミナル | 動かすもの | 仮想環境 `~/px4-venv` |
|---|---|---|
| T1 | PX4のシミュレーション（`make px4_sitl gz_x500_lidar_2d_walls`） | 使う |
| T2 | QGroundControl | 使わない |
| T3 | Micro XRCE-DDS Agent | 使わない |
| T4 | `parameter_bridge`（LiDARの値の中継） | 使わない |
| T5 | `planner_server`（計画器） | 使わない |
| T6 | 自作のノード（フェーズ6-1でビルドしたもの）と、5節の課題でのビルドし直し | 使わない |
| T7 | RViz2 | 使わない |
| T8 | `ros2 lifecycle` のコマンド | 使わない |

ターミナルの番号は、[READMEの「ターミナルの番号」](../README.md#ターミナルの番号)のとおり、T1〜T4がどの手順書でも同じプログラムで、T5以降がそのページの作業用である。この手順書では、T1〜T8のすべてを使う。

## 1. 起動する

起動するものと、そのつながりは、フェーズ6-1の1-1節の図と1-3節の表のとおりである。

### 1-1. シミュレーションと中継

PX4のシミュレーションは、起動し直してから使う（位置の原点を、機体が現れた地点にするため。フェーズ3の5節）。T1からT4を、フェーズ4とフェーズ2と同じように起動する。T4の中継には、フェーズ6-1の2-4節の時刻の設定（`-p override_timestamps_with_wall_time:=true`）を足す。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl gz_x500_lidar_2d_walls

# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage

# T3
source ~/px4_ws/install/setup.bash

MicroXRCEAgent udp4 -p 8888

# T4
export GZ_IP=127.0.0.1

ros2 run ros_gz_bridge parameter_bridge \
  /world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan@sensor_msgs/msg/LaserScan[gz.msgs.LaserScan \
  --ros-args -p override_timestamps_with_wall_time:=true \
  -r /world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan:=/scan
```

**期待する結果**（想定）: T1からT4は、フェーズ4の3-2節・5-1節と、フェーズ2の3節と同じ表示になる。QGCが機体につながり、T1に `Ready for takeoff!` が出るまで待つ。

### 1-2. 計画器と自作のノード

T5で計画器を、T6で自作のノードを、T7でRViz2を起動する。

```bash
# T5
ros2 run nav2_planner planner_server --ros-args \
  --params-file ~/px4_ws/src/drone_offboard/config/planner.yaml

# T6
source ~/px4_ws/install/setup.bash

ros2 run drone_offboard replan_flight

# T7
rviz2
```

**期待する結果**（抜粋。T5は計画器を単体で起動して確かめた表示、T6は想定。時刻は実行ごとに変わる）:

```text
# T5（planner_server）
[INFO] [1793491285.908555022] [planner_server]:
	planner_server lifecycle node launched.
	Waiting on external lifecycle transitions to activate
	See https://design.ros2.org/articles/node_lifecycle.html for more information.

# T6（replan_flight）
[INFO] [<time>] [replan_flight]: 最初の経路を待つ（計画器の有効化を待つ）
```

T5の計画器は、起動しただけの「未設定」の状態で、外からの切り替えを待っている（フェーズ6-1の2-3節）。T6のノードは、最初の経路が届くまで、TFを送るだけで、機体には何も指示しない。

T7のRViz2で、次の順に設定する（フェーズ4の6-2節と同じ操作）。

1. **Fixed Frame** を `map` にする（今度は、地図の座標系を基準にする）。
2. **Add** の **By topic** で、`/scan` の **LaserScan** を足し、**Size (m)** を `0.05` にする。
3. **Add** の **By topic** で、`/global_costmap/costmap` の **Map** を足す（計画器を有効にした後で一覧に出る。出ていなければ、1-3節の後に足す）。
4. **Add** の **By topic** で、`/plan` の **Path** を足す（同じく、最初の計画の後で一覧に出る）。
5. **Add** の **By display type** で **TF** を足す（`map`・`base_link`・`link` の座標系の軸が表示される）。

### 1-3. 計画器を有効にする

T8で、計画器を「設定」してから「有効化」する（フェーズ6-1の2-3節）。

```bash
# T8
ros2 lifecycle set /planner_server configure

ros2 lifecycle set /planner_server activate
```

**期待する結果**（計画器を単体で起動して確かめた表示）:

```text
$ ros2 lifecycle set /planner_server configure
Transitioning successful

$ ros2 lifecycle set /planner_server activate
Transitioning successful
```

「設定」で、計画器は設定ファイルを読み込み、中の地図とアクションの受け口を作る。この時点では、まだ頼みを断るので、T5には `Action server is inactive. Rejecting the goal.` が頼まれるたびに（0.5秒ごとに）出て、T6には「計画器が頼みを断った（有効化を待つ）」が1回だけ出る（T5の行の文言は確かめたもので、繰り返し出ることとT6の表示は想定）。「有効化」で、地図がLiDARの値を受け取り始め、頼みを受け付けるようになる。最初の経路が届くと、T6のノードが飛行を始める（2節）。最初の計画のときに、T5に `[WARN] ... No planners specified in action call. Server will use only plugin GridBased  in server. This warning will appear once.` が1回出る。自作のノードが、どの計画器を使うか（`planner_id`）を指定せずに頼むためで、計画器は `GridBased` の1つだけなので、問題ない。

## 2. 飛ばして、経路が変わるのを見る

### 2-1. 何が起きる見込みか

目的地の (東8m, 北−6m) は、正面の壁1の向こう側にある。フェーズ4の3-1節の表のとおり、壁1の南の端には壁3が、壁3の東の端の近くには壁4がつながっていて、目的地は、壁1・壁3・壁4に三方を囲まれた場所にある。フェーズ6-1の3-2節の地図の範囲では、壁3が地図の東の端まで届いているので、地図の中で目的地へ入れるのは、北からだけである。

機体が現れた地点からは、LiDARで壁1の正面と左の壁2は見えるが、壁3の長い面は見えない（壁3の面は南と北を向いていて、北の面は壁1の陰にあり、南の面は壁1の南の端より南へ出ないと見えない）。まだ見ていない場所は「空いている」とみなすので、最初の計画では、目的地に近い南の端を回る経路が引かれる見込みである。

機体が壁1の西の面に沿って南へ進み、壁1の南の端の角を回ると、壁3の南の面が見え、地図の東の端までの壁3が一度に書き込まれる。南からは入れないことが分かるので、経路が引き直され、北の端を回る経路に変わる。北の端を回る経路は、壁2の東の端と壁1の間の、幅約2.5mの隙間を通る。

### 2-2. 飛ばす

1-3節で計画器を有効にすると、飛行が始まる。

**期待する結果**（T6の抜粋。想定。時刻と経路の長さは実行ごとに変わる）:

```text
[INFO] [<時刻>] [replan_flight]: 計画器が頼みを断った（有効化を待つ）
[INFO] [<時刻>] [replan_flight]: 経路を計画した: 長さ <約19> m
[INFO] [<時刻>] [replan_flight]: Offboardへの切り替えとアームを指示した
...
[INFO] [<時刻>] [replan_flight]: 経路を引き直した: 長さ <約8> m → <約45> m
...
[INFO] [<時刻>] [replan_flight]: 目的地に着いたので、着陸を指示した
[INFO] [<時刻>] [replan_flight]: 着陸してディスアームした。終わる
```

最初の経路が届くと、機体はアームして3mの高さまで上がり、最初の経路（南の端を回る経路）に沿って、南へ飛び始める。QGCの飛行モードの表示は **Offboard** になる。壁1の南の端の角を回ったところで、T6に「経路を引き直した」が出て、経路が北の端を回る長い経路に変わり、機体は向きを変えて北へ戻る。向きを変えている間は、LiDARの真後ろの90°が見えないが、地図には、それまでに見た壁が残っているので、経路はその壁を避ける。機体は、壁1の西の面に沿って北へ飛び、壁2と壁1の隙間を抜け、北の端を回って、壁1と壁4の間を南へ下り、目的地の上で着陸する。ディスアームすると、ノードは自分で終わる。

## 3. 観察する

飛行の間、T7のRViz2で、次を見る（1-2節で足した表示）。

| 表示 | 見えるもの |
|---|---|
| LaserScan（`/scan`） | LiDARの点。機体の向きに合わせて回る |
| Map（`/global_costmap/costmap`） | 地図。障害物の格子が濃い色、その周りの膨らませた範囲が段々に薄い色で表示される。飛ぶにつれて、見えた壁が書き加えられていく |
| Path（`/plan`） | 計画した経路の線。0.5秒ごとに計画し直されるので、少しずつ動く。南からは入れないと分かった時点で、大きく形が変わる |
| TF | `map` の原点（機体が現れた地点）と、機体（`base_link`）とLiDAR（`link`）の座標系の軸 |

**期待する結果**（想定）: 飛び始めは、地図に壁1の正面と左の壁2だけがあり、経路は壁1の南の端を回っている。機体が角を回ると、壁3が地図の東の端まで書き加えられ、すぐに、経路の線が、北の端を回る形に切り替わる。完了条件のとおり、経路が変わり、機体がぶつからずに回り込んで、目的地に着く。

T8で、計画器の状態と、経路のトピックも見られる。

```bash
# T8
ros2 lifecycle get /planner_server

ros2 topic hz /plan
```

**期待する結果**（抜粋。`ros2 lifecycle get` は計画器を単体で起動して確かめた表示、`ros2 topic hz` は想定。数は実行ごとに変わる）:

```text
$ ros2 lifecycle get /planner_server
active [3]

$ ros2 topic hz /plan
average rate: 2.000
```

`active` は、有効の状態である。`/plan` は、自作のノードが0.5秒ごとに計画を頼むので、毎秒約2回出る。

## 4. 止める

ノードは、着陸してディスアームすると自分で終わる。T8のコマンドを Ctrl+C で止め、T7のRViz2のウィンドウを閉じる。T5の計画器、T4の中継、T3のAgentを Ctrl+C で止める。T2のQGCのウィンドウを閉じ、T1のPX4のシミュレーションを Ctrl+C で止める。

途中で止めたいときは、QGCの **Land** で着陸させる。ノードは「Offboardから別のモードに移った。終わる」と出して終わる（フェーズ3の5節と同じ）。

## 5. 課題（任意）

1. 設定ファイル（フェーズ6-1の3-2節の `planner.yaml`）の地図の幅を `width: 40`（東へ25mまで）に広げると、壁3の東の端の外を回る道が地図に入る。角を回ったときに引き直される経路が、北回りになるか、東回りになるかを、壁3と壁4の配置（フェーズ4の3-1節）と、`obstacle_max_range` から予想し、確かめる。
2. `GOAL_ENU`（フェーズ6-1の4-2節）を (東−5m, 北8m)（壁2の向こう側）に変えて、壁2の東の端と壁1の間（幅約2.5m）を通る経路が引かれるか、西の端を大きく回る経路が引かれるかを予想し、確かめる。`robot_radius` と `inflation_radius` を変えると、どちらになるかが変わることも確かめる。
3. 設定ファイルの `track_unknown_space` を `true` に、`allow_unknown` を `false` に変えると、まだ見ていない場所を通る経路を引かなくなる。最初の計画がどうなるかを予想し、確かめる（設定ファイルを変えたら、下の段落のとおり、1節から起動し直す）。
4. `use_astar` を `false` にすると、NavFnは、A\*ではなく、出発点から全方向に同じように広げて調べる探し方（ダイクストラ法）を使う。経路の形と、計画にかかる時間（アクションの答えの `planning_time`）を比べる。
5. Nav2のライフサイクルの管理の部品 `lifecycle_manager`（パッケージ `nav2_lifecycle_manager`）を使って、1-3節の切り替えを自動にする。パラメータ `node_names` と `autostart` を調べる。さらに、T4〜T6をlaunchのファイルでまとめて起動する。この課題は、親プロジェクトの [フェーズ4](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase4_launch.md) の2節〜4節（launchのファイルの書き方）を前提にする。

ノード（`replan_flight.py`）を変える課題では、変えた後に、T6でビルドし直す（フェーズ6-1の4-4節と同じ）。

```bash
# T6
cd ~/px4_ws

colcon build --packages-select drone_offboard

source ~/px4_ws/install/setup.bash
```

設定ファイル（`planner.yaml`）は、T5で計画器を起動するときに `src` の下から直接読むので、ビルドし直さなくてよいが、計画器を起動し直す。どちらも、機体を着陸させ、すべてのターミナルを止めてから、1節から起動し直す。

## つまずきやすい点

- **T6が「最初の経路を待つ」のまま進まない**: 1-3節の有効化をしていない。T8で `ros2 lifecycle get /planner_server` を実行し、`active` かを確かめる。
- **有効化で止まる・失敗する（T5にTFのエラーが出る）**: 地図が、`map` → `base_link` のTFを見つけられていない。T6のノードが起動していて、T3のAgentがPX4とつながっているか（PX4の位置が届いているか）を確かめる。
- **RViz2の地図に壁が書き込まれない**: T4の中継に `override_timestamps_with_wall_time:=true` を付けたかを確かめる（フェーズ6-1の2-4節）。T5に、時刻が合わずにLiDARの値を捨てたという警告が出ていないかを見る。設定ファイル（フェーズ6-1の3-2節）の高さの範囲（`min_obstacle_height`・`max_obstacle_height`）も確かめる。
- **「経路が見つからない」が出続ける**: 機体のいる格子か、目的地の格子が、膨らませた範囲に入って通れなくなっている。`robot_radius` と `inflation_radius` を小さくするか、`tolerance` を大きくする。
- **目的地の近くで、着陸せずに浮いたままになる**: 計画器は、目的地の格子が通れないと、`tolerance`（0.5m）以内の近くの格子を代わりの終点にする。経路の終点が目的地から0.5m以上ずれると、ノードの「着いた」の判定（`REACHED_DIST`）に入らない。目的地を壁から離すか、`REACHED_DIST` を少し大きくする。
- **角を回った直後に、壁に近づきすぎる・ぶつかる**: 引き直される前の経路は、まだ見ていない壁3の中を通っている。目標の点がその上にある間に進みすぎると、壁に近づく。`LOOKAHEAD` を小さくする、`PLAN_PERIOD` を短くする、`inflation_radius` を大きくして角から離れて回らせる、のどれかを試す。

## 次へ

ここまでで、この教材の最終ゴール（障害物を見つけたら経路を計画し直して回避する）に着いた。Nav2のほかの部品と、フェーズ6の設定のうち変えて試してよいところは、[間章（Nav2）](interlude_nav2.md) にまとめた。学習計画（[`docs/learning_plan.md`](learning_plan.md)）に戻り、全体を振り返る。

## 出典

- 計画器の起動とライフサイクルの切り替え（`ros2 run nav2_planner planner_server`・`ros2 lifecycle`）: [Nav2](https://github.com/ros-navigation/navigation2)（`jazzy`、Apache License 2.0）のソース（`nav2_planner`）を読んで、自分の言葉でまとめたもの。設定ファイルとノードの出典は、フェーズ6-1の出典のとおり。
- 中継の時刻の付け替え（`override_timestamps_with_wall_time`）: [`ros_gz_bridge`](https://github.com/gazebosim/ros_gz/blob/jazzy/ros_gz_bridge/README.md)（`jazzy`、Apache License 2.0、Open Source Robotics Foundation）のREADMEを読んで、自分の言葉でまとめたもの。
- 壁の配置: フェーズ4の出典のとおり、PX4 v1.17に付属する模型のファイルを読んだもの。

