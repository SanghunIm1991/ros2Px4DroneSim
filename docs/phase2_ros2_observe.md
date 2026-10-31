# フェーズ2: ROS 2から、機体の状態を見る

[学習計画](learning_plan.md) のフェーズ2の手順書。PX4とROS 2をつなぐ中継のプログラム（Micro XRCE-DDS Agent）と、PX4のトピックの型のパッケージ（`px4_msgs`）をビルドし、PX4のシミュレーションの機体の位置や状態を、ROS 2のコマンド（`ros2 topic`）で見る。PX4のトピックを受け取るときに要るQoSの指定と、値がNEDであることも、ここで実際に確かめる。プログラムは書かない。ここで作るワークスペースと、つなぎ方は、フェーズ3以降のすべての手順書で使う。

- 想定環境: [フェーズ1](phase1_first_flight.md) を終えたWSL2のUbuntu 24.04
- 所要の目安: 1〜2コマ（Agentのビルドに時間がかかる）
- 必須の範囲: 1〜7節（8節の課題は任意）
- 前提（親プロジェクト）: [フェーズ2](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase2_packages.md) の1-1節（ワークスペースの構成）・1-2節（ビルドと実行の流れ）・2-1節（ワークスペースを作る）・2-4節（ビルドする）・2-5節（環境に登録して実行する）

> **この手順書の位置づけ**: [フェーズ0](phase0_drone_px4.md) の7節（uXRCE-DDS）と8節（座標系）を、実際に動かして確かめる。ROS 2のワークスペースとビルドの基本は、上の親プロジェクトの節で学ぶ。
>
> **期待する結果の出どころ**: 2節（Agentと `px4_msgs` のビルド、型の表示）と、3節のT3（Agent）とT5（`ros2 topic list`）の表示、4節・5節の表示、6節の地面にいるときの表示は、実際に動かした表示（ROS 2 Jazzy、Agent v2.4.3、`px4_msgs` の `release/1.17`、PX4 v1.17.0）。3節のT1（PX4のシミュレーション）の表示と、6節の、飛ばしたときの値の変わり方は、PX4 v1.17のソースと設定のファイル、`px4_msgs` の型の定義、PX4とeProsimaの公式の文書から想定したもの。時刻・ID・位置の値は、実行ごとに変わる。ビルドの時間はPCによって変わるので `<time>` と書いた。

## 0. 学習目標と完了条件

この手順書を終えると、次のことができるようになる。

1. Micro XRCE-DDS Agentと `px4_msgs` を、ROS 2のワークスペースでビルドできる（2節）。
2. Agentを起動して、PX4のトピックをROS 2に出せる（3節）。
3. `ros2 topic list`・`ros2 topic info`・`ros2 topic echo` で、PX4のトピックの名前・型・QoS・値を見られる（4節）。
4. PX4のトピックの受け取りに、送る側に合わせたQoSが要る理由を説明できる（5節）。
5. 機体の位置の値がNEDであることを、機体を動かして確かめられる（6節）。

**完了条件**（すべて満たしたら完了）:

1. `ros2 topic list` に、`/fmu/out/` で始まるPX4のトピックが並ぶ（3節）。
2. `ros2 topic echo` で、`/fmu/out/vehicle_odometry` の値が表示される（4節）。
3. QGCで機体を離陸・移動させると、`ros2 topic echo` で見ている位置の値が変わり、上昇すると `z` が負に大きくなる（6節）。

## 1. 全体像

フェーズ0の4節の図のうち、「PX4（SITL）」「Micro XRCE-DDS Agent」「ROS 2のノードとツール」の3つを、ここでつなぐ。PX4の中のuXRCE-DDSのクライアントは、PX4の起動と一緒に動き始め、UDPの8888番のポートでAgentを待っている（環境構築の6節の `INFO  [uxrce_dds_client] init UDP agent IP:127.0.0.1, port:8888` の行）。Agentを起動すると、両者がつながり、PX4のトピックがROS 2のトピックとして見えるようになる。

この手順書では、4つのターミナルを使う。

| ターミナル | 動かすもの | 仮想環境 `~/px4-venv` |
|---|---|---|
| T1 | PX4のシミュレーション（`make px4_sitl gz_x500`） | 使う（環境構築・フェーズ1と同じ） |
| T2 | QGroundControl | 使わない |
| T3 | Micro XRCE-DDS Agent | 使わない |
| T5 | ビルドと `ros2` のコマンド | 使わない |

