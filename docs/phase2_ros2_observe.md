# フェーズ2: ROS 2から、機体の状態を見る

[学習計画](learning_plan.md) のフェーズ2の手順書。PX4とROS 2をつなぐ中継のプログラム（Micro XRCE-DDS Agent）と、PX4のトピックの型のパッケージ（`px4_msgs`）をビルドし、PX4のシミュレーションの機体の位置や状態を、ROS 2のコマンド（`ros2 topic`）で見る。PX4のトピックを受け取るときに要るQoSの指定と、値がNEDであることも、ここで実際に確かめる。プログラムは書かない。ここで作るワークスペースと、つなぎ方は、フェーズ3以降のすべての手順書で使う。

- 想定環境: [フェーズ1](phase1_first_flight.md) を終えたWSL2のUbuntu 24.04
- 所要の目安: 1〜2コマ（Agentのビルドに時間がかかる）
- 必須の範囲: 1〜7節（8節の課題は任意）
- 前提（親プロジェクト）: [フェーズ2](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase2_packages.md) の1-1節（ワークスペースの構成）・1-2節（ビルドと実行の流れ）・2-1節（ワークスペースを作る）・2-4節（ビルドする）・2-5節（環境に登録して実行する）

> **この手順書の位置づけ**: [フェーズ0](phase0_drone_px4.md) の7節（uXRCE-DDS）と8節（座標系）を、実際に動かして確かめる。ROS 2のワークスペースとビルドの基本は、上の親プロジェクトの節で学ぶ。
>
> **期待する結果の出どころ**: （作成中）2節（Agentと `px4_msgs` のビルド、型の表示）は、実際に動かした表示（ROS 2 Jazzy、Agent v2.4.3、`px4_msgs` の `release/1.17`）。3節以降の表示は、PX4 v1.17のソースと設定のファイル、`px4_msgs` の型の定義、PX4とeProsimaの公式の文書から想定したもの。実際に動かした表示に差し替える予定。

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
| T1 | Micro XRCE-DDS Agent | 使わない |
| T2 | PX4のシミュレーション（`make px4_sitl gz_x500`） | 使う（環境構築・フェーズ1と同じ） |
| T3 | QGroundControl | 使わない |
| T4 | ビルドと `ros2` のコマンド | 使わない |

PX4専用の仮想環境は、PX4のビルドと起動のためのものである。環境構築の4-3節のとおり、仮想環境を有効にしたターミナルでは、ROS 2のビルドやコマンドを動かさない。T1とT4は、仮想環境を有効にしていない、新しいターミナルで開く。

## 2. Agentと `px4_msgs` をビルドする

### 2-1. ワークスペースを用意する

この教材のワークスペースは `~/px4_ws` にする（作り方と、`src`・`build`・`install` の役割は、親プロジェクトのフェーズ2の1-1節と2-1節。親プロジェクトの `~/ros2_ws` と、名前だけが違う）。

親プロジェクトの `~/ros2_ws` とは分ける。一般に、目的の違うプロジェクト（製品）ごとにワークスペースを分けると、使う依存の版をプロジェクトごとに決められ、ビルドや不具合の影響がほかのプロジェクトに及ばない。複数のプロジェクトで共通に使う部品は、その部品だけのワークスペースを作ってビルドし、その `setup.bash` を読み込んでから、各プロジェクトのワークスペースをビルドする形で共有できる（ワークスペースを重ねる、オーバーレイという仕組み）。

```bash
# T4
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
Finished <<< microxrcedds_agent [<時間>]

Summary: 1 package finished [<時間>]
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
Finished <<< px4_msgs [<時間>]

Summary: 1 package finished [<時間>]
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

`source ~/px4_ws/install/setup.bash` は、ターミナルごとに要る。T1とT4では、新しく開くたびに実行する。

## 3. つないで、トピックを見る

T1でAgentを、T2でPX4のシミュレーションを、T3でQGCを起動する。

```bash
# T1
source ~/px4_ws/install/setup.bash

MicroXRCEAgent udp4 -p 8888

# T2
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl gz_x500

# T3
cd ~/qgc

./QGroundControl-x86_64.AppImage
```

`MicroXRCEAgent udp4 -p 8888` は、UDP（IPv4）の8888番のポートでクライアントを待つ、という意味である。

**期待する結果**（抜粋。想定。時刻・ID・番号は実行ごとに変わる）:

```text
# T1（Agent）
[<時刻>] info     | UDPv4AgentLinux.cpp | init                     | running...             | port: 8888
[<時刻>] info     | Root.cpp           | set_verbose_level        | logger setup           | verbose_level: 4
...
[<時刻>] info     | Root.cpp           | create_client            | create                 | client_key: <番号>, session_id: 0x81
...
[<時刻>] info     | ProxyClient.cpp    | create_datawriter        | datawriter created     | client_key: <番号>, datawriter_id: <番号>, publisher_id: <番号>

