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

2026-10-31に下書き。すべての表示（Agentと `px4_msgs` のビルド、AgentとPX4がつながったときの表示、`ros2 topic list`・`info -v`・`echo`、QoSが合わないときの警告、機体を動かしたときの位置の値の変化）が想定で、まだ動かしていない。AgentがROS 2 Jazzyの環境でビルドでき、`~/.bashrc` の `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` のままでPX4のトピックが見えるかも、確かめていない（学習計画のフェーズ2の予備の実験に当たる）。動かしたら、表示を差し替え、この節を、確かめた項目と残りの項目の表に直す。
