# 間章: 機体の模型を読み解き、自分でセンサを付ける

[学習計画](learning_plan.md) の間章（任意）。フェーズ1で使った機体 `x500` と、フェーズ4・5で使ったLiDAR付きの機体 `x500_lidar_2d`（フェーズ6でも使う）は、何が違うのかを、Gazeboの模型のファイル（SDF）を読んで確かめる。そのうえで、自分でセンサを付けた機体の模型を作る手順を、例として「真後ろも見える360°のLiDAR」を付けた機体を作りながら見ていく。

- 想定環境: [フェーズ5](phase5_collision_prevention.md) を終えたWSL2のUbuntu 24.04（フェーズ6は終えていなくてよい）
- 所要の目安: 1〜2コマ
- 必須の範囲: なし（任意の章）。読む場合は1〜6節（7節の課題は任意）
- 前提（親プロジェクト）: なし

> **この手順書の位置づけ**: フェーズ4の2-1節で見たLiDARの仕様と、フェーズ5の6-4節で見た「真後ろへは動けない」の理由を、模型のファイルの側から見直す。親プロジェクトの [間章（URDFとRViz2）](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/interlude_urdf_rviz.md) は、ロボットの形をURDFで書く話で、ここで扱うGazeboのSDFとは別の形式である（参考）。
>
> **期待する結果の出どころ**: （作成中）模型・ワールド・起動のスクリプトの中身は、PX4 v1.17のソース（`~/PX4-Autopilot`）で確かめた。この章で書く模型のファイルは、この教材で一から書いたもので、Gazeboのコマンド `gz sdf -k` で形式だけを点検し、まだGazeboで読み込んでいない。起動・トピック・RViz2・機体の動きの表示は想定したもので、実際に動かした表示に差し替える予定。

## 0. 学習目標と完了条件

この章を終えると、次のことができるようになる。

1. ワールドのファイルと機体の模型のファイルの役割の違いと、PX4の起動のときに、機体がワールドへ置かれる流れを説明できる（1節）。
2. `x500` と `x500_lidar_2d` の模型のファイルを読み、LiDARがどう付け足されているかを説明できる（2節）。
3. PX4が、Gazeboのセンサの値を、どのトピックの名前で受け取っているかを説明できる（3節）。
4. 自分でセンサを付けた機体の模型を書き、PX4のシミュレーションで使える（4節・5節）。

**完了条件**: 自分で書いた360°のLiDAR付きの機体で、RViz2に真後ろの向きの点が表示され、フェーズ5の衝突防止を有効にしたPosition modeで、真後ろへも動けることを確かめる（5節）。

この章で使うターミナルの番号は、フェーズ4の1節の表と同じである（T1がPX4のシミュレーション、T2がQGC、T3が中継、T4がコマンド、T5がRViz2）。

## 1. ワールドと機体は別のファイル

### 1-1. ワールドのファイルには、機体が入っていない

フェーズ4では、`make px4_sitl gz_x500_lidar_2d_walls` で、壁のワールドにLiDAR付きの機体が現れた。このため、「LiDAR付きの機体が置かれたワールドのファイルがある」と考えたくなる。しかし、PX4のソースのワールドのファイル（`~/PX4-Autopilot/Tools/simulation/gz/worlds/walls.sdf`）を開くと、地面・光・4枚の壁が書かれているだけで、機体は入っていない。フェーズ1の既定のワールド（`default.sdf`）も同じである。

Gazeboのファイルは、次のように役割が分かれている。

| ファイル | 置き場所（PX4のソースの中） | 何が書かれているか |
|---|---|---|
| ワールド | `Tools/simulation/gz/worlds/<ワールドの名前>.sdf` | 地面・光・障害物・物理の設定など、機体の周りの世界 |
| 機体の模型 | `Tools/simulation/gz/models/<模型の名前>/model.sdf` | 機体の形・重さ・モーター・センサ |
| PX4の機体の設定 | `ROMFS/px4fmu_common/init.d-posix/airframes/<番号>_gz_<模型の名前>` | PX4の側のパラメータと、使う模型の名前 |

