# 実際の表示で確かめる項目の一覧

手順書の「期待する結果」のうち、PX4のソースや公式の文書から想定して書き、まだ実際に動かして確かめていない表示の一覧。手順書を使って練習するときに確かめ、違っていたら手順書を直して、この一覧から消す（直した経緯は [`docs/qa_log.md`](qa_log.md) に残す）。どの表示が想定かは、各手順書の冒頭の注記「期待する結果の出どころ」にも書いてある。

確かめた表示は、ユーザー名・ホスト名・日時・PCの実測値（処理時間・速さ等）を伏せてから手順書に載せる。

## フェーズ1（[`docs/phase1_first_flight.md`](phase1_first_flight.md)）

2026-10-31に作成。起動・QGCでの離陸と着陸のT1の表示、QGCの起動した直後の表示、Gazeboの右クリックのメニューは確かめた。

| 節 | 確かめること | 今の記述（想定） | 想定の根拠 |
|---|---|---|---|
| 3節 | Gazeboの機体の右クリックのメニューに、**Move to** と **Remove** があるか | どちらもある | Gazebo Harmonicの文書 |
| 5-1節 | 離陸のときのQGCの表示の変化 | 機体の状態が **Armed** → **Flying**、飛行モードが **Takeoff** → **Hold** | QGC v5.1.5の文書、PX4のソース |
| 5-1節 | 10 ftのまま離陸したとき、止まる高さ | QGCの高さの表示で約10 ft（約3m） | QGC v5.1.5の文書 |
| 5-2節 | 地図をクリックしたときの一覧の項目名 | **Go to location** がある | QGC v5.1.5の文書 |
| 5-2節 | 移動の間のQGCの飛行モードの表示 | **Hold** のまま | PX4のソース（`VEHICLE_CMD_DO_REPOSITION` はHoldへの切り替え） |
| 5-2節 | 止まった後の `commander status` の最初の4行 | `Armed`・`navigation mode: Hold`・`user intended navigation mode: Hold`・`in failsafe: no` | PX4のソース、6-1節の実際の表示 |
| 5-3節 | 着陸のときのQGCの表示の変化 | 飛行モードが **Land**、機体の状態が **Landing** → **Ready** | QGC v5.1.5の文書 |
| 6-2節 | `commander takeoff` の後の動きと、T1の表示 | 2.5mまで離陸する。T1には5-1節と同じ行が出る | PX4のソース（`MIS_TAKEOFF_ALT`） |
| 6-2節 | `listener vehicle_local_position` の表示の形 | `TOPIC: vehicle_local_position` の後に、`timestamp`・`x`・`y`・`z` 等が並び、`z` は約−2.5 | PX4のソース |
| 6-3節 | `commander mode auto:rtl` の後の動き | 飛行モードが **Return** になり、10m以内の地点からなら少し上がってから、離陸した地点へ戻って着陸する | PX4のソース（`rtl.cpp`・`rtl_params.c`） |
| 6-4節 | 帰還の後の `commander status` | `Disarmed`・`navigation mode: Hold` | PX4のソース（`UserModeIntention.cpp`） |
| 6-5節 | `commander land` の後の動きと、T1の表示 | 飛行モードが **Land** になり、その場に着陸する。T1に `Landing detected` と `Disarmed by landing` | PX4のソース、5-3節の実際の表示 |
| 6-3節 | `commander` とだけ打ったときの使い方の説明 | `mode` に渡せる名前（`auto:loiter`・`auto:land`・`auto:takeoff`・`auto:rtl`・`posctl`・`offboard` 等）が並ぶ | PX4のソース（`Commander.cpp` の使い方の一覧） |
| 8節 | 課題2: QGCの飛行モードの一覧から **Land** を選べるか | 選べて、左のボタンと同じことが起きる | QGC v5.1.5の文書 |

## フェーズ2（[`docs/phase2_ros2_observe.md`](phase2_ros2_observe.md)）

2026-10-31に下書き。2節（AgentがROS 2 Jazzyの環境でビルドできること、`px4_msgs` のビルド、`ros2 interface show` の表示）は、同じ日に確かめて差し替えた。3節以降の表示（AgentとPX4がつながったときの表示、`ros2 topic list`・`info -v`・`echo`、QoSが合わないときの警告、機体を動かしたときの位置の値の変化）は想定で、まだ動かしていない。親プロジェクトのフェーズ1の1-3節で設定する `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` のままでPX4のトピックが見えるかも、確かめていない（学習計画のフェーズ2の予備の実験の残り）。動かしたら、表示を差し替え、この節を、確かめた項目と残りの項目の表に直す。

## フェーズ3-0（[`docs/phase3_0_node_qos.md`](phase3_0_node_qos.md)）とフェーズ3（[`docs/phase3_offboard.md`](phase3_offboard.md)）

2026-10-31に下書き。サンプルのコードは、ROS 2のリンタ（`ament_flake8`）とPythonの文法の点検だけを通した。`px4_msgs` が無い環境で書いたので、ビルドと起動はしていない。すべての表示（`ros2 pkg create`・`colcon build`・ノードのログ・`ros2 node info`・`ros2 topic info -v`・QoSが合わないときの警告・`ros2 topic hz`）と、機体の動き（Offboardへの切り替え、四角形の飛行、着陸の後にノードが自分で終わること）が想定である。とくに、次を確かめる。