# T2（PX4のシミュレーション）
...
INFO  [uxrce_dds_client] synchronized with time offset <時間>us
INFO  [uxrce_dds_client] successfully created rt/fmu/out/vehicle_odometry data writer, topic id: <番号>
...
```

T1には、Agentが8888番で待ち始めた行の後、PX4が起動してつながると、クライアントの登録（`create_client`）と、トピックごとの送り手の作成（`datawriter created`）の行が続く。T2には、`successfully created rt/fmu/out/... data writer` の行が、PX4が出すトピックの数だけ並ぶ。`rt/` は、ROS 2のトピックをDDSの上で表すときに付く印で、ROS 2の側では `/fmu/out/...` と見える。

T4で、ROS 2のトピックの一覧を見る。

```bash
# T4
ros2 topic list
```

**期待する結果**（抜粋。想定）:

```text
/fmu/in/...
...
/fmu/out/battery_status_v1
/fmu/out/failsafe_flags
...
/fmu/out/vehicle_attitude
...
/fmu/out/vehicle_local_position_v1
/fmu/out/vehicle_odometry
/fmu/out/vehicle_status_v1
...
/parameter_events
/rosout
```

`/fmu/out/` で始まるのがPX4が出すトピック、`/fmu/in/` で始まるのがPX4が受け取るトピックである。どのトピックを出すかは、PX4のソースの中の設定のファイル（`src/modules/uxrce_dds_client/dds_topics.yaml`）で決まっている。名前の末尾の `_v1` は、型の版の印である（フェーズ0の7節）。

## 4. 機体の状態を見る

### 4-1. トピックの型とQoSを見る

```bash
ros2 topic info -v /fmu/out/vehicle_odometry
```

**期待する結果**（抜粋。想定。GIDは実行ごとに変わる）:

```text
Type: px4_msgs/msg/VehicleOdometry

Publisher count: 1

Node name: _NODE_NAME_UNKNOWN_
Node namespace: _NODE_NAMESPACE_UNKNOWN_
Topic type: px4_msgs/msg/VehicleOdometry
...
Endpoint type: PUBLISHER
...
QoS profile:
  Reliability: BEST_EFFORT
  History (Depth): ...
  Durability: TRANSIENT_LOCAL
...

Subscription count: 0
```

送り手（Publisher）は1つで、ROS 2のノードではなくAgentが作ったものなので、ノードの名前は `_NODE_NAME_UNKNOWN_` と表示される。QoS（ROS 2の通信の品質の設定）は、信頼性（Reliability）が `BEST_EFFORT`（届かなかったデータを送り直さない）、耐久性（Durability）が `TRANSIENT_LOCAL`（後からつないだ受け手にも、最後のデータを渡す。ただし、受け手も `TRANSIENT_LOCAL` を求めた場合だけ）である。この設定が、5節の話につながる。

### 4-2. 位置の値を見る

```bash
ros2 topic echo --once /fmu/out/vehicle_odometry
```

**期待する結果**（抜粋。想定。数は実行ごとに変わる）:

```text
timestamp: <起動からの時間>
timestamp_sample: <起動からの時間>
pose_frame: 1
position:
- <北への位置>
- <東への位置>
- <下への位置>
q:
- ...
velocity_frame: 1
velocity:
- ...
...
---
```

`--once` は、1つ受け取ったら終わる指定である。`pose_frame: 1` と `velocity_frame: 1` は、型の定義の `POSE_FRAME_NED = 1`・`VELOCITY_FRAME_NED = 1` に当たり、位置と速度がNED（フェーズ0の8節）であることを示す。`position` の3つの数は、北・東・下の順の位置（m）で、原点はPX4の推定が動き始めたときの機体の位置である（フェーズ1の6-2節）。機体が地面にいる間は、3つとも0に近い。

### 4-3. 機体の状態を見る

機体のアームの状態と飛行モードは、[`px4_msgs/msg/VehicleStatus`](https://github.com/PX4/px4_msgs/blob/release/1.17/msg/VehicleStatus.msg) の型の `/fmu/out/vehicle_status_v1` に入っている。

```bash
ros2 topic echo --once /fmu/out/vehicle_status_v1
```

**期待する結果**（抜粋。想定）:

```text
...
arming_state: 1
...
nav_state: 4
...
```

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
ros2 topic echo --qos-reliability reliable /fmu/out/vehicle_odometry
```

**期待する結果**（想定）:

```text
[WARN] [<時刻>] [<ノード名>]: New publisher discovered on topic '/fmu/out/vehicle_odometry', offering incompatible QoS. No messages will be received from it. Last incompatible policy: RELIABILITY
```

警告が1行出るだけで、値は表示されない。送り手と受け手のQoSが合わないので、つながらないのである。Ctrl+Cで止める。

自分でノードを書くときは、この合わせ方を、ノードのコードの中で指定する。PX4の文書は、PX4のトピックを購読するノードに、ROS 2があらかじめ用意しているセンサのデータ向けのQoS（信頼性が `BEST_EFFORT`）を使うよう求めている。PX4へ送る側（`/fmu/in/` のトピック）は、ROS 2の既定のままでよい。フェーズ3で、ノードを書くときに使う。

## 6. 機体を動かして、値の変化を見る

T4で、位置だけを表示し続ける。

