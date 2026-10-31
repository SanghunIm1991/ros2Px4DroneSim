# フェーズ3-0: 自作のノードとQoSの復習

[学習計画](learning_plan.md) のフェーズ3（ROS 2から指令して、機体を飛ばす）の前に読む、短い復習のページ。フェーズ3では、この教材で初めて、自分でノードを書く。その前に、ノードの骨組み（購読・タイマー・ログ）と、PX4のトピックを受け取るためのQoSの指定を、機体の高さを表示するだけの小さなノードで確かめる。ノードの観察の仕方（`ros2 node`）も、ここで見る。

- 想定環境: [フェーズ2](phase2_ros2_observe.md) を終えたWSL2のUbuntu 24.04（ワークスペース `~/px4_ws` に、Agentと `px4_msgs` がビルドしてある）
- 所要の目安: 1コマ
- 必須の範囲: すべて
- 前提（親プロジェクト）: [フェーズ2](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase2_packages.md) の2-2節（Pythonパッケージを作る）・2-4節（ビルドする）・2-5節（環境に登録して実行する）

> **このページの位置づけ**: 親プロジェクトのフェーズ1（コマンドでの観察）とフェーズ3-1（PublisherとSubscriber）・3-2b（QoS）のうち、フェーズ3に要る部分を、ドローンの題材で書き直したもの。親プロジェクトのそれらのページは、前提にしない（さらに詳しく知りたい場合の参考）。
>
> **期待する結果の出どころ**: （作成中）サンプルのコードは、ROS 2のリンタ（`ament_flake8`）と、Pythonの文法の点検を通したもの。3節の `qos_profile_sensor_data` の値は、ROS 2 Jazzyの `rclpy` で表示して確かめた。ビルド・起動の表示は、ROS 2 Jazzyと `px4_msgs` の定義から想定したもので、まだ動かしていない。実際に動かした表示に差し替える予定。

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

## 2. パッケージを作る

`~/px4_ws/src` に、Pythonのパッケージ `drone_basics` を作る（`ros2 pkg create` の各オプションの意味は、親プロジェクトのフェーズ2の2-2節）。依存に `rclpy` と `px4_msgs` を入れ、実行ファイル `altitude_monitor` の雛形も作る。

```bash
# T4
cd ~/px4_ws/src

ros2 pkg create --build-type ament_python \
  --license Apache-2.0 \
  --maintainer-name learner --maintainer-email noreply@example.com \
  --dependencies rclpy px4_msgs \
  --node-name altitude_monitor \
  drone_basics
```

**期待する結果**（抜粋。想定）:

```text
going to create a new package
package name: drone_basics
...
dependencies: ['rclpy', 'px4_msgs']
node_name: altitude_monitor
...
creating ./drone_basics/drone_basics/altitude_monitor.py
```

`--node-name altitude_monitor` を付けたので、`setup.py` の `entry_points` に、実行ファイル `altitude_monitor` が登録された状態で作られる。次の3節で、雛形の `altitude_monitor.py` の中身を書き換える。

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

フェーズ2の3節と同じように、T1でAgent、T2でPX4のシミュレーション、T3でQGCを起動しておく。T4で、パッケージをビルドして、ノードを起動する。

```bash
# T4
cd ~/px4_ws

colcon build --packages-select drone_basics

source ~/px4_ws/install/setup.bash

ros2 run drone_basics altitude_monitor
```

**期待する結果**（想定。時刻と値は実行ごとに変わる）:

```text
[INFO] [<時刻>] [altitude_monitor]: 高さ: 0.01 m (NEDのz: -0.01)
[INFO] [<時刻>] [altitude_monitor]: 高さ: 0.01 m (NEDのz: -0.01)
...
```

機体が地面にいる間は、高さは0に近い。QGCで離陸させる（フェーズ1の5-1節）と、高さが上がり、離陸の高さ（10 ftなら約3m）で止まる。着陸させると、0に近い値に戻る。

ノードを動かしたまま、新しいターミナル（T5）で、ノードを観察する。T5でも、最初に `source ~/px4_ws/install/setup.bash` を実行する。

```bash
# T5
source ~/px4_ws/install/setup.bash

ros2 node list

ros2 node info /altitude_monitor
```

**期待する結果**（抜粋。想定）:

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
  ...