| ページ・節 | 確かめること | 今の記述（想定） |
|---|---|---|
| フェーズ3-0の4節 | `ros2 topic info -v` の受け手の履歴と深さの表示 | `History (Depth): UNKNOWN` |
| フェーズ3-0の5節 | QoSを `10` にしたときの、受け手の側の警告の文言 | `New publisher discovered on topic ..., offering incompatible QoS. ... Last incompatible policy: RELIABILITY` |
| フェーズ3の5節 | 切り替えとアームが1回の指示で通るか | 10回の合図の後の最初の指示で、Offboardになりアームする（通らなければ、1秒ごとに指示し直す） |
| フェーズ3の5節 | 飛行中にQGCのLandで止めたときの、ノードの動き | 「Offboardから別のモードに移った。終わる」と出して終わる |
| フェーズ3の5節 | 経由点に着いたとみなす距離（0.5m）で、すべての経由点を回れるか | 回れる |
| フェーズ3の5節 | 着陸の後に、ノードが `SystemExit` で終わるか | 「着陸してディスアームした。終わる」の後に終わる |
| フェーズ3の5節 | 飛行中にノードを Ctrl+C で止めたときのPX4の動き | 少しHoldした後、Returnで離陸した地点へ戻って着陸する（既定の設定と、送信機が無いこと。ソースの読み取りによる） |

## フェーズ4（[`docs/phase4_lidar.md`](phase4_lidar.md)）

2026-10-31に下書き。機体・センサ・ワールドの中身とGazeboのトピックの名前はPX4 v1.17のソースで、`parameter_bridge` の引数の書き方は使い方の表示で確かめたが、起動はしていない。すべての表示（T1の起動の表示、`gz topic -l`、`parameter_bridge` の表示、`ros2 topic list`・`hz`・`echo`、RViz2の表示、機体を動かしたときの変化）が想定である。とくに、次を確かめる（学習計画のフェーズ4の予備の実験を含む）。

| 節 | 確かめること | 今の記述（想定） |
|---|---|---|
| 3-2節 | `make px4_sitl gz_x500_lidar_2d_walls` で、壁のワールドとLiDAR付きの機体が現れるか | 現れる |
| 4節 | `gz topic` と `parameter_bridge` に `GZ_IP=127.0.0.1` が要るか（要らなければ、説明を減らす） | 要る（PX4の `make` がGazeboを `GZ_IP=127.0.0.1` で起動するため） |
| 4節・5節 | 専用のGPUが無いPCで、LiDARの値が出るか | 出る |
| 5-1節 | `parameter_bridge` の起動の表示の文言 | `Creating GZ->ROS Bridge: [... (gz.msgs.LaserScan) -> ... (sensor_msgs/msg/LaserScan)] (Lazy 0)` |
| 5-2節 | `header.frame_id` の値 | `link`（模型の `gz_frame_id`） |
| 5-2節 | `ros2 topic hz /scan` の値 | 約30 |
| 6-2節 | Fixed Frameを `link` にしたとき、TFが無くても点が表示されるか。警告の文言 | 表示される。`link` が見つからないという警告が出ることがある |
| 6-2節 | 原点の機体から、正面の壁が約4.4m先、左の壁が約4.5m先に見えるか | 見える |
| 7節 | 北へ約3mのGo to locationで、機首が北へ回るか（`MPC_YAW_MODE` が0、`NAV_ACC_RAD` が2m） | 北を向いてから進む。RViz2で、壁2が前に、壁1が右に移り、壁2が約1.4mまで近づく |
| 4節・5節 | ROS 2のパッケージの `gz`（T4）と `parameter_bridge` が、PX4が起動するGazebo（どちらもHarmonic）とつながるか（環境構築の4-4節の予告） | つながる |
| 4節・5節 | 画面なし（`HEADLESS=1`）で起動しても、LiDARの値が出るか（学習計画の予備の実験） | 出る（手順書には書いていない） |
| 5-2節 | `angle_min`・`angle_increment` の表示の桁 | float32の模型の値（±2.3561949729919434）と、その2倍を1079で割った値 |
| 5-2節 | RTFが100%より小さいとき、`ros2 topic hz` が30より小さくなるか | 小さくなる |
| 6-2節 | **Axes** の表示が、TFなしで固定フレームの原点に出るか | 出る |
| 6-2節 | 壁3の西の端が、右前の約11m先に数点出るか | 出ることがある |

## フェーズ5（[`docs/phase5_collision_prevention.md`](phase5_collision_prevention.md)）

2026-10-31に下書き。パラメータの名前・既定値・働きはPX4 v1.17のソースと文書で、仮想ジョイスティックの設定はQGC v5.1.5の文書と設定の定義で確かめたが、起動はしていない。すべての表示と機体の動きが想定である。とくに、次を確かめる。

