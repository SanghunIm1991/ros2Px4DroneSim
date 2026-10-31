# フェーズ3-0: 自作のノードとQoSの復習

[学習計画](learning_plan.md) のフェーズ3（ROS 2から指令して、機体を飛ばす）の前に読む、短い復習のページ。フェーズ3では、この教材で初めて、自分でノードを書く。その前に、ノードの骨組み（購読・タイマー・ログ）と、PX4のトピックを受け取るためのQoSの指定を、機体の高さを表示するだけの小さなノードで確かめる。ノードの観察の仕方（`ros2 node`）も、ここで見る。

- 想定環境: [フェーズ2](phase2_ros2_observe.md) を終えたWSL2のUbuntu 24.04（ワークスペース `~/px4_ws` に、Agentと `px4_msgs` がビルドしてある）
- 所要の目安: 1コマ
- 必須の範囲: すべて
- 前提（親プロジェクト）: [フェーズ2](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase2_packages.md) の2-2節（Pythonパッケージを作る）・2-4節（ビルドする）・2-5節（環境に登録して実行する）

> **このページの位置づけ**: 親プロジェクトのフェーズ1（コマンドでの観察）とフェーズ3-1（PublisherとSubscriber）・3-2b（QoS）のうち、フェーズ3に要る部分を、ドローンの題材で書き直したもの。親プロジェクトのそれらのページは、前提にしない（さらに詳しく知りたい場合の参考）。
>
> **期待する結果の出どころ**: サンプルのコードは、ROS 2のリンタ（`ament_flake8`）と、Pythonの文法の点検を通したもの。3節の `qos_profile_sensor_data` の値は、ROS 2 Jazzyの `rclpy` で表示して確かめた。2節・4節・5節の表示（パッケージの作成・ビルド・ノードのログ・`ros2 node`・`ros2 topic info -v`・QoSが合わないときの警告・Ctrl+Cで止めたときの例外）は、筆者の環境で動かして確かめたもの。4節の、離陸させたときの高さの変わり方は、想定である。時刻・GID・高さの値は、実行ごとに変わる。ビルドの時間はPCによって変わるので `<time>` と書いた。

## 0. 学習目標と完了条件

このページを終えると、次のことができるようになる。

1. ノードの骨組み（購読・タイマー・ログ・`main`）を説明できる（3節）。
2. PX4のトピックを購読するときに、センサのデータ向けのQoSを指定できる（3節）。
3. `ros2 node list`・`ros2 node info`・`ros2 topic info -v` で、自分のノードのつながりとQoSを確かめられる（4節）。
4. QoSの信頼性と耐久性の組み合わせで、送り手と受け手がつながるかを判断できる（5節・6節）。

**完了条件**: 高さを表示するノードを動かし、QGCで離陸させると、ログの高さが上がる（4節）。QoSを既定に戻すと、値が届かなくなることを確かめる（5節）。

## 1. 全体像