```bash
ros2 topic echo /fmu/out/vehicle_odometry --field position
```

**期待する結果**（想定。数は実行ごとに変わる）:

```text
- <北への位置>
- <東への位置>
- <下への位置>
---
...
```

`--field position` は、`position` の項目だけを表示する指定である。表示が流れ続けるので、値の変化を見ながら、T3のQGCで、フェーズ1の5節と同じように離陸させ、Go to locationで移動させ、着陸させる。

- **離陸すると**: 3つ目の数（下への位置）が、0から負の方向に大きくなり、離陸の高さ（10 ftなら約−3）で止まる。NEDのzは下が正だからである。
- **Go to locationで北へ動かすと**: 1つ目の数（北への位置）が増える。東へ動かすと、2つ目の数（東への位置）が増える。
- **着陸すると**: 3つ目の数が0に近い値に戻る。

確かめたら、T4で Ctrl+C を押して止める。

## 7. 止める

T3のQGCのウィンドウを閉じ、T2で Ctrl+C を押してPX4のシミュレーションを止め、最後にT1で Ctrl+C を押してAgentを止める。

## 8. 課題（任意）

1. `ros2 topic echo --once /fmu/out/vehicle_local_position_v1` で、`x`・`y`・`z` が、4-2節の `position` の3つの数と同じになることを確かめる（どちらも、PX4の推定した位置である）。
2. 飛んでいる間に、`ros2 topic echo /fmu/out/vehicle_status_v1 --field nav_state` を表示し続け、QGCで着陸を指示すると、4から18に変わることを確かめる。

## つまずきやすい点

- **`ros2 topic list` に `/fmu/` のトピックが出ない**: T1のAgentが動いているか、T2のPX4がつながったか（T2に `successfully created` の行が出たか）を見る。ROS 2のドメインの番号（環境変数 `ROS_DOMAIN_ID`）を0以外にしている場合は、PX4の側の既定（パラメータ `UXRCE_DDS_DOM_ID` の0）と合わないので、そのターミナルでは `ROS_DOMAIN_ID` を0にするか、設定しない。
- **`ros2 topic echo` で `The message type 'px4_msgs/msg/...' is invalid` と出る**: そのターミナルで `source ~/px4_ws/install/setup.bash` を実行していない（2-4節）。
- **`colcon build` が、Pythonのモジュールが無い、などで止まる**: PX4専用の仮想環境を有効にしたターミナルでビルドしている。新しいターミナルを開いてやり直す（1節）。
- **Agentのビルドが、取得のエラーで止まる**: 2-2節のとおり、ビルドの途中でGitHubから取得する。インターネットにつながっているかを確かめて、もう一度 `colcon build` を実行する。

## 次へ

学習計画（[`docs/learning_plan.md`](learning_plan.md)）のフェーズ3（ROS 2から指令して、機体を飛ばす）へ進む。先に、自作のノードとQoSの復習の [フェーズ3-0](phase3_0_node_qos.md) を読み、続けて [フェーズ3](phase3_offboard.md) へ進む（どちらも下書き）。

## 出典

この手順書の技術的な記述は、次の文書とファイルを読んで、自分の言葉でまとめたもの（逐語の転載ではない）。

- PX4 User Guide（v1.17。[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)、Dronecode/PX4）: [ROS 2 User Guide](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/ros2/user_guide.md)（Agentの取得の版、起動の `MicroXRCEAgent udp4 -p 8888`、購読のQoS）、[uXRCE-DDS](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/middleware/uxrce_dds.md)（ROS 2のワークスペースの中でAgentをビルドする方法と、ROS 2の版に合うAgentの版、v3系とつながらないこと）。2-2節・2-3節・3節のT1のコマンドは、これらの文書の手順に従い、ワークスペースの場所と `--packages-select` をこの教材で変えた（改変あり）。
- PX4 v1.17のソースと設定のファイル（作成に使った環境に取得したもの）: [`src/modules/uxrce_dds_client/dds_topics.yaml`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/dds_topics.yaml)（出すトピックの一覧）、[`src/modules/uxrce_dds_client/utilities.hpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/utilities.hpp)（送り手のQoSが `BEST_EFFORT`・`TRANSIENT_LOCAL` であること、名前の版の印）、[`src/modules/uxrce_dds_client/module.yaml`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/module.yaml)（`UXRCE_DDS_DOM_ID` の既定の0）
- [PX4/px4_msgs](https://github.com/PX4/px4_msgs)（`release/1.17`、BSD 3-Clause License、PX4 Development Team）: 型の定義（`VehicleOdometry.msg`・`VehicleStatus.msg`）。2-4節の `ros2 interface show` の表示は、この定義の抜粋である。
- [eProsima/Micro-XRCE-DDS-Agent](https://github.com/eProsima/Micro-XRCE-DDS-Agent)（v2.4.3、Apache License 2.0）: パッケージの名前（`CMakeLists.txt` の `microxrcedds_agent`）と、依存のライブラリをビルドの途中で取得する作り（`CMakeLists.txt` と `cmake/SuperBuild.cmake`）。