| 節 | 確かめること | 今の記述（想定） |
|---|---|---|
| 4節 | `param set CP_DIST 2` の表示 | `  CP_DIST: curr: -1.0000 -> new: 2.0000` |
| 4節 | SITLで、変えたパラメータが起動し直しても残るか | 残る（`parameters.bson` に保存） |
| 4節 | QGCのパラメータの画面の場所 | **Q** → **Vehicle Configuration** → **Parameters** |
| 5節 | 仮想ジョイスティックの設定の場所と、表示の位置・割り当て | **Application Settings** → **General** → **Virtual Joystick**。左右に操縦桿、左がスロットルと向き（中央に戻る） |
| 6-1節 | 仮想ジョイスティックを表示していれば、Positionを選べるか | 選べる |
| 6-2節 | 止まる距離と止まり方（行き過ぎ・揺れ）。止まる距離が2mよりかなり遠くならないか | ゆっくり進み、2.5〜3m付近でほとんど進まなくなる（ソースからの見積もり）。2mより近づかない |
| 6-2節 | 左下・右下へ斜めに倒すと、壁から離れる向きに動けるか | 動ける |
| 6-3節 | 右上へ倒したとき、壁に沿って右へ動くか | 動く |
| 6-4節 | 真後ろへは動かないか | ほとんど動かない |
| 8節 | 戻すときの `param set` の表示の先頭の記号 | `+` |
| 2-2節 | 自動のモードの間に操縦桿を動かすと、Positionに切り替わるか（`COM_RC_OVERRIDE`） | 切り替わる |
| つまずきやすい点 | 距離の値が届かないときのT1の表示 | `No obstacle data, not moving...` |
| 9節 | 課題3: `CP_GUIDE_ANG` を0にしたときの、壁に沿う動き | 沿って動くが、速さが落ちる |
| 9節 | 課題2: 衝突防止が有効でも、Go to locationでは壁にぶつかるか | ぶつかる |

## フェーズ6（[`docs/phase6_replan.md`](phase6_replan.md)）

2026-10-31に下書き。Nav2を導入していない環境で書いた。サンプルのコードは、ROS 2のリンタ（`ament_flake8`）とPythonの文法の点検だけを通し、Nav2の設定の名前・既定値・アクションの型は `jazzy` のソースで確かめた。すべての表示と機体の動きが想定である（学習計画のフェーズ6の予備の実験を含む）。とくに、次を確かめる。

| 節 | 確かめること | 今の記述（想定） |
|---|---|---|
| 3-1節 | `ros-jazzy-navigation2` に、`planner_server`・コストマップ・NavFn・`nav2_msgs` が含まれるか | 含まれる |
| 5-2節 | `planner_server` を `ros2 run` で起動したときの表示 | `planner_server lifecycle node launched.` と、外からの切り替えを待つ旨 |
| 5-3節 | `ros2 lifecycle set` の表示と、有効化がTFを待って止まらないか | `Transitioning successful`。止まらない |
| 5-3節 | 「設定」の後・「有効化」の前に、計画器がアクションの頼みを断るか（ノードが離陸しないか） | 断る。T6に「計画器が頼みを断った」が1回出て、離陸しない |
| 2-4節・5-1節 | `override_timestamps_with_wall_time:=true` で、コストマップにLiDARの点が書き込まれるか | 書き込まれる |
| 2-1節 | 高さの範囲（0〜20m）で、地上と3mの高さの両方で壁が書き込まれるか | 書き込まれる |
| 2-4節 | ノードの時計（PCの時計）で付けたPX4への指令の時刻で、オフボード制御が動くか（フェーズ3と同じ前提） | 動く |
| 6-1節・6-2節 | 最初の経路が南の端を回り、角を回って壁3の南の面が地図の東の端まで書き込まれ、北の端を回る経路に引き直されるか（地図の東の端を20mにした前提） | そのとおり（壁の配置からの見込み） |
| 6-2節 | 経路の長さのログの値と、「引き直した」がその1回だけか | 約19m。次に約8m → 約45m |
| 6-2節 | 角を回った直後に、まだ見ていない壁3に近づきすぎないか（`LOOKAHEAD`=1.0m、`PLAN_PERIOD`=0.5秒） | 近づきすぎない |
| 6-2節 | 北回りの経路が、壁2と壁1の間の幅約2.5mの隙間を通るか | 通る |
| 6-2節 | 機体が壁にぶつからずに目的地に着き、着陸してノードが終わるか | 着く |
| 7節 | RViz2で、Map・Pathの表示と、経路が切り替わる様子が見えるか | 見える |
| 7節 | `ros2 lifecycle get` と `ros2 topic hz /plan` の表示 | `active [3]`、約2.0 |
| 4-1節 | Pythonの `tf2_ros` の依存の名前（`tf2_ros_py`）でビルドと実行ができるか | できる |
| 出どころの注記 | 確かめたNav2の設定の名前（層の全体の `min_obstacle_height`、`Result.NONE`・`error_msg`）が、導入される版でも同じか | 同じ |
| つまずきやすい点 | 時刻が合わないときのT5の警告の文言 | 未確認 |
