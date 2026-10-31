# フェーズ4: センサの値を見る

[学習計画](learning_plan.md) のフェーズ4の手順書。2DのLiDAR（レーザーで周りの物までの距離を測るセンサ）を付けた機体を、壁のあるワールドで起動し、LiDARの値を `ros_gz_bridge` でGazeboからROS 2へ中継して、RViz2で壁の形として見る。ここで中継するLiDARの値は、フェーズ6で、障害物を見つけて経路を計画し直すときに使う。プログラムは書かない。

- 想定環境: [フェーズ3](phase3_offboard.md) を終えたWSL2のUbuntu 24.04
- 所要の目安: 1コマ
- 必須の範囲: 1〜8節（9節の課題は任意）
- 前提（親プロジェクト）: なし（`ros_gz_bridge` とRViz2の使い方は、この手順書で書く）

> **この手順書の位置づけ**: [フェーズ0](phase0_drone_px4.md) の4節の図の「ros_gz_bridge」の道（Gazeboの値を、PX4を通さずにROS 2へ出す道）を、実際に動かす。親プロジェクトにも、`ros_gz_bridge`（[フェーズ5-4](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase5_4_gazebo_plant.md)）と、RViz2（[間章](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/interlude_urdf_rviz.md)）の説明がある。どちらも車両の文脈が中心なので、前提にはせず、さらに詳しく知りたい場合の参考にする。
>
> **期待する結果の出どころ**: （作成中）機体・センサ・ワールドの中身と、Gazeboのトピックの名前は、PX4 v1.17のソースの模型のファイル（SDF）と起動のスクリプトで確かめた。`parameter_bridge` の引数の書き方は、ROS 2 Jazzyの `ros_gz_bridge` の使い方の表示で確かめた。起動・トピック・RViz2の表示は想定したもので、まだ動かしていない。実際に動かした表示に差し替える予定。

## 0. 学習目標と完了条件

この手順書を終えると、次のことができるようになる。