ターミナルの番号は、[READMEの「ターミナルの番号」](../README.md#ターミナルの番号)のとおり、T1〜T4がどの手順書でも同じプログラムで、T5以降がそのページの作業用である。この手順書では、LiDARの中継（T4）を使わないので、T4は開かない。

PX4専用の仮想環境は、PX4のビルドと起動のためのものである。環境構築の4-3節のとおり、仮想環境を有効にしたターミナルでは、ROS 2のビルドやコマンドを動かさない。T3とT5は、仮想環境を有効にしていない、新しいターミナルで開く。

## 2. Agentと `px4_msgs` をビルドする

### 2-1. ワークスペースを用意する

この教材のワークスペースは `~/px4_ws` にする（作り方と、`src`・`build`・`install` の役割は、親プロジェクトのフェーズ2の1-1節と2-1節。親プロジェクトの `~/ros2_ws` と、名前だけが違う）。

親プロジェクトの `~/ros2_ws` とは分ける。一般に、目的の違うプロジェクト（製品）ごとにワークスペースを分けると、使う依存の版をプロジェクトごとに決められ、ビルドや不具合の影響がほかのプロジェクトに及ばない。複数のプロジェクトで共通に使う部品は、その部品だけのワークスペースを作ってビルドし、その `setup.bash` を読み込んでから、各プロジェクトのワークスペースをビルドする形で共有できる（ワークスペースを重ねる、オーバーレイという仕組み）。

```bash
# T5
mkdir -p ~/px4_ws/src

cd ~/px4_ws/src
```

**期待する結果**: 何も表示されない。

### 2-2. Micro XRCE-DDS Agentを取得してビルドする

AgentはeProsima社のオープンソースのプログラムで、PX4の文書が示す版（ROS 2 Jazzyではv2.4.3）を取得する。PX4のクライアントはv2系なので、v3系のAgentとはつながらない。

```bash
git clone -b v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git

cd ~/px4_ws

colcon build --packages-select microxrcedds_agent
```

**期待する結果**（抜粋。`git clone` の進み具合の行と、ビルド中の `[Processing: ...]` の行は省いた。時間は実行ごとに変わる）:

```text
Cloning into 'Micro-XRCE-DDS-Agent'...
...
Note: switching to '73622810d984349b80bbac0ef55fc0b694d62222'.

You are in 'detached HEAD' state. You can look around, make experimental
...
Starting >>> microxrcedds_agent
--- stderr: microxrcedds_agent
Cloning into 'spdlog'...
Cloning into 'microxrcedds_client'...
HEAD is now at d44dc3f Release v2.4.3
HEAD is now at eb322062 Bump version to 1.9.2
Cloning into 'microcdr'...
HEAD is now at 3d1b177 Release v2.0.1
---
Finished <<< microxrcedds_agent [<time>]

Summary: 1 package finished [<time>]
  1 package had stderr output: microxrcedds_agent
```

最初の部分は `git clone` の表示である。`-b v2.4.3` は、ブランチではなく、版に付けた名前（タグ）なので、Gitは「detached HEAD」（どのブランチにもいない状態）の説明を出す。版を決めて取得したときの普通の表示で、誤りではない。

`microxrcedds_agent` は、Agentのパッケージの名前である（取得したフォルダの名前とは違う）。Agentのビルドは、必要なライブラリのうち、決まった版が見つからないものを、ビルドの途中でGitHubから取得して一緒にビルドする。そのため、時間がかかる。`--- stderr:` と `---` の間の行が、その取得の表示である。ROS 2 Jazzyの環境を読み込んだターミナル（`~/.bashrc` で `/opt/ros/jazzy/setup.bash` を読み込んでいる状態）でビルドすると、DDSのライブラリ（Fast DDS・Fast CDR）はROS 2に入っているものが見つかって使われ、この教材を作るときに確かめた環境で取得されたのは、ログの出力のライブラリ（spdlog）と、Micro XRCE-DDSのクライアントとデータの変換のライブラリ（`microxrcedds_client`・`microcdr`）だった。これらの表示は、エラーの出力（stderr）に出るので、最後に `1 package had stderr output` と書かれるが、`Finished` と `1 package finished` が出ていれば、ビルドは成功している。取得したライブラリも、ワークスペースの `install/` の中に入り、PCのほかの場所には入らない。PX4の文書には、Agentを `sudo make install` で `/usr/local` に入れる方法もあるが、この教材では、ほかのソフトウェアに影響しないように、ワークスペースの中でビルドする方法を使う。

### 2-3. `px4_msgs` を取得してビルドする

`px4_msgs` は、PX4のトピックの型（フェーズ0の7節）を定義したROS 2のパッケージである。使うPX4の版（v1.17）に合わせて、`release/1.17` のブランチを取得する。

```bash
cd ~/px4_ws/src

git clone -b release/1.17 https://github.com/PX4/px4_msgs.git

cd ~/px4_ws

colcon build --packages-select px4_msgs
```

**期待する結果**（抜粋。`git clone` の進み具合の行と、ビルド中の `[Processing: ...]` の行は省いた。時間は実行ごとに変わる）:

```text
Cloning into 'px4_msgs'...
...
Starting >>> px4_msgs
Finished <<< px4_msgs [<time>]

Summary: 1 package finished [<time>]
```

`px4_msgs` には200を超える型があり、それぞれについてC++とPythonのコードを作るので、ビルドに時間がかかる（2-2節のAgentより長くかかることが多い）。ビルドの間は `[Processing: px4_msgs]` の行が何度も出るが、止まっているわけではない。

### 2-4. 型を確かめる

ビルドしたパッケージを、このターミナルに登録して（親プロジェクトのフェーズ2の2-5節）、機体の位置と姿勢の型 [`px4_msgs/msg/VehicleOdometry`](https://github.com/PX4/px4_msgs/blob/release/1.17/msg/VehicleOdometry.msg) の中身を表示する。

```bash
source ~/px4_ws/install/setup.bash

ros2 interface show px4_msgs/msg/VehicleOdometry
```

**期待する結果**（抜粋）:

```text
# Vehicle odometry data
#
# Fits ROS REP 147 for aerial vehicles

uint32 MESSAGE_VERSION = 0

uint64 timestamp         # [us] Time since system start
...
float32[3] position  # [m] [@frame local frame] [@invalid NaN If invalid/unknown] Position. Origin is position of GC at startup.
float32[4] q         # [-] [@invalid NaN First value if invalid/unknown] Attitude (expressed as a quaternion) ...
...
float32[3] velocity          # [m/s] [@frame @velocity_frame] [@invalid NaN If invalid/unknown] Velocity.
...
```

`position` が位置（m）、`q` が姿勢（クォータニオン。回転を4つの数で表す方法）、`velocity` が速度（m/s）である。`pose_frame` と `velocity_frame` の値で、位置と速度がどの座標系か（NED等）が分かる。

`source ~/px4_ws/install/setup.bash` は、ターミナルごとに要る。T3とT5では、新しく開くたびに実行する。忘れると、`px4_msgs` の型が見つからず、トピックの値を表示できない（「つまずきやすい点」）。この手順書では、見落とさないように、T3とT5のコマンドの先頭に、毎回この行を書く。同じターミナルで既に実行していても、もう一度実行して問題ない。

## 3. つないで、トピックを見る

T1でPX4のシミュレーションを、T2でQGCを、T3でAgentを起動する（どの順に起動してもよい。PX4の中のクライアントは、Agentが起動するまで待ち続ける）。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl gz_x500

# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage

# T3
source ~/px4_ws/install/setup.bash

MicroXRCEAgent udp4 -p 8888
```

`MicroXRCEAgent udp4 -p 8888` は、UDP（IPv4）の8888番のポートでクライアントを待つ、という意味である。

**期待する結果**（抜粋。行の先頭の時刻、ポートの番号（`58536`）は、実行ごとに変わる。T3は約200行で、同じ形の行の繰り返しを `...` で省いた。T1は想定）:

```text
# T3（Agent）
[1793451846.496970] info     | UDPv4AgentLinux.cpp | init                     | running...             | port: 8888
[1793451846.497550] info     | Root.cpp           | set_verbose_level        | logger setup           | verbose_level: 4
[1793451879.342087] info     | Root.cpp           | create_client            | create                 | client_key: 0x00000001, session_id: 0x81
[1793451879.342313] info     | SessionManager.hpp | establish_session        | session established    | client_key: 0x00000001, address: 127.0.0.1:58536
[1793451879.352913] info     | ProxyClient.cpp    | create_participant       | participant created    | client_key: 0x00000001, participant_id: 0x001(1)
[1793451885.540573] info     | ProxyClient.cpp    | create_topic             | topic created          | client_key: 0x00000001, topic_id: 0x800(2), participant_id: 0x001(1)
[1793451885.541773] info     | ProxyClient.cpp    | create_subscriber        | subscriber created     | client_key: 0x00000001, subscriber_id: 0x800(4), participant_id: 0x001(1)
[1793451885.550587] info     | ProxyClient.cpp    | create_datareader        | datareader created     | client_key: 0x00000001, datareader_id: 0x800(6), subscriber_id: 0x800(4)
...
[1793451885.586804] info     | ProxyClient.cpp    | create_topic             | topic created          | client_key: 0x00000001, topic_id: 0x0CD(2), participant_id: 0x001(1)
[1793451885.587031] info     | ProxyClient.cpp    | create_publisher         | publisher created      | client_key: 0x00000001, publisher_id: 0x0CD(3), participant_id: 0x001(1)
[1793451885.588639] info     | ProxyClient.cpp    | create_datawriter        | datawriter created     | client_key: 0x00000001, datawriter_id: 0x0CD(5), publisher_id: 0x0CD(3)
...
[1793451885.602352] info     | ProxyClient.cpp    | create_replier           | replier created        | client_key: 0x00000001, requester_id: 0x800(7), participant_id: 0x001(1)

# T1（PX4のシミュレーション）
...
INFO  [uxrce_dds_client] synchronized with time offset <offset>us
INFO  [uxrce_dds_client] successfully created rt/fmu/out/vehicle_odometry data writer, topic id: <id>
...
```

T3の行の先頭の数は、PCの時刻を、1970年1月1日からの秒数（Unix時刻）で表したものである。T3は、次の順に進む。

- **待ち始める**: 最初の2行は、Agentが8888番で待ち始めたことを示す。PX4がまだ起動していなければ、起動するまで、ここで止まっている。
- **PX4とつながる**: PX4が起動すると、クライアント（PX4の中の `uxrce_dds_client`）の登録（`create_client`）と、通信の始まり（`session established`。相手は同じPCの `127.0.0.1`）の行が出る。`participant created` は、PX4の代わりに、DDSの参加者（DDSの通信に加わる単位）を作ったことを示す。
- **PX4が受け取るトピック**: `topic created`・`subscriber created`・`datareader created` の3行の組が、`0x800` から `0x825` まで、38組続く。PX4が受け取るトピック（ROS 2の側の `/fmu/in/...`）ごとに、Agentが、PX4の代わりにROS 2からの値を受け取る口（データの読み手）を作っている。
- **PX4が出すトピック**: 続いて、`topic created`・`publisher created`・`datawriter created` の3行の組が、27組続く。PX4が出すトピック（`/fmu/out/...`）ごとに、PX4の代わりにROS 2へ値を送る口（データの書き手）を作っている。組の数は、次の `ros2 topic list` の `/fmu/in/` と `/fmu/out/` のトピックの数と同じである。
- **サービス**: 最後の `replier created` は、PX4が受け付けるサービス（`vehicle_command`。指示を受け取り、結果を返す）を作ったことを示す（PX4 v1.17のソースの `vehicle_command_srv.cpp`）。この教材では使わない。

`0x800(2)` のような番号は、Agentが作った物の番号で、括弧の中の数は、物の種類（トピック・読み手・書き手等）を表す。この手順書では、番号を読まなくてよい。

T1には、PX4とAgentが時刻を合わせた（`synchronized with time offset`）行と、`successfully created rt/fmu/out/... data writer` の行が、PX4が出すトピックの数だけ並ぶ。`rt/` は、ROS 2のトピックをDDSの上で表すときに付く印で、ROS 2の側では `/fmu/out/...` と見える。

T5で、ROS 2のトピックの一覧を見る。

```bash
# T5
source ~/px4_ws/install/setup.bash

ros2 topic list
```

**期待する結果**（抜粋。全部で67行。`/fmu/in/` が38行、`/fmu/out/` が27行）:

```text
/fmu/in/actuator_motors
/fmu/in/actuator_servos
/fmu/in/arming_check_reply_v1
...
/fmu/in/offboard_control_mode
...
/fmu/in/trajectory_setpoint
...
/fmu/in/vehicle_command
...
/fmu/out/airspeed_validated_v1
/fmu/out/arming_check_request_v1
/fmu/out/battery_status_v1
...
/fmu/out/failsafe_flags
...
/fmu/out/vehicle_attitude
...
/fmu/out/vehicle_local_position_v1
/fmu/out/vehicle_odometry
/fmu/out/vehicle_status_v1
/fmu/out/vtol_vehicle_status
/fmu/out/wind
/parameter_events
/rosout
```

`/fmu/out/` で始まるのがPX4が出すトピック、`/fmu/in/` で始まるのがPX4が受け取るトピックである。`/fmu/in/` の `offboard_control_mode`・`trajectory_setpoint`・`vehicle_command` は、フェーズ3で、ROS 2から機体を飛ばすときに使う。`rover_...`（地面を走る車両）や `fixed_wing_...`（固定翼の機体）のように、ドローン（マルチコプタ）では使わないトピックも並ぶ。PX4は、機体の種類を問わず、同じトピックの一覧を出すからである。最後の `/parameter_events` と `/rosout` は、PX4ではなく、ROS 2が標準で用意するトピックである。どのトピックを出すかは、PX4のソースの中の設定のファイル（`src/modules/uxrce_dds_client/dds_topics.yaml`）で決まっている。名前の末尾の `_v1` は、型の版の印である（フェーズ0の7節）。

## 4. 機体の状態を見る

### 4-1. トピックの型とQoSを見る

```bash
# T5
source ~/px4_ws/install/setup.bash

ros2 topic info -v /fmu/out/vehicle_odometry
```

**期待する結果**（GIDは実行ごとに変わる）:

```text
Type: px4_msgs/msg/VehicleOdometry

Publisher count: 1

Node name: _CREATED_BY_BARE_DDS_APP_
Node namespace: _CREATED_BY_BARE_DDS_APP_
Topic type: px4_msgs/msg/VehicleOdometry
Topic type hash: INVALID
Endpoint type: PUBLISHER
GID: 01.0f.30.94.98.16.f8.6c.00.00.00.00.00.00.3b.03
QoS profile:
  Reliability: BEST_EFFORT
  History (Depth): UNKNOWN
  Durability: TRANSIENT_LOCAL
  Lifespan: Infinite
  Deadline: Infinite
  Liveliness: AUTOMATIC
  Liveliness lease duration: Infinite

Subscription count: 0
```

送り手（Publisher）は1つで、ROS 2のノードではなく、Agentが（ROS 2を使わずに）DDSで直接作ったものなので、ノードの名前と名前空間は `_CREATED_BY_BARE_DDS_APP_`（ROS 2ではない、DDSだけのプログラムが作った）と表示される。同じ理由で、ROS 2のノードなら送り手が知らせる型の指紋（`Topic type hash`）が無いので `INVALID`、履歴の深さ（`History (Depth)`）も伝わらないので `UNKNOWN` と表示される。どちらも、値を受け取るのには影響しない。`GID` は、送り手を見分けるための番号である。QoS（ROS 2の通信の品質の設定）は、信頼性（Reliability）が `BEST_EFFORT`（届かなかったデータを送り直さない）、耐久性（Durability）が `TRANSIENT_LOCAL`（後からつないだ受け手にも、最後のデータを渡す。ただし、受け手も `TRANSIENT_LOCAL` を求めた場合だけ）である。この設定が、5節の話につながる。

### 4-2. 位置の値を見る

```bash
# T5
source ~/px4_ws/install/setup.bash

ros2 topic echo --once /fmu/out/vehicle_odometry
```

**期待する結果**（機体が地面にいるとき。数は実行ごとに変わる）:

```text
timestamp: 1793451977976925
timestamp_sample: 1793451977976925
pose_frame: 1
position:
- 0.01132920477539301
- -0.01821982115507126
- -0.01982933282852173
q:
- 0.6688007116317749
- -0.0001213458162965253
- -0.0002021686377702281
- 0.7434417605400085
velocity_frame: 1
velocity:
- 0.01125241443514824
- -0.007338504772633314
- -0.0037452999968081713
angular_velocity:
- -0.00016174273332580924
- 0.0006787137826904655
- -0.00014059009845368564
position_variance:
- 0.011531238444149494
- 0.011538553051650524
- 0.027856960892677307
orientation_variance:
- 3.578146788640879e-05
- 3.584166552172974e-05
- 0.0336848720908165
velocity_variance:
- 0.0037913925480097532
- 0.0037908463273197412
- 0.0029586583841592073
reset_counter: 11
quality: 0
---
```

`--once` は、1つ受け取ったら終わる指定である。`pose_frame: 1` と `velocity_frame: 1` は、型の定義の `POSE_FRAME_NED = 1`・`VELOCITY_FRAME_NED = 1` に当たり、位置と速度がNED（フェーズ0の8節）であることを示す。`position` の3つの数は、北・東・下の順の位置（m）で、原点はPX4の推定が動き始めたときの機体の位置である（フェーズ1の6-2節）。機体が地面にいる間は、3つとも0に近い（この例では、どれも2cm以内）。ちょうど0にならないのは、推定の値が少し揺れるためである。

`timestamp` は、1970年1月1日からのマイクロ秒（T3のAgentの行の先頭の時刻と同じ時計）である。PX4の中の時刻は起動からの時間（フェーズ1の6-2節の `listener` の `timestamp`）だが、`uxrce_dds_client` が、Agentと合わせた時刻のずれ（3節のT1の `time offset`）を使い、ROS 2へ送るときにPCの時刻に直している（PX4 v1.17のソースの `src/modules/uxrce_dds_client/dds_topics.h.em` と `Tools/msg/templates/ucdr/msg.h.em`）。ただし、直されるのは `timestamp` と `timestamp_sample` だけで、ほかの時刻の項目（4-3節の `nav_state_timestamp` 等）は、起動からの時間のままである。

`q` は姿勢のクォータニオンで、4つの数は w・x・y・z の順である。xとyがほぼ0なのは、機体が水平であることを示す。wとzから、機首の向き（方位）を求めると、約96°になる（2×atan(0.743/0.669)。フェーズ1の4節のQGCの方位の95°前後と同じで、東を向いている）。`..._variance` は、それぞれの推定の値のばらつきの大きさ（分散）である。

### 4-3. 機体の状態を見る

機体のアームの状態と飛行モードは、[`px4_msgs/msg/VehicleStatus`](https://github.com/PX4/px4_msgs/blob/release/1.17/msg/VehicleStatus.msg) の型の `/fmu/out/vehicle_status_v1` に入っている。

```bash
# T5
source ~/px4_ws/install/setup.bash

ros2 topic echo --once /fmu/out/vehicle_status_v1
```

**期待する結果**（抜粋。全部で約40行。`timestamp` は実行ごとに変わる）:

```text
timestamp: 1793451990286189
armed_time: 0
takeoff_time: 0
arming_state: 1
latest_arming_reason: 0
latest_disarming_reason: 0
nav_state_timestamp: 1704000
nav_state_user_intention: 4
nav_state: 4
...
vehicle_type: 1
...
---
```

`nav_state` は今の飛行モード、`nav_state_user_intention` は人や地上局が選んだ飛行モードで、フェーズ1の6-1節の `commander status` の2行目と3行目に当たる。`armed_time` と `takeoff_time` が0なのは、まだアームも離陸もしていないからである。`nav_state_timestamp` は、飛行モードが今の値になった時刻で、4-2節のとおり、起動からの時間（マイクロ秒。この例では起動から約1.7秒）のままである。`vehicle_type: 1` は、型の定義の `VEHICLE_TYPE_ROTARY_WING`（回転翼の機体）に当たる。

値は数で表される。数と意味の対応は、型の定義の定数にある（`ros2 interface show px4_msgs/msg/VehicleStatus` でも見られる）。この手順書で出会うものは次のとおりである。

| 項目 | 数 | 定数の名前 | 意味 |
|---|---|---|---|
| `arming_state` | 1 | `ARMING_STATE_DISARMED` | ディスアーム |
| `arming_state` | 2 | `ARMING_STATE_ARMED` | アーム |
| `nav_state` | 4 | `NAVIGATION_STATE_AUTO_LOITER` | Hold |
| `nav_state` | 5 | `NAVIGATION_STATE_AUTO_RTL` | Return |
| `nav_state` | 14 | `NAVIGATION_STATE_OFFBOARD` | Offboard（フェーズ3） |
| `nav_state` | 17 | `NAVIGATION_STATE_AUTO_TAKEOFF` | Takeoff |
| `nav_state` | 18 | `NAVIGATION_STATE_AUTO_LAND` | Land |

フェーズ1の4節で見たように、起動した直後の飛行モードはHoldなので、`nav_state` は4になる。

## 5. QoS: 送る側に合わせて受け取る

4-1節のとおり、PX4のトピックの送り手は、信頼性が `BEST_EFFORT` である。ROS 2の購読の既定の信頼性は `RELIABLE`（届かなかったデータを送り直してもらう）で、`RELIABLE` の受け手は、`BEST_EFFORT` の送り手とつながらない。受け手が求める「送り直し」を、送り手が約束していないからである。

`ros2 topic echo` は、何も指定しないと、送り手のQoSに合わせて受け取るので、4節では値が表示された。わざと既定の `RELIABLE` で受け取ろうとすると、どうなるかを見る。

```bash
# T5
source ~/px4_ws/install/setup.bash

ros2 topic echo --qos-reliability reliable /fmu/out/vehicle_odometry
```

**期待する結果**（時刻とノードの名前の数は、実行ごとに変わる）:

```text
[WARN] [1793452009.943585227] [_ros2cli_6667]: New publisher discovered on topic '/fmu/out/vehicle_odometry', offering incompatible QoS. No messages will be received from it. Last incompatible policy: RELIABILITY
```

警告が1行出るだけで、値は表示されない。`_ros2cli_6667` は、`ros2 topic echo` が内部で作ったノードの名前である。警告の文は、「互換性の無いQoSの送り手が見つかった。この送り手からは値を受け取れない。合わなかった項目は信頼性（RELIABILITY）」という意味である。送り手と受け手のQoSが合わないので、つながらないのである。Ctrl+Cで止める。

自分でノードを書くときは、この合わせ方を、ノードのコードの中で指定する。PX4の文書は、PX4のトピックを購読するノードに、ROS 2があらかじめ用意しているセンサのデータ向けのQoS（信頼性が `BEST_EFFORT`）を使うよう求めている。PX4へ送る側（`/fmu/in/` のトピック）は、ROS 2の既定のままでよい。フェーズ3で、ノードを書くときに使う。

## 6. 機体を動かして、値の変化を見る

T5で、位置だけを表示し続ける。

```bash
# T5
source ~/px4_ws/install/setup.bash

ros2 topic echo /fmu/out/vehicle_odometry --field position
```

**期待する結果**（機体が地面にいるときの、最初の3回分。数は実行ごとに変わる）:

```text
[ 0.00151809  0.0132562  -0.02072768]
---
[ 0.00154904  0.01322436 -0.02073906]
---
[ 0.00162934  0.01314959 -0.02078304]
---
...
```

`--field position` は、`position` の項目だけを表示する指定である。4-2節と違い、3つの数が、角括弧の中に、北・東・下の順に横に並ぶ（項目だけを取り出すと、配列の形で表示される）。地面にいる間も、4-2節のとおり、数cm以内で少しずつ変わり続ける。表示が流れ続けるので、値の変化を見ながら、T2のQGCで、フェーズ1の5節と同じように離陸させ、Go to locationで移動させ、着陸させる。

- **離陸すると**: 3つ目の数（下への位置）が、0から負の方向に大きくなり、離陸の高さ（10 ftなら約−3）で止まる。NEDのzは下が正だからである。
- **Go to locationで北へ動かすと**: 1つ目の数（北への位置）が増える。東へ動かすと、2つ目の数（東への位置）が増える。
- **着陸すると**: 3つ目の数が0に近い値に戻る。

確かめたら、T5で Ctrl+C を押して止める。

## 7. 止める

T2のQGCのウィンドウを閉じ、T1で Ctrl+C を押してPX4のシミュレーションを止め、最後にT3で Ctrl+C を押してAgentを止める。

## 8. 課題（任意）

1. `ros2 topic echo --once /fmu/out/vehicle_local_position_v1` で、`x`・`y`・`z` が、4-2節の `position` の3つの数と同じになることを確かめる（どちらも、PX4の推定した位置である）。
2. 飛んでいる間に、`ros2 topic echo /fmu/out/vehicle_status_v1 --field nav_state` を表示し続け、QGCで着陸を指示すると、4から18に変わることを確かめる。

## つまずきやすい点

- **`ros2 topic list` に `/fmu/` のトピックが出ない**: T3のAgentが動いているか、T1のPX4がつながったか（T1に `successfully created` の行が出たか）を見る。ROS 2のドメインの番号（環境変数 `ROS_DOMAIN_ID`）を0以外にしている場合は、PX4の側の既定（パラメータ `UXRCE_DDS_DOM_ID` の0）と合わないので、そのターミナルでは `ROS_DOMAIN_ID` を0にするか、設定しない。
- **`ros2 topic echo` で `The message type 'px4_msgs/msg/...' is invalid` と出る**: そのターミナルで `source ~/px4_ws/install/setup.bash` を実行していない（2-4節）。
- **`colcon build` が、Pythonのモジュールが無い、などで止まる**: PX4専用の仮想環境を有効にしたターミナルでビルドしている。新しいターミナルを開いてやり直す（1節）。
- **Agentのビルドが、取得のエラーで止まる**: 2-2節のとおり、ビルドの途中でGitHubから取得する。インターネットにつながっているかを確かめて、もう一度 `colcon build` を実行する。

## 次へ

学習計画（[`docs/learning_plan.md`](learning_plan.md)）のフェーズ3（ROS 2から指令して、機体を飛ばす）へ進む。先に、自作のノードとQoSの復習の [フェーズ3-0](phase3_0_node_qos.md) を読み、続けて [フェーズ3](phase3_offboard.md) へ進む。

## 出典

この手順書の技術的な記述は、次の文書とファイルを読んで、自分の言葉でまとめたもの（逐語の転載ではない）。

- PX4 User Guide（v1.17。[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)、Dronecode/PX4）: [ROS 2 User Guide](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/ros2/user_guide.md)（Agentの取得の版、起動の `MicroXRCEAgent udp4 -p 8888`、購読のQoS）、[uXRCE-DDS](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/middleware/uxrce_dds.md)（ROS 2のワークスペースの中でAgentをビルドする方法と、ROS 2の版に合うAgentの版、v3系とつながらないこと）。2-2節・2-3節・3節のT3のコマンドは、これらの文書の手順に従い、ワークスペースの場所と `--packages-select` をこの教材で変えた（改変あり）。
- PX4 v1.17のソースと設定のファイル（作成に使った環境に取得したもの）: [`src/modules/uxrce_dds_client/dds_topics.yaml`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/dds_topics.yaml)（出すトピックの一覧）、[`src/modules/uxrce_dds_client/utilities.hpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/utilities.hpp)（送り手のQoSが `BEST_EFFORT`・`TRANSIENT_LOCAL` であること、名前の版の印）、[`src/modules/uxrce_dds_client/module.yaml`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/module.yaml)（`UXRCE_DDS_DOM_ID` の既定の0）、[`src/modules/uxrce_dds_client/vehicle_command_srv.cpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/vehicle_command_srv.cpp)（3節のT3の `replier created` のサービス）、[`src/modules/uxrce_dds_client/dds_topics.h.em`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/dds_topics.h.em) と [`Tools/msg/templates/ucdr/msg.h.em`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/Tools/msg/templates/ucdr/msg.h.em)（4-2節の、`timestamp` と `timestamp_sample` だけを、時刻のずれでPCの時刻に直すこと）
- [PX4/px4_msgs](https://github.com/PX4/px4_msgs)（`release/1.17`、BSD 3-Clause License、PX4 Development Team）: 型の定義（`VehicleOdometry.msg`・`VehicleStatus.msg`）。2-4節の `ros2 interface show` の表示は、この定義の抜粋である。
- [eProsima/Micro-XRCE-DDS-Agent](https://github.com/eProsima/Micro-XRCE-DDS-Agent)（v2.4.3、Apache License 2.0）: パッケージの名前（`CMakeLists.txt` の `microxrcedds_agent`）と、依存のライブラリをビルドの途中で取得する作り（`CMakeLists.txt` と `cmake/SuperBuild.cmake`）。