フェーズ2では、`ros2 topic echo` で、PX4のトピックを受け取って表示した。`ros2 topic echo` も、中身は1つのノードである。このページでは、同じことをするノードを自分で書く。ノードは、PX4の位置のトピック `/fmu/out/vehicle_local_position_v1`（型は [`px4_msgs/msg/VehicleLocalPosition`](https://github.com/PX4/px4_msgs/blob/release/1.17/msg/VehicleLocalPosition.msg)）を購読し、1秒ごとに、機体の高さをログに出す。

位置の `z` は、NED（フェーズ0の8節）なので、下が正である。ノードの中で符号を反対にして、上向きを正にした「高さ」として表示する。

このページでは、5つのターミナルを使う。

| ターミナル | 動かすもの | 仮想環境 `~/px4-venv` |
|---|---|---|
| T1 | PX4のシミュレーション（`make px4_sitl gz_x500`） | 使う |
| T2 | QGroundControl | 使わない |
| T3 | Micro XRCE-DDS Agent | 使わない |
| T5 | パッケージの作成とビルド、自作のノード | 使わない |
| T6 | ノードの観察のコマンド（`ros2 node`・`ros2 topic`） | 使わない |

ターミナルの番号は、[READMEの「ターミナルの番号」](../README.md#ターミナルの番号)のとおり、T1〜T4がどの手順書でも同じプログラムで、T5以降がそのページの作業用である。このページでは、LiDARの中継（T4）を使わないので、T4は開かない。

## 2. パッケージを作る

`~/px4_ws/src` に、Pythonのパッケージ `drone_basics` を作る（`ros2 pkg create` の各オプションの意味は、親プロジェクトのフェーズ2の2-2節）。依存に `rclpy` と `px4_msgs` を入れ、実行ファイル `altitude_monitor` の雛形も作る。

```bash
# T5
cd ~/px4_ws/src

ros2 pkg create --build-type ament_python \
  --license Apache-2.0 \
  --maintainer-name learner --maintainer-email noreply@example.com \
  --dependencies rclpy px4_msgs \
  --node-name altitude_monitor \
  drone_basics
```

**期待する結果**（`<username>` は、各自のユーザー名）:

```text
going to create a new package
package name: drone_basics
destination directory: /home/<username>/px4_ws/src
package format: 3
version: 0.0.0
description: TODO: Package description
maintainer: ['learner <noreply@example.com>']
licenses: ['Apache-2.0']
build type: ament_python
dependencies: ['rclpy', 'px4_msgs']
node_name: altitude_monitor
creating folder ./drone_basics
creating ./drone_basics/package.xml
creating source folder
creating folder ./drone_basics/drone_basics
creating ./drone_basics/setup.py
creating ./drone_basics/setup.cfg
creating folder ./drone_basics/resource
creating ./drone_basics/resource/drone_basics
creating ./drone_basics/drone_basics/__init__.py
creating folder ./drone_basics/test
creating ./drone_basics/test/test_copyright.py
creating ./drone_basics/test/test_flake8.py
creating ./drone_basics/test/test_pep257.py
creating ./drone_basics/drone_basics/altitude_monitor.py
```

前半の行は、オプションで指定した内容（依存の `rclpy`・`px4_msgs`、ノードの名前等）で、後半の `creating` の行は、作られたファイルとフォルダである。`description: TODO: ...` は、パッケージの説明がまだ空であることを示す（この教材では、そのままでよい）。`--node-name altitude_monitor` を付けたので、`setup.py` の `entry_points` に、実行ファイル `altitude_monitor` が登録された状態で作られる。次の3節で、雛形の `altitude_monitor.py` の中身を書き換える。

## 3. ノードを書く

ファイル: `~/px4_ws/src/drone_basics/drone_basics/altitude_monitor.py`

```python
from px4_msgs.msg import VehicleLocalPosition
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data


# PX4の推定した機体の位置を購読し、高さを1秒ごとにログに出すノード。
class AltitudeMonitor(Node):
    # 位置のトピックの購読と、ログを出すタイマーを作る。
    def __init__(self):
        super().__init__('altitude_monitor')
        self.latest = None
        self.sub = self.create_subscription(
            VehicleLocalPosition,
            '/fmu/out/vehicle_local_position_v1',
            self.on_position,
            qos_profile_sensor_data)
        self.timer = self.create_timer(1.0, self.on_timer)

    # 位置が届くたびに呼ばれ、最後に届いたものを覚えておく。
    def on_position(self, msg):
        self.latest = msg

    # タイマーから1秒ごとに呼ばれ、覚えている位置から高さを求めて出す。
    def on_timer(self):
        if self.latest is None:
            self.get_logger().info('位置をまだ受け取っていない')
            return
        altitude = -self.latest.z
        self.get_logger().info(
            f'高さ: {altitude:.2f} m (NEDのz: {self.latest.z:.2f})')


# エントリポイント（setup.py の entry_points から呼ばれる）。
# ノードを作って spin で回し、Ctrl+C で後片付けして終わる。
def main(args=None):
    rclpy.init(args=args)
    node = AltitudeMonitor()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()
```

- **ノード**: `Node` を受け継いだクラスが、1つのノードになる。`super().__init__('altitude_monitor')` の文字列が、ノードの名前（4節の `ros2 node list` で見える名前）である。
- **購読**: `create_subscription(型, トピック名, コールバック, QoS)` で購読を作る。トピックにデータが届くたびに、コールバック（ここでは `on_position`）が呼ばれる。PX4の位置のトピックは、1秒に何十回も届くので、`on_position` では覚えておくだけにして、表示はタイマーでまとめて行う。
- **QoS**: 4つ目の引数 `qos_profile_sensor_data` は、ROS 2があらかじめ用意している、センサのデータ向けのQoSである。信頼性が `BEST_EFFORT`、耐久性が `VOLATILE`、履歴が「最後の5つを保つ」になっている。フェーズ2の4-1節のとおり、PX4の送り手は信頼性が `BEST_EFFORT` なので、受け手も `BEST_EFFORT` にしないとつながらない（5節で確かめる）。PX4の文書も、PX4のトピックの購読にこのQoSを使うよう求めている。
- **タイマー**: `create_timer(周期, コールバック)` で、決まった周期（ここでは1秒）でコールバック（`on_timer`）を呼ぶ。フェーズ3では、このタイマーで、PX4への合図を0.1秒ごとに送る。
- **ログ**: `self.get_logger().info(...)` で、ノードの名前と時刻の付いたログを出す。
- **`main`**: ノードを作り、`rclpy.spin` で、コールバックを呼び出しながら動かし続ける。Ctrl+Cで止めると、`finally` で後片付けをして終わる。

## 4. 動かして、観察する

フェーズ2の3節と同じように、T1でPX4のシミュレーション、T2でQGC、T3でAgentを起動しておく。

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

**期待する結果**: フェーズ2の3節と同じ表示になる。QGCが機体につながり、T1に `Ready for takeoff!` が表示されるまで待つ。

T5で、パッケージをビルドして、ノードを起動する。

```bash
# T5
cd ~/px4_ws

colcon build --packages-select drone_basics

source ~/px4_ws/install/setup.bash

ros2 run drone_basics altitude_monitor
```

**期待する結果**（抜粋。機体が地面にいるとき。時刻と値は実行ごとに変わる）:

```text
Starting >>> drone_basics
Finished <<< drone_basics [<time>]

Summary: 1 package finished [<time>]
[INFO] [1793452319.003045441] [altitude_monitor]: 位置をまだ受け取っていない
[INFO] [1793452319.979714491] [altitude_monitor]: 位置をまだ受け取っていない
...
[INFO] [1793452378.982427123] [altitude_monitor]: 高さ: -0.05 m (NEDのz: 0.05)
[INFO] [1793452379.979829186] [altitude_monitor]: 高さ: -0.06 m (NEDのz: 0.06)
[INFO] [1793452380.979239911] [altitude_monitor]: 高さ: -0.07 m (NEDのz: 0.07)
...
[INFO] [1793452391.981620015] [altitude_monitor]: 高さ: 0.02 m (NEDのz: -0.02)
...
```

最初の3行は、ビルドの表示である。その後のログの行は、`[INFO]`（ログの重さの段階。ふつうの知らせ）、時刻（1970年1月1日からの秒数）、ノードの名前、3節のコードで出した文の順に並ぶ。

位置がまだ1つも届いていない間は、3節の `on_timer` のとおり、「位置をまだ受け取っていない」が1秒ごとに出る。位置が届き始めると、高さの表示に変わる。PX4のシミュレーションとAgentがまだつながっていないうちにノードを起動すると、つながるまで、この表示が続く（上の例は、T1〜T3より先にノードを起動したときのもの）。ノードを先に起動しても、起動し直す必要はなく、後からPX4とAgentがつながれば、そのまま位置を受け取り始める。

機体が地面にいる間は、高さは0に近いが、ちょうど0にはならず、数cmの範囲で揺れる（フェーズ2の4-2節）。この例のように、−0.05 m（地面より5cm下）のような負の値になることもある。推定の値の揺れなので、問題ない。QGCで離陸させる（フェーズ1の5-1節）と、高さが上がり、離陸の高さ（10 ftなら約3m）で止まる。着陸させると、0に近い値に戻る。

ノードを動かしたまま、新しいターミナル（T6）で、ノードを観察する。T6でも、最初に `source ~/px4_ws/install/setup.bash` を実行する。

```bash
# T6
source ~/px4_ws/install/setup.bash

ros2 node list

ros2 node info /altitude_monitor
```

**期待する結果**:

```text
$ ros2 node list
/altitude_monitor
$ ros2 node info /altitude_monitor
/altitude_monitor
  Subscribers:
    /fmu/out/vehicle_local_position_v1: px4_msgs/msg/VehicleLocalPosition
  Publishers:
    /parameter_events: rcl_interfaces/msg/ParameterEvent
    /rosout: rcl_interfaces/msg/Log
  Service Servers:
    /altitude_monitor/describe_parameters: rcl_interfaces/srv/DescribeParameters
    /altitude_monitor/get_parameter_types: rcl_interfaces/srv/GetParameterTypes
    /altitude_monitor/get_parameters: rcl_interfaces/srv/GetParameters
    /altitude_monitor/get_type_description: type_description_interfaces/srv/GetTypeDescription
    /altitude_monitor/list_parameters: rcl_interfaces/srv/ListParameters
    /altitude_monitor/set_parameters: rcl_interfaces/srv/SetParameters
    /altitude_monitor/set_parameters_atomically: rcl_interfaces/srv/SetParametersAtomically
  Service Clients:

  Action Servers:

  Action Clients:

```

`ros2 node list` には、自分のノードだけが出る。PX4のトピックの送り手はAgentで、ROS 2のノードではないので、一覧に出ない（フェーズ2の4-1節の `_CREATED_BY_BARE_DDS_APP_`）。`ros2 node info` の `Subscribers` に、購読しているトピックと型が出る。`/parameter_events` と `/rosout` は、すべてのノードが自動で持つトピックである（ログは `/rosout` にも送られる）。`Service Servers` の7つも、すべてのノードが自動で持つサービスで、ノードのパラメータ（実行中に変えられる設定）の読み書きと、使っている型の説明の問い合わせに使う。このノードはパラメータを使わないので、この教材では使わない。`Service Clients` 以下が空なのは、サービスを呼ぶ側やアクションを持たないからである。

購読のQoSを確かめる。

```bash
# T6
source ~/px4_ws/install/setup.bash

ros2 topic info -v /fmu/out/vehicle_local_position_v1
```

**期待する結果**（GIDは実行ごとに変わる）:

```text
Type: px4_msgs/msg/VehicleLocalPosition

Publisher count: 1

Node name: _CREATED_BY_BARE_DDS_APP_
Node namespace: _CREATED_BY_BARE_DDS_APP_
Topic type: px4_msgs/msg/VehicleLocalPosition
Topic type hash: INVALID
Endpoint type: PUBLISHER
GID: 01.0f.30.94.a4.1b.56.a7.00.00.00.00.00.00.3a.03
QoS profile:
  Reliability: BEST_EFFORT
  History (Depth): UNKNOWN
  Durability: TRANSIENT_LOCAL
  Lifespan: Infinite
  Deadline: Infinite
  Liveliness: AUTOMATIC
  Liveliness lease duration: Infinite

Subscription count: 1

Node name: altitude_monitor
Node namespace: /
Topic type: px4_msgs/msg/VehicleLocalPosition
Topic type hash: RIHS01_690ad535169297241c696494adbd98bbdc45566645026fe7963513a29a1bf144
Endpoint type: SUBSCRIPTION
GID: 01.0f.30.94.79.1b.2b.34.00.00.00.00.00.00.13.04
QoS profile:
  Reliability: BEST_EFFORT
  History (Depth): UNKNOWN
  Durability: VOLATILE
  Lifespan: Infinite
  Deadline: Infinite
  Liveliness: AUTOMATIC
  Liveliness lease duration: Infinite
```

送り手（PX4。信頼性 `BEST_EFFORT`・耐久性 `TRANSIENT_LOCAL`）と、受け手（自分のノード。信頼性 `BEST_EFFORT`・耐久性 `VOLATILE`）が並ぶ。履歴と深さは、ほかの参加者に伝わらない設定なので、`ros2 topic info -v` では、どちらも `UNKNOWN` と表示される（自分のノードの値は、3節のコードの `qos_profile_sensor_data` で決まる）。

送り手の `Topic type hash` は、フェーズ2の4-1節のとおり `INVALID` だが、受け手は、ROS 2のノードなので、型の指紋（`RIHS01_` で始まる値。型の定義から計算したもの）を知らせている。指紋が片方にしか無くても、型の名前が同じなので、つながる。`Lifespan`・`Deadline`・`Liveliness` は、この教材では使わないQoSの項目で、いずれも既定の値である。

## 5. QoSを既定に戻して、確かめる

T5のノードを Ctrl+C で止め、3節のコードの `qos_profile_sensor_data` を、`10` に書き換える。QoSの引数に数を書くと、「最後の10個を保つ」以外は、ROS 2の既定（信頼性 `RELIABLE`・耐久性 `VOLATILE`）になる。

```python
            self.on_position,
            10)
```

ビルドし直して、もう一度起動する。

```bash
# T5
cd ~/px4_ws

colcon build --packages-select drone_basics

source ~/px4_ws/install/setup.bash

ros2 run drone_basics altitude_monitor
```

**期待する結果**（時刻は実行ごとに変わる）:

```text
Starting >>> drone_basics
Finished <<< drone_basics [<time>]

Summary: 1 package finished [<time>]
[WARN] [1793452507.605395581] [altitude_monitor]: New publisher discovered on topic '/fmu/out/vehicle_local_position_v1', offering incompatible QoS. No messages will be received from it. Last incompatible policy: RELIABILITY
[INFO] [1793452508.579507972] [altitude_monitor]: 位置をまだ受け取っていない
[INFO] [1793452509.579197574] [altitude_monitor]: 位置をまだ受け取っていない
...
```

信頼性が合わないという警告が出て、位置が届かないので、「位置をまだ受け取っていない」が続く。警告の文は、フェーズ2の5節と同じで、ここでは、警告を出したのが自分のノード（`altitude_monitor`）である。警告は、送り手が見つかったときに1回出るだけで、その後は、ノードはエラーで止まらず、黙って待ち続ける点に注意する。QoSの合わない受け手は、つながらないだけで、エラーにはならない。確かめたら、Ctrl+Cで止め、コードを `qos_profile_sensor_data` に戻して、ビルドし直しておく。

Ctrl+Cで止めたときに、次のような表示が出て、`[ros2run]: Process exited with failure 1` で終わることがある（`<username>` は、各自のユーザー名。出ないこともある）。

```text
^CTraceback (most recent call last):
  File "/home/<username>/px4_ws/install/drone_basics/lib/drone_basics/altitude_monitor", line 33, in <module>
    sys.exit(load_entry_point('drone-basics==0.0.0', 'console_scripts', 'altitude_monitor')())
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/home/<username>/px4_ws/install/drone_basics/lib/python3.12/site-packages/drone_basics/altitude_monitor.py", line 46, in main
    rclpy.try_shutdown()
  File "/opt/ros/jazzy/lib/python3.12/site-packages/rclpy/utilities.py", line 100, in try_shutdown
    g_default_context.try_shutdown()
  File "/opt/ros/jazzy/lib/python3.12/site-packages/rclpy/context.py", line 139, in try_shutdown
    self.__context.shutdown()
rclpy._rclpy_pybind11.RCLError: failed to shutdown: rcl_shutdown already called on the given context, at ./src/rcl/init.c:333
[ros2run]: Process exited with failure 1
```

これは、3節の `main` の最後の `rclpy.try_shutdown()`（まだ終わっていなければ、ROS 2の通信を終える）が、終える処理をしようとしたときに、既に終わっていた（`rcl_shutdown already called`）、というエラーである。rclpyは、Ctrl+Cを受けると、自分でもROS 2の通信を終える。その処理と、`try_shutdown` の「まだ終わっていないかを確かめてから終える」処理が、ほぼ同時に走って重なると、確かめた直後に先を越されて、このエラーになると考えられる（ROS 2 Jazzyの `rclpy` の `context.py` の `try_shutdown`）。重なるかどうかは、そのときの処理の順番しだいなので、出たり出なかったりする。3節の `main` は、ROS 2 Jazzyの公式のサンプル（`demo_nodes_py` の `listener`）と同じ形で、終わるときにだけ出る表示なので、ノードの動きには影響しない。

## 6. QoSの組み合わせのまとめ

QoSの項目のうち、この教材で使うのは次の3つである。

| 項目 | 選べる値 | 意味 |
|---|---|---|
| 信頼性（Reliability） | `RELIABLE` / `BEST_EFFORT` | 届かなかったデータを送り直すか（`RELIABLE`）、送り直さないか（`BEST_EFFORT`） |
| 耐久性（Durability） | `TRANSIENT_LOCAL` / `VOLATILE` | 後からつないだ受け手にも、送り手が最後のデータを渡すか（`TRANSIENT_LOCAL`。受け手も `TRANSIENT_LOCAL` を求めた場合だけ渡す）、渡さないか（`VOLATILE`） |
| 履歴（History）と深さ（Depth） | `KEEP_LAST` と数 | 最後のいくつのデータを保つか |

送り手と受け手がつながるかは、信頼性と耐久性で決まる。受け手が求めることを、送り手が約束していれば、つながる。

| 項目 | 送り手 | 受け手 | つながるか |
|---|---|---|---|
| 信頼性 | `RELIABLE` | `RELIABLE` / `BEST_EFFORT` | つながる |
| 信頼性 | `BEST_EFFORT` | `BEST_EFFORT` | つながる |
| 信頼性 | `BEST_EFFORT` | `RELIABLE` | つながらない（5節） |
| 耐久性 | `TRANSIENT_LOCAL` | `TRANSIENT_LOCAL` / `VOLATILE` | つながる |
| 耐久性 | `VOLATILE` | `VOLATILE` | つながる |
| 耐久性 | `VOLATILE` | `TRANSIENT_LOCAL` | つながらない |

PX4のトピックに当てはめると、次のようになる。

- **PX4から受け取る**（`/fmu/out/`）: 送り手は `BEST_EFFORT`・`TRANSIENT_LOCAL`。受け手は `qos_profile_sensor_data`（`BEST_EFFORT`・`VOLATILE`）にする。
- **PX4へ送る**（`/fmu/in/`）: PX4の側の受け手は `BEST_EFFORT`・`VOLATILE`（PX4 v1.17のソースで確かめた）。送り手は、ROS 2の既定（`RELIABLE`・`VOLATILE`。上の表で、どちらも受け手と同じか、より強い約束）のままでつながる。フェーズ3では、送り手のQoSを `10`（既定）にする。

## 7. 止める

T5のノードを Ctrl+C で止める。T2のQGCのウィンドウを閉じ、T1のPX4のシミュレーション、T3のAgentの順に Ctrl+C で止める。

## 次へ

[フェーズ3](phase3_offboard.md)（ROS 2から指令して、機体を飛ばす）へ進む。

## 出典

- QoSの組み合わせの規則と、`qos_profile_sensor_data` の中身: ROS 2 Jazzyの文書（[About Quality of Service settings](https://docs.ros.org/en/jazzy/Concepts/Intermediate/About-Quality-of-Service-Settings.html)、Open Robotics、CC BY 4.0）を読んで、自分の言葉でまとめたもの。`qos_profile_sensor_data` の値は、ROS 2 Jazzyの `rclpy` で表示して確かめた。
- PX4のトピックのQoS: PX4 v1.17のソース [`src/modules/uxrce_dds_client/utilities.hpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/utilities.hpp)（送り手は `BEST_EFFORT`・`TRANSIENT_LOCAL`、受け手は `BEST_EFFORT`・`VOLATILE`）と、PX4 User Guide（v1.17、CC BY 4.0）の [ROS 2 User Guide](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/ros2/user_guide.md)（購読にセンサのデータ向けのQoSを使うこと）。
- サンプルのコードは、この教材で書いたもの（Apache License 2.0）。`main` の形は、親プロジェクトのフェーズ3-1のサンプルにそろえた。この形は、ROS 2 Jazzyの公式のサンプル（`demo_nodes_py` の `listener`、0.33.11。aptで入るもの）の `main` と同じである。
- 5節の、Ctrl+Cで止めたときの例外の説明: ROS 2 Jazzyの `rclpy`（7.1.12。aptで入るもの）の `rclpy/context.py` の `try_shutdown` と `rclpy/__init__.py` の `init`（Ctrl+Cを受ける処理を入れること）を読んで、自分の言葉でまとめたもの。