1. 2DのLiDARが測るもの（角度ごとの距離）と、ROS 2の型 [`sensor_msgs/msg/LaserScan`](https://github.com/ros2/common_interfaces/blob/jazzy/sensor_msgs/msg/LaserScan.msg) の項目の意味を説明できる（2節）。
2. PX4に付属するLiDAR付きの機体を、壁のワールドで起動できる（3節）。
3. Gazeboのトピックを `ros_gz_bridge` でROS 2へ中継し、`ros2 topic` で見られる（4節・5節）。
4. RViz2で、LiDARの値を障害物の形として表示できる（6節）。

**完了条件**（すべて満たしたら完了）:

1. `ros2 topic echo` で、`/scan` の値（角度の範囲と距離の範囲）が表示される（5節）。
2. 機体の周りの壁の形が、RViz2に点の並びとして表示される（6節）。
3. QGCで機体を離陸させて壁に近づけると、RViz2に表示される壁の位置が、機体から見た向きと距離に合わせて変わる（7節）。

## 1. 全体像

フェーズ2とフェーズ3では、PX4の中の値（位置・状態）を、Micro XRCE-DDS Agentを通してROS 2で受け取った。LiDARの値は、PX4ではなくGazeboが計算する。この手順書では、Gazeboの値を、PX4を通さずに、`ros_gz_bridge` という中継のノードで直接ROS 2へ出す（フェーズ0の4節の図）。

| 段 | 何をするか | この手順書で使うもの |
|---|---|---|
| Gazebo | 壁のワールドの中で、機体に付いたLiDARの値を計算し、Gazeboのトピックに出す | ワールド `walls`、機体 `x500_lidar_2d` |
| 中継 | Gazeboのトピックを受け取り、同じ値をROS 2のトピックとして出す | `ros_gz_bridge` の `parameter_bridge` |
| ROS 2 | 値を見る・表示する | `ros2 topic`、RViz2 |

この手順書では、5つのターミナルを使う。

| ターミナル | 動かすもの | 仮想環境 `~/px4-venv` |
|---|---|---|
| T1 | PX4のシミュレーション（`make px4_sitl gz_x500_lidar_2d_walls`） | 使う |
| T2 | QGroundControl | 使わない |
| T3 | `ros_gz_bridge`（中継） | 使わない |
| T4 | `gz` と `ros2` のコマンド | 使わない |
| T5 | RViz2 | 使わない |

LiDARの値を見るだけなら、Agentは要らない（フェーズ6で、PX4の値と合わせて使うときに、再び起動する）。

## 2. 2DのLiDARと、その値の型

### 2-1. 2DのLiDARが測るもの

2DのLiDARは、レーザーの向きを水平に回しながら、向きごとに、物に当たって返ってくるまでの距離を測る。1回転（または決まった角度の範囲）を測り終えると、「角度ごとの距離」の並びが1組できる。これを1回の走査（スキャン）と呼ぶ。測るのは、センサの高さの水平な面の上だけなので、その面より高い物や低い物は見えない。

この手順書で使う機体 `x500_lidar_2d` は、フェーズ1で使った `x500` の上に、2DのLiDARを載せたものである。PX4のソースの模型のファイル（`~/PX4-Autopilot/Tools/simulation/gz/models/lidar_2d_v2/model.sdf`）によると、LiDARの仕様は次のとおりである。

| 項目 | 値 |
|---|---|
| 測る角度の範囲 | 機首の向きを0として、左右に135°ずつ（合わせて270°。真後ろの90°は測らない） |
| 1回の走査の点の数 | 1080（約0.25°ごと） |
| 測れる距離 | 0.1〜30m |
| 走査の回数 | 毎秒30回 |
| Gazeboのトピック | `/world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan` |

Gazeboのトピックの名前は、ワールドの名前（`walls`）・機体の名前・センサの部品の名前・センサの名前をつないで、Gazeboが自動で決める。機体の名前の `x500_lidar_2d_0` は、PX4の起動のスクリプトが、模型の名前（`x500_lidar_2d`）にPX4のインスタンスの番号（1台だけなら0）を付けて決めたものである。

PX4も、このトピックを自分で受け取っている。PX4は、270°の距離を5°ごとの区画にまとめて、障害物までの距離として使う（フェーズ5の組み込みの衝突防止で使う）。

### 2-2. `sensor_msgs/msg/LaserScan`

1回の走査の値は、ROS 2では [`sensor_msgs/msg/LaserScan`](https://github.com/ros2/common_interfaces/blob/jazzy/sensor_msgs/msg/LaserScan.msg) の型で表す。主な項目は次のとおりである。

| 項目 | 意味 | この機体での値 |
|---|---|---|
| `header.frame_id` | 値がどの座標系の値か（座標系の名前。ここでは、センサが付いた部品の名前） | `link`（想定。5節で確かめる） |
| `angle_min`・`angle_max` | 最初と最後の点の角度（ラジアン） | 約−2.356・約2.356（−135°・135°） |
| `angle_increment` | 隣の点との角度の差（ラジアン） | 約0.0044（約0.25°） |
| `range_min`・`range_max` | 測れる距離の範囲（m） | 0.1・30.0 |
| `ranges` | 角度ごとの距離（m）の並び。`ranges[i]` は角度 `angle_min + i × angle_increment` の距離 | 1080個 |
| `intensities` | 角度ごとの、返ってきた光の強さ | 1080個 |

角度は、センサから見て前を0とし、左回り（上から見て反時計回り）を正にする。これは、フェーズ0の8節で見た、ROS 2の機体の座標系（FLU。前・左・上）に合わせた決まりである。`angle_min` の−135°は右の後ろ寄り、`angle_max` の135°は左の後ろ寄りに当たる。何にも当たらなかった向きの距離は、無限大（`inf`）になる。

## 3. LiDAR付きの機体を、壁のワールドで起動する

### 3-1. 壁のワールド

ワールド `walls` は、PX4に付属する、衝突防止を試すためのワールドである。PX4のソースのワールドのファイル（`~/PX4-Autopilot/Tools/simulation/gz/worlds/walls.sdf`）によると、高さ15mの壁が4枚ある。機体は原点に、東を向いて現れる（フェーズ1の3節）。位置はENU（東・北・上）で書く。

| 壁 | 中心の位置（東, 北） | 向き | 長さ | 機体から見て |
|---|---|---|---|---|
| 1 | (5, 0) | 南北に延びる | 20m | 正面（東）。機体に近い面は、機体の中心から4.5m先（LiDARは中心より約0.1m前に付いているので、LiDARからは約4.4m） |
| 2 | (−3, 5) | 東西に延びる | 10m | 左（北）。機体に近い面は4.5m先 |
| 3 | (13, −10) | 東西に延びる | 17m | 壁1の向こう側。ほぼ見えない（壁1の陰から外れる西の端だけが、右前の約11m先に数点出る） |
| 4 | (12, 0) | 南北に延びる | 20m | 壁1の向こう側。原点からは見えない |

壁はどれも厚さ1mである。原点の機体のLiDARには、正面の壁1と、左の壁2が見えるはずである。

### 3-2. 起動する

T1でPX4のシミュレーションを、T2でQGCを起動する。PX4の `make` の対象は、`gz_<機体の名前>_<ワールドの名前>` の形で、機体とワールドを同時に選べる（フェーズ1で使った `gz_x500` は、ワールドを省いて既定のワールドを使う形）。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl gz_x500_lidar_2d_walls

# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage
```

**期待する結果**（T1の抜粋。想定。`<ユーザー名>` は環境によって変わる）:

```text
INFO  [init] Starting gazebo with world: /home/<ユーザー名>/PX4-Autopilot/Tools/simulation/gz/worlds/walls.sdf
INFO  [init] Starting gz gui
...
INFO  [init] Spawning Gazebo model
...
INFO  [commander] Ready for takeoff!
```

`walls.sdf` が読み込まれ、Gazeboの画面に、灰色の壁と、上にLiDARを載せた機体が現れる。そのほかの行は、フェーズ1の2節（環境構築の6節）と同じである。LiDARの光は、Gazeboの画面には表示されない（模型の設定で、見えないようにしてある）。

## 4. Gazeboのトピックを見る

ROS 2へ中継する前に、Gazeboの側で、LiDARのトピックが出ていることを確かめる。Gazeboのトピックは、Gazebo自身の通信の仕組み（Gazebo Transport）で流れていて、`ros2 topic` では見えない。見るには、Gazeboのコマンド `gz topic` を使う。

```bash
# T4
export GZ_IP=127.0.0.1

gz topic -l | grep lidar
```

**期待する結果**（想定）:

```text
/world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan
/world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan/points
```

1行目が2-1節の表のトピックで、1回の走査の値（Gazeboの型 `gz.msgs.LaserScan`）が流れる。2行目は、同じ値を3次元の点の集まり（点群）にしたもので、この手順書では使わない。

`export GZ_IP=127.0.0.1` は、Gazeboの通信に使うネットワークの場所を、このPCの中だけ（127.0.0.1）にする設定である。PX4の `make` の対象（3-2節）は、Gazeboを `GZ_IP=127.0.0.1` で起動するので、Gazeboのトピックを見る・中継するターミナルでも同じ値にそろえる。`export` した値は、そのターミナルを閉じるまで有効である。

## 5. `ros_gz_bridge` でROS 2へ中継する

### 5-1. 中継を起動する

`ros_gz_bridge` は、GazeboのトピックとROS 2のトピックを中継するパッケージで、環境構築で入れた `ros-jazzy-ros-gz` に含まれる。その中の `parameter_bridge` は、引数で指定したトピックを中継するノードである。

```bash
# T3
export GZ_IP=127.0.0.1

ros2 run ros_gz_bridge parameter_bridge \
  /world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan@sensor_msgs/msg/LaserScan[gz.msgs.LaserScan \
  --ros-args -r /world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan:=/scan
```

引数の形は、`<トピック>@<ROS 2の型><向き><Gazeboの型>` である。向きの記号は、`[` がGazeboからROS 2へ、`]` がROS 2からGazeboへ、`@` が両方向である。ここでは、Gazeboの `gz.msgs.LaserScan` を、ROS 2の `sensor_msgs/msg/LaserScan` に直して、ROS 2へだけ流す。どの型どうしを直せるかは、`ros_gz_bridge` の [README](https://github.com/gazebosim/ros_gz/blob/jazzy/ros_gz_bridge/README.md) の表にある。

ROS 2のトピックの名前は、何もしなければGazeboのトピックと同じ長い名前になる。`--ros-args -r <元の名前>:=<新しい名前>` は、ROS 2の名前の付け替え（リマップ）の書き方で、ここでは `/scan` という短い名前にしている。

**期待する結果**（想定。時刻は実行ごとに変わる）:

```text
[INFO] [<時刻>] [ros_gz_bridge]: Creating GZ->ROS Bridge: [/world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan (gz.msgs.LaserScan) -> /world/walls/model/x500_lidar_2d_0/link/link/sensor/lidar_2d_v2/scan (sensor_msgs/msg/LaserScan)] (Lazy 0)
```

中継を作ったことを示す1行が出て、その後は何も表示されずに動き続ける。表示の中のROS 2の名前は、付け替える前の名前のままだが、実際には `/scan` に出る（次の5-2節で確かめる）。

### 5-2. ROS 2のトピックを見る

T4で、ROS 2のトピックとして見えることを確かめる。

```bash
# T4
ros2 topic list

ros2 topic hz /scan

ros2 topic echo /scan --once --no-arr
```

`ros2 topic hz` は、Ctrl+Cで止めてから、次のコマンドを実行する。`--no-arr` は、並びの項目（`ranges`・`intensities`）の中身を表示せず、個数だけを表示する指定である（1080個の数が流れて、ほかの項目が読めなくなるのを避ける）。

**期待する結果**（抜粋。想定。時刻・数は実行ごとに変わる）:

```text
$ ros2 topic list
/parameter_events
/rosout
/scan

$ ros2 topic hz /scan
average rate: 30.0
	min: 0.032s max: 0.035s std dev: 0.00080s window: 32

$ ros2 topic echo /scan --once --no-arr
header:
  stamp:
    sec: <秒>
    nanosec: <ナノ秒>
  frame_id: link
angle_min: -2.3561949729919434
angle_max: 2.3561949729919434
angle_increment: 0.004367367830127478
time_increment: 0.0
scan_time: 0.0
range_min: 0.1
range_max: 30.0
ranges: '<sequence type: float, length: 1080>'
intensities: '<sequence type: float, length: 1080>'
---
```

`/scan` が、毎秒約30回届いている（`ros2 topic hz` はPCの時計で数えるので、シミュレーションが実時間より遅く進んでいる（RTFが100%より小さい）と、30より小さくなる）。`angle_min`・`angle_max`・`range_min`・`range_max` は、2-1節の表の仕様と一致する。`angle_increment` は、270°（約4.712ラジアン）を、1080個の点の間の1079個の間隔で割った値である。`stamp` は、PCの時計ではなく、Gazeboの中の時計（シミュレーションが始まってからの時間）である。

PX4のトピックとは違い、ここでは受け手のQoSを気にしなくてよい。`parameter_bridge` は、ROS 2の既定のQoS（信頼性 `RELIABLE`）で送るので、既定のQoSの受け手（`ros2 topic echo` やRViz2）とそのまま合う（フェーズ3-0の6節の表）。

## 6. RViz2で見る

### 6-1. RViz2

RViz2は、ROS 2のデータを3次元の画面に表示する道具で、ROS 2 Jazzyの導入（desktop）に含まれる。距離の並びの数だけを見ても、周りの形は分かりにくい。RViz2に `LaserScan` を表示させると、角度と距離から点の位置を計算して、点を並べて描く。壁があれば、点が直線に並ぶ。

RViz2は、表示するすべてのデータを、1つの基準の座標系（固定フレーム、Fixed Frame）の上に描く。ふつうは、地図や機体の座標系を基準にし、センサの座標系との位置関係（座標の変換、TF）を別に流す。この手順書では、TFを流さず、LiDARの座標系（5-2節の `frame_id` の `link`）そのものを固定フレームにする。こうすると、LiDARの位置が画面の原点に固定され、機体から見た壁の形がそのまま表示される。

### 6-2. 表示する

```bash
# T5
rviz2
```

RViz2のウィンドウが開いたら、次の順に設定する。

1. 左の **Displays** の **Global Options** の **Fixed Frame** の欄（初めは `map`）をクリックし、`link` と入力して、Enterを押す。
2. 左下の **Add** を押し、開いた画面の **By topic** のタブで、`/scan` の下の **LaserScan** を選び、**OK** を押す。
3. **Displays** に足された **LaserScan** の左の三角を開き、**Size (m)** を `0.05` にする（初めの0.01では、点が小さくて見えにくい）。
4. もう一度 **Add** を押し、**By display type** のタブで **Axes** を選び、**OK** を押す。固定フレームの原点（LiDARの位置）に、座標の軸が表示される。赤がx（前）、緑がy（左）、青がz（上）である。

**期待する結果**（想定）: 軸の原点（LiDARの位置）から見て、前（赤い軸の向き。2-2節の角度0の向き）の約4.4m先に、左右に延びる点の直線が現れる。これが正面の壁1である。左（緑の軸の向き）の約4.5m先にも、前後に延びる点の直線が現れる。これが左の壁2である。右前の約11m先に、壁3の端が数点出ることがある。真後ろの90°には、点が無い（測っていない範囲）。そのほかの向きは、30m以内に何も無いので、点が無い。

**Global Options** の **Fixed Frame** の欄や **Global Status** に、`link` が見つからないという警告が出ることがある。TFを流していないためで、LiDARの点が表示されていれば、この手順書では問題ない。

画面の見え方は、マウスで変えられる（左のボタンを押したまま動かすと回転、ホイールで拡大・縮小、Shiftを押しながら左のボタンで平行移動）。Gazeboの画面では、Shiftを押しながら左のボタンが回転だった（フェーズ1の3節）ので、逆になることに注意する。上から見下ろす向きにすると、壁の形が分かりやすい。

## 7. 機体を動かして、壁の見え方の変化を見る

QGCで、フェーズ1の5節と同じように機体を離陸させる（初めの10 ftのままでよい。壁の高さは15mあるので、離陸した高さでも、LiDARの面は壁に当たる）。

離陸して止まったら、QGCの地図を最大近くまで拡大し、機体の北、約3mの地点をクリックして、**Go to location** で移動させる（フェーズ1の5-2節）。左の壁2の手前の面は北へ4.5mの位置なので、3mより北には移動させない（この段階の機体は、壁を避けない。避ける仕組みは、フェーズ5とフェーズ6で扱う）。ぶつけてしまったら、T1のPX4のシミュレーションを止めて、起動し直す。

PX4の既定の設定では、自動のモードで目標の地点が少し離れている（2mより遠い）と、機体は機首を目標の方へ向けてから進む（パラメータ `MPC_YAW_MODE` が0で「目標の方を向く」、`NAV_ACC_RAD` が2m）。そのため、この移動では、機体は北を向いてから北へ進む。

**期待する結果**（想定）: 機体が北を向くと、RViz2の表示が、軸の原点を中心に回る。左にあった壁2の点の直線は前（赤い軸の向き）に、前にあった壁1の点の直線は右（緑の軸の反対の向き）に移る。固定フレームがLiDARの座標系なので、画面の前は、常に機体の前である。機体が北へ進むにつれて、前の壁2の点の直線が原点に近づく（約4.5mから約1.4mへ）。移動の途中で機体が傾くと、LiDARの面も傾くので、点の並びが少し乱れたり、遠くの地面に当たった点が出たりする。

確かめたら、QGCの **Land** で着陸させる（フェーズ1の5-3節）。

## 8. 止める

T5のRViz2のウィンドウを閉じ、T3の `parameter_bridge` を Ctrl+C で止める。T2のQGCのウィンドウを閉じ、T1のPX4のシミュレーションを Ctrl+C で止める。

## 9. 課題（任意）

1. 5-2節の `ros2 topic echo` の `--no-arr` を外し、`--field ranges` を付けて、距離の並びを表示する。機体を原点に置いたまま（起動し直した直後）、並びの真ん中（540番目付近）の値が、正面の壁1までの距離（約4.4m）になっていることを確かめる。何番目が左の真横（90°）に当たるかを、`angle_min` と `angle_increment` から計算し、その値が左の壁2までの距離になっていることも確かめる。
2. フェーズ3-0を参考にして、`/scan` を購読し、正面（角度0の付近）の距離を毎回ログに出すノードを書く。QGCで機体を壁1に向かって近づけ、ログの距離が小さくなることを確かめる（7節と同じく、地図を拡大して指し、壁の手前1.5mより近くには移動させない）。

## つまずきやすい点

- **`gz topic -l` に何も出ない・LiDARのトピックが無い**: `export GZ_IP=127.0.0.1` を忘れていないかを確かめる。T1を、`gz_x500` ではなく `gz_x500_lidar_2d_walls` で起動したかを確かめる（T1に `walls.sdf` の行が出ているか）。
- **`/scan` は見えるが、`ros2 topic hz` に何も出ない**: T3で `export GZ_IP=127.0.0.1` をしていないと、中継がGazeboのトピックを受け取れない。T3の引数のトピックの名前が、4節の `gz topic -l` の表示と一字一句同じかを確かめる。
- **RViz2に点が出ない**: **Fixed Frame** が `link` になっているか、**LaserScan** の **Topic** が `/scan` になっているかを確かめる。点が小さすぎることもあるので、**Size (m)** を大きくしてみる。
- **LiDARの値がまったく出ない（専用のGPUが無いPC）**: GazeboのLiDARは、画面の描画の仕組み（GPU）を使って距離を計算する。GPUの描画が使えない環境では、値が出ないことがある。

## 次へ

学習計画（[`docs/learning_plan.md`](learning_plan.md)）のフェーズ5（組み込みの衝突防止を試す）へ進む。フェーズ5の手順書は、まだ作成中である。

## 出典

- LiDAR付きの機体（`x500_lidar_2d`）とセンサの仕様、壁のワールド（`walls`）の中身: PX4 v1.17に付属するGazeboの模型のファイル（各自のPCの `~/PX4-Autopilot/Tools/simulation/gz/` の下。[PX4-gazebo-models](https://github.com/PX4/PX4-gazebo-models) のリポジトリにある）を読んで、自分の言葉でまとめたもの。模型のファイルは、この教材には含めていない。
- 機体とワールドの選び方（`make` の対象の名前）: PX4 User Guide（v1.17、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)、Dronecode/PX4）の [Gazebo Vehicles](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/sim_gazebo_gz/vehicles.md) と [Gazebo Worlds](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/sim_gazebo_gz/worlds.md) を読んで、自分の言葉でまとめたもの。機体の名前の決まり方と、`GZ_IP` の値: PX4 v1.17のソースの [`ROMFS/px4fmu_common/init.d-posix/px4-rc.gzsim`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/ROMFS/px4fmu_common/init.d-posix/px4-rc.gzsim) と `src/modules/simulation/gz_bridge/CMakeLists.txt`。PX4がLiDARの値を5°ごとの区画にまとめること: 同じソースの [`src/modules/simulation/gz_bridge/GZBridge.cpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/simulation/gz_bridge/GZBridge.cpp)。
- `parameter_bridge` の引数の書き方: [`ros_gz_bridge`](https://github.com/gazebosim/ros_gz/blob/jazzy/ros_gz_bridge/README.md)（`jazzy`、Apache License 2.0、Open Source Robotics Foundation）のREADMEと、使い方の表示を読んで、自分の言葉でまとめたもの。
- `sensor_msgs/msg/LaserScan` の項目: ROS 2の [`common_interfaces`](https://github.com/ros2/common_interfaces)（`jazzy`、Apache License 2.0）の定義。