`Tools/simulation/gz` のフォルダは、PX4の模型とワールドを集めた別のリポジトリ（[PX4-gazebo-models](https://github.com/PX4/PX4-gazebo-models)）を、PX4のリポジトリの中に取り込んだもの（Gitのサブモジュール）である。

### 1-2. 機体がワールドに置かれる流れ

`make px4_sitl gz_<模型の名前>_<ワールドの名前>` を実行すると、次の順に進む（PX4のソースの `src/modules/simulation/gz_bridge/CMakeLists.txt`、`ROMFS/px4fmu_common/init.d-posix/rcS`・`px4-rc.gzsim` による）。

| 順 | 何が起きるか |
|---|---|
| 1 | `make` が、環境変数 `PX4_SIM_MODEL=gz_<模型の名前>`・`PX4_GZ_WORLD=<ワールドの名前>` を付けて、PX4を起動する |
| 2 | PX4の起動のスクリプトが、名前が `<番号>_gz_<模型の名前>` の機体の設定のファイルを探し、その番号（`SYS_AUTOSTART`）の設定を読み込む |
| 3 | PX4の起動のスクリプトが、Gazeboをワールドのファイルだけで起動する |
| 4 | PX4の起動のスクリプトが、Gazeboのサービス `/world/<ワールドの名前>/create` を呼び、`models/<模型の名前>/model.sdf` の機体を、`<模型の名前>_0` という名前でワールドに追加する |
| 5 | PX4の中のGazeboとの中継（`gz_bridge`）が、その機体のセンサのトピックを受け取り、モーターの回転の指令を送り始める |

つまり、ワールドと機体は、起動のたびに組み合わせられる。`make` の対象の名前の後ろ半分を変えるとワールドが変わり、前半を変えると機体が変わる。フェーズ4のトピックの名前の中の `x500_lidar_2d_0` は、4の順で付けられた名前である。

Gazeboの側で、LiDARやカメラの値を計算する仕組み（センサのシステム）は、ワールドのファイルではなく、PX4が用意したGazeboのサーバの設定（`src/modules/simulation/gz_bridge/server.config`）で読み込まれる。Gazeboは、ワールドのファイルに仕組み（`<plugin>`）が書かれていないとき、このサーバの設定を使う。PX4のワールドのファイルには `<plugin>` が書かれていないので、どのワールドでもセンサが動く。

## 2. `x500` と `x500_lidar_2d` の違い

### 2-1. 模型のファイルを並べる

2つの機体の模型のファイルを開いて比べる。

```bash
# T4
cd ~/PX4-Autopilot/Tools/simulation/gz/models

cat x500_lidar_2d/model.sdf

head -6 x500/model.sdf
```

**期待する結果**（抜粋）:

```text
$ cat x500_lidar_2d/model.sdf
<?xml version="1.0" encoding="UTF-8"?>
<sdf version='1.9'>
  <model name='x500_lidar_2d'>
    <include merge='true'>
      <uri>x500</uri>
    </include>
    <include merge='true'>
      ...
      <uri>model://lidar_2d_v2</uri>
      <pose>.12 0 .26 0 0 0</pose>
    </include>
    <joint name="LidarJoint" type="fixed">
      <parent>base_link</parent>
      <child>link</child>
      <pose relative_to="base_link">-.1 0 .26 0 0 0</pose>
    </joint>
  </model>
</sdf>

$ head -6 x500/model.sdf
<?xml version="1.0" encoding="UTF-8"?>
<sdf version='1.9'>
  <model name='x500'>
    <include merge='true'>
      <uri>model://x500_base</uri>
    </include>
```

`x500_lidar_2d` の模型は、わずか十数行で、自分では機体の形を何も書いていない。次の3つを組み合わせているだけである。

| 部分 | 何をしているか |
|---|---|
| 1つ目の `<include>` | `x500` の模型を、まるごと取り込む |
| 2つ目の `<include>` | LiDARの部品の模型 `lidar_2d_v2` を、模型の原点（機体の真下の地面の高さ）から前へ0.12m、上へ0.26mの位置に取り込む |
| `<joint>` | 機体の本体（`base_link`）と、LiDARの部品（`link`）を、動かない関節（`fixed`）でつなぐ。つながないと、LiDARの部品は機体と別の物体になり、飛び立つ機体を置いて地面に落ちる |

`x500` の本体（`base_link`）の中心は、`x500_base` の模型の中で、模型の原点から0.24m上に置かれている。そのため、LiDARの部品は、本体の中心から見ると、前へ0.12m、上へ約0.02mの位置にある。`<joint>` の中の `<pose>` は、関節の軸の位置を表すもので、固定の関節では部品の位置に影響しない。

`merge='true'` は、取り込んだ模型の部品を、別の模型としてではなく、この模型の部品として直接並べる指定である。これで、`x500_lidar_2d` は、`x500` の部品（`base_link`・4つのプロペラ・モーターの仕組み）と、LiDARの部品（`link`）を持つ、1つの模型になる。`x500` 自身も、同じ形で、形と重さの模型 `x500_base` を取り込み、モーターの仕組み（プラグイン）を足したものである。

### 2-2. LiDARの部品の中身

LiDARの部品の模型（`lidar_2d_v2/model.sdf`）は、次のものからできている（フェーズ4の2-1節の表は、ここから読んだ）。

| 要素 | 何を表すか |
|---|---|
| `<link name="link">` | 部品そのもの。重さ（`<inertial>`）、ぶつかるときの形（`<collision>`）、見た目（`<visual>` のメッシュ）を持つ |
| `<sensor name="lidar_2d_v2" type="gpu_lidar">` | 部品に付いたセンサ。`type` の `gpu_lidar` は、画面の描画の仕組み（GPU）で距離を計算するLiDAR |
| `<ray>` の中の `<horizontal>` | 水平の向きの点の数（`samples` が1080）と、角度の範囲（`min_angle`・`max_angle` が±2.356ラジアン＝±135°） |
| `<range>` | 測れる距離（0.1〜30m）と、距離の細かさ |
| `<noise>` | 距離に足すばらつき（正規分布、標準偏差0.001m） |
| `<update_rate>` | 1秒あたりの走査の回数（30） |
| `<gz_frame_id>` | 値に付ける座標系の名前（`link`。フェーズ4の5-2節の `frame_id`） |

### 2-3. PX4の側の違い

PX4の機体の設定のファイルも比べる。

```bash
# T4
cat ~/PX4-Autopilot/ROMFS/px4fmu_common/init.d-posix/airframes/4013_gz_x500_lidar_2d
```

**期待する結果**（抜粋）:

```text
PX4_SIM_MODEL=${PX4_SIM_MODEL:=x500_lidar_2d}

. ${R}etc/init.d-posix/airframes/4001_gz_x500
```

LiDAR付きの機体の設定は、使う模型の名前を決めた後、`x500` の設定（4001番）をそのまま読み込むだけである。`${PX4_SIM_MODEL:=x500_lidar_2d}` は、環境変数 `PX4_SIM_MODEL` がまだ決まっていなければ `x500_lidar_2d` にする、というシェルの書き方で、すでに決まっていれば、その値を使う（4節で、この性質を使う）。

まとめると、2つの機体の違いは、Gazeboの模型にLiDARの部品があるかどうかだけで、PX4のパラメータは同じである。

## 3. PX4は、トピックの名前でセンサを見つける

PX4は、機体の設定のファイルで「この機体にはLiDARがある」と教わるわけではない。PX4の中のGazeboとの中継（`gz_bridge`）は、起動するときに、決まった名前のGazeboのトピックを購読する（PX4のソースの `src/modules/simulation/gz_bridge/GZBridge.cpp`）。2DのLiDARのトピックの名前は、次の形に決め打ちされている。

```text
/world/<ワールドの名前>/model/<機体の名前>/link/link/sensor/lidar_2d_v2/scan
```

`x500_lidar_2d` で起動すると、このトピックに値が流れるので、PX4は、フェーズ4の2-1節のとおり、値を5°ごとの区画にまとめて、衝突防止（フェーズ5）に使う。`x500` で起動しても、PX4は同じ形の名前（機体の名前が `x500_0` になる）のトピックを購読するが、値が流れてこないので、何も起きない（フェーズ5のつまずきやすい点の「前へ倒しても、まったく動かない」の状態になる）。この購読は、パラメータ `SIM_GZ_EN_LIDAR`（既定は1で有効）が有効なときに行われる。

このことから、自分でLiDARを付けるときの大事な点が分かる。PX4にもそのLiDARを使わせたい場合は、部品の名前を `link`、センサの名前を `lidar_2d_v2` にして、トピックの名前を、PX4が決め打ちしている形に合わせる。ROS 2でだけ使うなら、名前は自由に決めてよい（`ros_gz_bridge` で、実際のトピックの名前を指定すればよい）。

## 4. 360°のLiDARを付けた機体を作る

### 4-1. 何を作るか

フェーズ5の6-4節で見たとおり、`x500_lidar_2d` のLiDARは真後ろの90°を測らないので、衝突防止を有効にすると、真後ろへ動けない。ここでは、同じ位置に、360°を測るLiDARを付けた機体 `x500_lidar_360` を作る。

| 項目 | `x500_lidar_2d` | 作る `x500_lidar_360` |
|---|---|---|
| 取り付け位置（模型の原点から） | 前へ0.12m、上へ0.26m | 同じ |
| 部品の重さ | 0.37kg | 0.1kg |
| 角度の範囲 | ±135°（270°） | −180°〜約179.75°（360°） |
| 点の数 | 1080（約0.25°ごと） | 1440（0.25°ごと） |
| 距離・回数・ばらつき | 0.1〜30m、毎秒30回、0.001m | 同じ |
| 部品とセンサの名前 | `link`・`lidar_2d_v2` | 同じ（PX4にも使わせるため。3節） |
| 見た目 | 実物のLiDARのメッシュ | 簡単な円柱（メッシュのファイルを写さないため） |

点の数を1440にすると、PX4が5°ごとの区画にまとめたとき、ちょうど72区画（360°）になる。PX4の障害物までの距離の型（`obstacle_distance`）は72区画を持つので、すべての向きが埋まる。

### 4-2. 模型のフォルダを作る

模型は、PX4の模型のフォルダの中に、新しいフォルダとして作る。PX4の起動のスクリプトは、機体の模型を `Tools/simulation/gz/models/<模型の名前>/model.sdf` から読むためである（1-2節の4）。既存の模型のファイルは書き換えない。

```bash
# T4
mkdir -p ~/PX4-Autopilot/Tools/simulation/gz/models/x500_lidar_360
```

**期待する結果**: 何も表示されない。

このフォルダは、PX4-gazebo-modelsのサブモジュールの中に、Gitで管理されていないフォルダとして増える。PX4のフォルダで `git status` を実行すると、`Tools/simulation/gz (untracked content)` と表示される。また、PX4の `make distclean` や `make submodulesclean` は、サブモジュールの中の管理されていないファイルを消すので、このフォルダも黙って消える。4-3節と4-4節の2つのファイルは、控えを自分のワークスペース（例: `~/px4_ws/models/x500_lidar_360/`）にも取っておく。PX4を更新するときに邪魔になったら、このフォルダを消せば元に戻る。

PX4のフォルダの外に模型を置く方法は、この起動の仕組みでは使えない（PX4の起動のスクリプトが、模型の置き場所の環境変数 `PX4_GZ_MODELS` を、PX4の模型のフォルダに決め打ちで設定するため）。

### 4-3. 模型の説明のファイルを書く

`model.config` は、模型の名前と、本体のファイル（`model.sdf`）を書いた説明のファイルである。Gazeboは、模型が `model://x500_lidar_360` の形で参照されたときに、これを読む（PX4の起動のスクリプトは `model.sdf` を直接指定するので、5節の起動では読まれないが、模型のフォルダの決まりとして置いておく）。

ファイル: `~/PX4-Autopilot/Tools/simulation/gz/models/x500_lidar_360/model.config`

```xml
<?xml version="1.0"?>
<model>
  <name>x500_lidar_360</name>
  <version>1.0</version>
  <sdf version="1.9">model.sdf</sdf>
  <description>x500 with a 360-degree 2D lidar (learning example)</description>
</model>
```

### 4-4. 模型の本体を書く

ファイル: `~/PX4-Autopilot/Tools/simulation/gz/models/x500_lidar_360/model.sdf`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sdf version="1.9">
  <model name="x500_lidar_360">
    <!-- 機体はx500をそのまま取り込む -->
    <include merge="true">
      <uri>x500</uri>
    </include>

    <!-- LiDARの部品。PX4に使わせるため、名前はlinkにする -->
    <link name="link">
      <pose>0.12 0 0.26 0 0 0</pose>
      <inertial>
        <mass>0.1</mass>
        <inertia>
          <ixx>0.00005</ixx>
          <iyy>0.00005</iyy>
          <izz>0.00005</izz>
        </inertia>
      </inertial>
      <visual name="visual">
        <pose>0 0 0.03 0 0 0</pose>
        <geometry>
          <cylinder>
            <radius>0.03</radius>
            <length>0.06</length>
          </cylinder>
        </geometry>
      </visual>

      <!-- 360°のLiDAR。PX4に使わせるため、名前はlidar_2d_v2にする -->
      <sensor name="lidar_2d_v2" type="gpu_lidar">
        <gz_frame_id>link</gz_frame_id>
        <pose>0 0 0.055 0 0 0</pose>
        <update_rate>30</update_rate>
        <always_on>0</always_on>
        <visualize>false</visualize>
        <lidar>
          <scan>
            <horizontal>
              <samples>1440</samples>
              <resolution>1</resolution>
              <min_angle>-3.141593</min_angle>
              <max_angle>3.137230</max_angle>
            </horizontal>
          </scan>
          <range>
            <min>0.1</min>
            <max>30</max>
            <resolution>0.01</resolution>
          </range>
          <noise>
            <type>gaussian</type>
            <mean>0.0</mean>
            <stddev>0.001</stddev>
          </noise>
        </lidar>
      </sensor>
    </link>

    <!-- 機体の本体とLiDARの部品を、動かない関節でつなぐ -->
    <joint name="lidar_joint" type="fixed">
      <parent>base_link</parent>
      <child>link</child>
    </joint>
  </model>
</sdf>
```

- **`<include>`**: `x500_lidar_2d` と同じく、`x500` をまるごと取り込む（2-1節）。
- **`<link>`**: LiDARの部品を、自分で書く。位置（`<pose>`）は、模型の原点から測った値で、`x500_lidar_2d` と同じにした（2-1節）。`<inertial>` の重さと慣性は、小さな部品として適当な値にした（機体の約2kgに比べて十分に軽い）。`<visual>` は、見た目だけの円柱である。`<collision>` は書いていないので、この部品は、ほかの物にぶつからない（機体の本体の形で、ぶつかりは足りる）。
- **`<sensor>`**: 360°を測るLiDARである。`max_angle` を π（3.141593）ではなく3.137230にしたのは、−180°と180°が同じ向きで、点が重なるのを避けるためである。1440個の点の間の1439個の間隔で割ると、ちょうど0.25°ごとになる。`<lidar>` は、SDFの新しい版でのLiDARの書き方で、`lidar_2d_v2` が使っている古い書き方の `<ray>` と同じ中身を持つ。要素の並びと値は、`lidar_2d_v2` に倣った。
- **`<joint>`**: 本体（`base_link`）とLiDARの部品（`link`）を、動かない関節でつなぐ（2-1節）。

### 4-5. 確かめる前に

この模型には、PX4の機体の設定のファイルを作らない。2-3節のとおり、LiDAR付きの機体の設定（4013番）は、環境変数 `PX4_SIM_MODEL` が決まっていれば、その模型を使う。そこで、起動のときに、設定の番号を4013番に、模型の名前を `x500_lidar_360` に、環境変数で指定する（5-1節）。この方法では、`make px4_sitl gz_x500_lidar_360_walls` のような `make` の対象は使えない（`make` の対象は、機体の設定のファイルの一覧から作られるため）。`make` の対象として使いたい場合の手順は、6節にまとめる。

## 5. 作った機体で飛ばす

### 5-1. 起動する

フェーズ5と同じように、T1でPX4のシミュレーションを、T2でQGCを起動する。T1は、`make` ではなく、ビルド済みのPX4を、環境変数を付けて直接起動する。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

PX4_SYS_AUTOSTART=4013 PX4_SIM_MODEL=gz_x500_lidar_360 PX4_GZ_WORLD=walls GZ_IP=127.0.0.1 \
  ./build/px4_sitl_default/bin/px4

# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage
```

| 環境変数 | 意味 |
|---|---|
| `PX4_SYS_AUTOSTART=4013` | PX4の機体の設定を、4013番（LiDAR付きの機体）にする。この変数があると、PX4は、模型の名前から設定を探さない（1-2節の2を飛ばす） |
| `PX4_SIM_MODEL=gz_x500_lidar_360` | Gazeboに置く模型を、4節で作った模型にする |
| `PX4_GZ_WORLD=walls` | ワールドを、壁のワールドにする |
| `GZ_IP=127.0.0.1` | `make` の対象が付けていた値（フェーズ4の4節）を、自分で付ける |

**期待する結果**（T1の抜粋。想定）:

```text
env SYS_AUTOSTART: 4013
...
INFO  [init] Starting gazebo with world: /home/<ユーザー名>/PX4-Autopilot/Tools/simulation/gz/worlds/walls.sdf
...
INFO  [init] Spawning Gazebo model
...
INFO  [commander] Ready for takeoff!
```

Gazeboの画面に、上に小さな円柱を載せた機体が現れる。模型のファイルに誤りがあると、Gazeboが模型を読み込めず、`Spawning Gazebo model` の後に機体が現れない（つまずきやすい点）。

### 5-2. Gazeboのトピックと、ROS 2の値を見る

フェーズ4の4節・5節と同じ手順で、トピックを確かめ、ROS 2へ中継する。トピックの名前の中の機体の名前が、`x500_lidar_360_0` に変わる。

```bash
# T4
export GZ_IP=127.0.0.1

gz topic -l | grep lidar

# T3
export GZ_IP=127.0.0.1

ros2 run ros_gz_bridge parameter_bridge \
  /world/walls/model/x500_lidar_360_0/link/link/sensor/lidar_2d_v2/scan@sensor_msgs/msg/LaserScan[gz.msgs.LaserScan \
  --ros-args -r /world/walls/model/x500_lidar_360_0/link/link/sensor/lidar_2d_v2/scan:=/scan

# T4
ros2 topic echo /scan --once --no-arr
```

**期待する結果**（抜粋。想定）:

```text
$ gz topic -l | grep lidar
/world/walls/model/x500_lidar_360_0/link/link/sensor/lidar_2d_v2/scan
/world/walls/model/x500_lidar_360_0/link/link/sensor/lidar_2d_v2/scan/points

$ ros2 topic echo /scan --once --no-arr
header:
  ...
  frame_id: link
angle_min: -3.1415929794311523
angle_max: 3.1372299194335938
angle_increment: 0.004363324027508497
...
ranges: '<sequence type: float, length: 1440>'
...
```

トピックの名前が、3節のPX4が決め打ちしている形と一致していることを確かめる。`angle_min`・`angle_max` が4-4節の値、点の数が1440個になっている。

フェーズ4の6節と同じように、T5でRViz2を起動し、Fixed Frameを `link` にして `/scan` を表示する。

**期待する結果**（想定）: フェーズ4の6-2節と同じく、前の約4.4m先に壁1、左の約4.5m先に壁2の点の直線が出る。左の壁2の点の直線は、フェーズ4よりも後ろへ長く延びる（フェーズ4では、左後ろの135°より後ろは測っていなかった）。

### 5-3. 真後ろへ動けることを確かめる

フェーズ5の4節〜6節と同じ手順で、`CP_DIST` を2にし、仮想ジョイスティックを表示して、離陸してからPosition modeにする（フェーズ5の8節で `CP_DIST` を−1に戻していれば、もう一度設定する）。周りの空いた位置で、右の操縦桿を真下（真後ろ）へ倒す。

**期待する結果**（想定）: フェーズ5の6-4節では動かなかった真後ろへ、機体が動く。真後ろの向きにも距離の値があり、その向きに障害物が無いことが分かるので、衝突防止が動きを止めない。

もし動かない場合は、360°に広げたLiDARの光が、機体自身の部品（後ろのプロペラやアームなど）に当たっていないかを疑う。走査の面は、本体の中心から約0.075m上にあり、プロペラ（約0.06m上）のすぐ上を通る。5-2節の `ros2 topic echo` で `--no-arr` を外し、`ranges` の最初と最後のあたり（真後ろに近い向き）に、0.1〜0.4mほどの小さな値が並んでいないかを見る（つまずきやすい点）。

確かめたら、フェーズ5の8節のとおり、着陸させ、`CP_DIST` を−1に戻し、仮想ジョイスティックを無効にして、すべてを止める。

## 6. 恒久的な機体として登録する（参考）

4-5節の環境変数を使う方法は、PX4のソースの外のファイルを増やさず、手軽に試せる。何度も使う機体にするなら、PX4の文書（PX4 User Guide の「Adding a Model」）のとおり、次の手順で、PX4の機体として登録する。

1. 機体の設定のファイル `ROMFS/px4fmu_common/init.d-posix/airframes/<空いている番号>_gz_x500_lidar_360` を作る。中身は、2-3節の4013番と同じ形で、模型の名前を `x500_lidar_360` にする。
2. 同じフォルダの `CMakeLists.txt` の一覧に、そのファイルの名前を足す（一覧に載ったファイルだけが、ビルドのときにPX4の起動の場所へ写され、起動のスクリプトから見つけられる）。
3. PX4をビルドし直す。これで、`make px4_sitl gz_x500_lidar_360_walls` が使えるようになる。

この方法は、PX4のリポジトリのファイルを書き換えるので、PX4を更新するときに、自分の変更との食い違いを解決する手間が増える。この教材では、試すだけなら4-5節の方法で足りる。

ほかのセンサ（カメラ・深度カメラ・1方向の距離センサなど）も、同じ手順で付けられる。違うのは、`<sensor>` の `type` と中身、ROS 2へ中継するときの型（`ros_gz_bridge` の [README](https://github.com/gazebosim/ros_gz/blob/jazzy/ros_gz_bridge/README.md) の表）、PX4に使わせたい場合のトピックの名前（`GZBridge.cpp` で決め打ちされている名前）である。

## 7. 課題（任意）

1. 4-4節の `samples` を360に、`max_angle` を3.124139（πから1°を引いた値）にして、1°ごとに減らすと、PX4の区画のまとめ方（5°ごと）では、1区画が5点になる。RViz2の点の並びと、フェーズ5の衝突防止の止まり方が変わるかを予想し、確かめる。
2. `<noise>` の `stddev` を0.05にして、RViz2の壁の点の並びのばらつきが大きくなることを確かめる。フェーズ6を終えていれば、フェーズ6のコストマップ（障害物の地図）に、どんな影響が出そうかも考える。
3. 4-4節の `<pose>` の高さ（0.26）を0.6に上げ、Gazeboの画面とRViz2の見え方の違いを確かめる。重心より高い位置に部品を付けても、0.1kgなら飛び方がほとんど変わらないことを、フェーズ1の手順で離陸させて確かめる。

## つまずきやすい点

- **機体が現れない（`Spawning Gazebo model` の後に何も起きない）**: 模型のファイルを、Gazeboが読み込めていない。XMLの閉じ忘れや、タグの名前の誤りを確かめる。T1に、Gazeboの読み込みのエラーが出ていないかを見る。フォルダの名前と `PX4_SIM_MODEL` の `gz_` の後ろの名前が、同じかを確かめる。
- **機体は現れるが、LiDARのトピックが無い**: `<sensor>` が `<link>` の中に入っているかを確かめる。`gz topic -l | grep scan` で、別の名前で出ていないかを見る。
- **トピックはあるが、PX4の衝突防止が働かない**: トピックの名前が、3節の決め打ちの形と一字一句同じかを確かめる（部品の名前 `link`、センサの名前 `lidar_2d_v2`）。
- **離陸するとLiDARの部品だけが落ちる・離れる**: `<joint>` を書き忘れているか、`<parent>`・`<child>` の名前が違う。
- **後ろへ動けない・RViz2で機体のすぐ近くに点が出る**: LiDARの光が、機体自身の部品に当たっている（5-3節）。4-4節の `<link>` の `<pose>` の高さを、0.26から0.3程度に上げる。
- **フェーズ4・5の機体（`x500_lidar_2d`）に戻したい**: 環境変数は、そのターミナルで実行したコマンドにだけ効く。フェーズ4の起動のコマンド（`make px4_sitl gz_x500_lidar_2d_walls`）を、そのまま使えばよい。機体の設定の番号は同じ4013番なので、パラメータ（`CP_DIST` 等）は、そのまま引き継がれる（PX4は、設定の番号が変わったときだけ、パラメータを初期値に戻す）。

## 次へ

学習計画（[`docs/learning_plan.md`](learning_plan.md)）に戻る。この章で作った `x500_lidar_360` は、フェーズ6で使う機体の代わりにもできる（フェーズ6の5-1節のT1の起動を、この章の5-1節のコマンドに、T4の中継のトピックの名前を、この章の5-2節の名前に変える）。

## 出典

- ワールド・模型・機体の設定のファイルの中身と、起動の流れ: PX4 v1.17のソース（[PX4-Autopilot](https://github.com/PX4/PX4-Autopilot)、`release/1.17`、BSD 3-Clause License）の [`ROMFS/px4fmu_common/init.d-posix/rcS`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/ROMFS/px4fmu_common/init.d-posix/rcS)・[`px4-rc.gzsim`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/ROMFS/px4fmu_common/init.d-posix/px4-rc.gzsim)・[`src/modules/simulation/gz_bridge/`](https://github.com/PX4/PX4-Autopilot/tree/release/1.17/src/modules/simulation/gz_bridge) と、模型とワールド（[PX4-gazebo-models](https://github.com/PX4/PX4-gazebo-models)、各自のPCの `~/PX4-Autopilot/Tools/simulation/gz/`）を読んで、自分の言葉でまとめたもの。2節の模型のファイルと機体の設定のファイルの表示は、説明に必要な部分の抜粋である。
- 機体の登録の手順: PX4 User Guide（v1.17、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)、Dronecode/PX4）の [Gazebo Simulation](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/sim_gazebo_gz/index.md) の「Adding New Worlds and Models」を読んで、自分の言葉でまとめたもの。
- 4節の模型のファイル（`model.config`・`model.sdf`）は、この教材で一から書いたもの（Apache License 2.0）。LiDARのセンサの要素の並びと仕様の値は、`lidar_2d_v2` の模型（PX4-gazebo-models）に倣った。メッシュ等のファイルは写していない。