```

`ros2 node list` には、自分のノードだけが出る。PX4のトピックの送り手はAgentで、ROS 2のノードではないので、一覧に出ない（フェーズ2の4-1節の `_NODE_NAME_UNKNOWN_`）。`ros2 node info` の `Subscribers` に、購読しているトピックと型が出る。`/parameter_events` と `/rosout` は、すべてのノードが自動で持つトピックである（ログは `/rosout` にも送られる）。

購読のQoSを確かめる。

```bash
# T5
ros2 topic info -v /fmu/out/vehicle_local_position_v1
```

**期待する結果**（抜粋。想定）:

```text
Type: px4_msgs/msg/VehicleLocalPosition

Publisher count: 1
...
  Reliability: BEST_EFFORT
  ...
  Durability: TRANSIENT_LOCAL
...

Subscription count: 1

Node name: altitude_monitor
...
Endpoint type: SUBSCRIPTION
...
  Reliability: BEST_EFFORT
  History (Depth): UNKNOWN
  Durability: VOLATILE
...
```

送り手（PX4。信頼性 `BEST_EFFORT`・耐久性 `TRANSIENT_LOCAL`）と、受け手（自分のノード。信頼性 `BEST_EFFORT`・耐久性 `VOLATILE`）が並ぶ。履歴と深さは、ほかの参加者に伝わらない設定なので、`ros2 topic info -v` では `UNKNOWN` と表示される（自分のノードの値は、3節のコードの `qos_profile_sensor_data` で決まる）。

## 5. QoSを既定に戻して、確かめる

T4のノードを Ctrl+C で止め、3節のコードの `qos_profile_sensor_data` を、`10` に書き換える。QoSの引数に数を書くと、「最後の10個を保つ」以外は、ROS 2の既定（信頼性 `RELIABLE`・耐久性 `VOLATILE`）になる。

```python
            self.on_position,
            10)
```

ビルドし直して、もう一度起動する。

```bash
# T4
colcon build --packages-select drone_basics

ros2 run drone_basics altitude_monitor
```

**期待する結果**（想定）:

```text
[WARN] [<時刻>] [altitude_monitor]: New publisher discovered on topic '/fmu/out/vehicle_local_position_v1', offering incompatible QoS. No messages will be received from it. Last incompatible policy: RELIABILITY
[INFO] [<時刻>] [altitude_monitor]: 位置をまだ受け取っていない
[INFO] [<時刻>] [altitude_monitor]: 位置をまだ受け取っていない
...
```

信頼性が合わないという警告が出て、位置が届かないので、「位置をまだ受け取っていない」が続く。ノードはエラーで止まらず、黙って待ち続ける点に注意する。QoSの合わない受け手は、つながらないだけで、エラーにはならない。確かめたら、Ctrl+Cで止め、コードを `qos_profile_sensor_data` に戻して、ビルドし直しておく。

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

T4のノードを Ctrl+C で止める。T3のQGCのウィンドウを閉じ、T2のPX4のシミュレーション、T1のAgentの順に Ctrl+C で止める。

## 次へ

[フェーズ3](phase3_offboard.md)（ROS 2から指令して、機体を飛ばす）へ進む。

## 出典

- QoSの組み合わせの規則と、`qos_profile_sensor_data` の中身: ROS 2 Jazzyの文書（[About Quality of Service settings](https://docs.ros.org/en/jazzy/Concepts/Intermediate/About-Quality-of-Service-Settings.html)、Open Robotics、CC BY 4.0）を読んで、自分の言葉でまとめたもの。`qos_profile_sensor_data` の値は、ROS 2 Jazzyの `rclpy` で表示して確かめた。
- PX4のトピックのQoS: PX4 v1.17のソース [`src/modules/uxrce_dds_client/utilities.hpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/utilities.hpp)（送り手は `BEST_EFFORT`・`TRANSIENT_LOCAL`、受け手は `BEST_EFFORT`・`VOLATILE`）と、PX4 User Guide（v1.17、CC BY 4.0）の [ROS 2 User Guide](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/ros2/user_guide.md)（購読にセンサのデータ向けのQoSを使うこと）。
- サンプルのコードは、この教材で書いたもの（Apache License 2.0）。`main` の形は、親プロジェクトのフェーズ3-1のサンプルにそろえた。
