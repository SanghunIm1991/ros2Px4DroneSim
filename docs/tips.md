# Tips集: 手順書の本文に入れなかった小さな補足

手順書（フェーズ）の本文に入れると流れが途切れる補足をまとめた資料である。どの項目も独立しているので、関係する手順書を読んでいて気になったときに、その項目だけを読めばよい。読まなくても、手順書は最後まで進められる（任意）。

- 対象: PX4 v1.17、ROS 2 Jazzy（Ubuntu 24.04）、Gazebo Harmonic。版に依存する記述は、この版の文書とソースで確かめた（末尾の出典）
- 所要目安: 1項目あたり10〜15分（読み物。コマンドの実行は無い）

> **出どころ**: 内容は、PX4 v1.17の文書とソース、MAVROSのリポジトリの文書、ROSの配布の一覧（rosdistro）を読んで確かめ、自分の言葉でまとめたもの。MAVROSは、この教材では導入しておらず、動かして確かめてはいない。

## 項目の一覧

| 節 | 項目 | 関係する手順書 |
|---|---|---|
| 1 | MAVROSとuXRCE-DDSの違い | フェーズ0の4節・6節・7節、フェーズ2、フェーズ3 |
| 2 | シミュレーション時刻: この教材が `use_sim_time` を使わない理由 | フェーズ0の4節、フェーズ2の4-2節、フェーズ4の5-2節、フェーズ6-1の2-4節 |

## 1. MAVROSとuXRCE-DDSの違い

### 1-1. 疑問: ROS 2からPX4を扱う道は1本だけか

フェーズ0の4節では、ROS 2の側からPX4を扱う道を、uXRCE-DDSの1本にそろえると書いた。PX4の文書を読むと、もう1本の道が出てくる。**MAVROS**である。MAVROSは、地上局と同じMAVLink（フェーズ0の6節）で機体とやり取りし、その中身をROS 2のトピックやサービスに直すパッケージである。どちらもROS 2からPX4を扱えるなら、何が違い、どう使い分けるのか。この節では、その違いを整理する。

### 1-2. 2つの道の仕組み

**uXRCE-DDS**（フェーズ0の7節）は、PX4の中のuORBのトピックを、そのままROS 2のトピックとして出し入れする。PX4の中のクライアント（`uxrce_dds_client`）が、決めた一覧（`dds_topics.yaml`）のuORBのトピックを外へ出し、外から受け取る。ROS 2の側の型は、uORBの定義から作った `px4_msgs` で、値の中身も、時刻の2つの項目（2-2節）を除き、uORBと同じ（座標はNED・FRD）である。

**MAVROS**は、ROS 2のノードとして動き、シリアル・UDP・TCPのどれかで、機体とMAVLinkのメッセージをやり取りする。受け取ったMAVLinkのメッセージを、プラグイン（メッセージの種類ごとの変換の部品）が、ROS 2の標準の型（`sensor_msgs` 等）や、MAVROSの型（`mavros_msgs`）のトピックに直す。アーム・離陸・モードの切り替えなどの指示は、ROS 2のサービスとして呼べる。座標は、ROSの慣習のENU・FLUに直してから出す（逆向きも同じ）。PX4の側から見ると、MAVROSは、地上局と同じくMAVLinkで話す相手の1つである。SITLのPX4は、地上局とは別に、MAVSDKやMAVROSなどのプログラム向けに、UDPの14540番のポートへMAVLinkを送っている（フェーズ0の6節）。

一言でまとめると、uXRCE-DDSは「PX4の中の情報を、そのまま外に見せる道」で、MAVROSは「地上局と同じ言葉（MAVLink）で話し、それをROS 2の慣習に訳す道」である。

### 1-3. 違いの表

| 観点 | uXRCE-DDS（この教材） | MAVROS |
|---|---|---|
| 通る中身 | PX4の中のuORBのトピック | MAVLinkのメッセージ |
| PX4の側の部品 | `uxrce_dds_client`（SITLでは、Agentと8888番のポートでつながる） | `mavlink` のモジュール（地上局とつなぐものと同じ部品。SITLでは14540番のポートへ送る） |
| ROS 2の側に要るもの | Micro XRCE-DDS Agent（フェーズ2） | MAVROSのノード |
| ROS 2の側の型 | `px4_msgs`（PX4の版に合わせる。フェーズ0の7節） | ROS 2の標準の型と `mavros_msgs` |
| 座標 | NED・FRDのまま。ROS 2の慣習に合わせるなら、自分で変換する（フェーズ0の8-3節） | ENU・FLUに変換して出す |
| 扱えるデータの範囲 | `dds_topics.yaml` に書いたuORBのトピック。増やすには、一覧を変えてPX4をビルドし直す（間章「シミュレーションから実機へ」の3-3節） | MAVLinkに定義があり、プラグインが変換するメッセージ |
| 扱える機体 | PX4（`uxrce_dds_client` と `px4_msgs` は、PX4のもの。ArduPilotにも、XRCE-DDSでROS 2とつなぐ仕組みがあるが、トピックと型が違う） | MAVLinkを話す機体（PX4・ArduPilot等）。同じプログラムで両方を扱える |
| PX4との結び付きの深さ | uORBのトピックを直接、高い頻度で読み書きできる。ROS 2で、PX4の中のモードと同じように扱える飛行モード（外部のモード。C++のライブラリのPX4 ROS 2 Interface Libraryを使う）も作れる | MAVLinkで決まっている情報と指示の範囲 |
| 作っているところ | PX4の中のクライアントはPX4（Dronecode）、AgentはeProsima社（フェーズ2の2-2節）。PX4の文書が、ROS 2とつなぐ方法として説明している | MAVROSのプロジェクト。PX4の文書は、MAVROSでもつなげると紹介し、説明はMAVROSのプロジェクトに任せている |

PX4の文書は、ROS 2とPX4の組み合わせを、PX4と深く、遅れの少ない形で結び付けられるものとして強く勧め、その道としてuXRCE-DDSを説明している。MAVROSについては、PX4の文書は「ROS 2からはMAVROSでもつなげる。その方法はMAVROSのプロジェクトが支えている（PX4の文書では説明しない）」という扱いである。MAVROSは、ROS 2 Jazzyでも配布されている（ROSの配布の一覧に、Jazzy向けの `mavros` が登録されている。この教材では導入していない）。

### 1-4. 使いどころ

uXRCE-DDSが向くのは、次のような場合である。

- 機体のフライトスタックがPX4だけで、PX4の中の情報（推定の値・状態・センサの値等）を、高い頻度でそのまま扱いたい
- ROS 2の側で、新しい飛行モードを作りたい（外部のモード。間章「シミュレーションから実機へ」の4-3節）
- PX4の版に合わせて、型（`px4_msgs`）をそろえる手間を受け入れられる

MAVROSが向くのは、次のような場合である。

- PX4とArduPilotの両方の機体を、同じROS 2のプログラムで扱いたい
- MAVROSで書いた既存のプログラム（ROS 2の前の世代のROS 1の時代のものを含む）を生かしたい
- ROS 2の標準の型とENUの座標で、そのまま受け取りたい（変換を自分で書きたくない）
- 地上局とのやり取りと同じMAVLinkの経路に、ROS 2をつなぎたい

### 1-5. この教材がuXRCE-DDSにそろえた理由

この教材は、PX4だけを扱い、PX4の文書が説明している道にそろえた。理由は3つある。

1. **PX4の中と外で、対応するトピックが見える**: フェーズ1でPX4のシェルの `listener` で見たuORBのトピック（`vehicle_local_position` 等）が、フェーズ2では `/fmu/out/` の下に見える。名前の末尾に版の印が付くことがあり（`/fmu/out/vehicle_local_position_v1` 等。フェーズ0の7節）、時刻の2つの項目はPCの時計に直される（2-2節）が、ほかの中身は同じである。PX4の中の仕組み（フェーズ0の3-2節）と、ROS 2から見えるものが一続きになるので、学ぶ順番として分かりやすい。
2. **座標の違いを、自分の手で扱う**: uXRCE-DDSは座標を変換しないので、ENUとNEDの変換を、自作のノードの中で書く（フェーズ3・6）。座標の取り違えは、ドローンでよく起きる誤りであり（フェーズ0の8-3節）、変換を一度自分で書くことは、MAVROSのように変換してくれる道具を使うときにも役立つ。
3. **道を1本にする**: ROS 2からPX4への道を1本にしておくと、何かがおかしいときに、どの道を通った指令かを考えずに済む。MAVLinkの道は、地上局（QGroundControl）だけが使う。

MAVROSを使う教材も多い。MAVROSで書かれた例を読むときは、座標がENU・FLUに直されていること、アームやモードの切り替えの指示がサービスの形であることに注意すれば、この教材のノードと対応を付けられる。

## 2. シミュレーション時刻: この教材が `use_sim_time` を使わない理由

### 2-1. 時計が2つある

シミュレーションには、時計が2つある。PCの時計（ふつうの時刻。壁の時計と同じように進む）と、**Gazeboの時計**（シミュレーションが始まってからの、シミュレーションの中の時間）である。シミュレーションが現実と同じ速さで進めば、2つの時計は同じ速さで進む。PCの計算が追い付かないと、Gazeboの時計はPCの時計より遅く進む。その比が、Gazeboの画面の右下のRTFである（フェーズ1の3節）。

ROS 2のノードは、既定では、PCの時計で時刻を付け、タイマーを動かす。パラメータ `use_sim_time` を `true` にすると、ノードは、`/clock` のトピックで届くシミュレーションの時計を使うようになる。この仕組みの詳しい説明は、親プロジェクトの [Tips集](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/tips.md) の1節（シミュレーション時刻）にある。

### 2-2. PX4の時計とGazeboの時計

SITLのPX4は、自分の時計を、Gazeboの時計に合わせて進める。PX4の中のGazeboとつなぐモジュール（`gz_bridge`）が、Gazeboの時計（`/world/<ワールドの名前>/clock`）を受け取るたびに、PX4の時計をその値にそろえている。フェーズ0の4節で、PX4とGazeboが足並みをそろえて進む（ロックステップ）と書いたのは、この仕組みのことである（PX4のROS 2のユーザーガイドは、古いGazebo Classicのロックステップとはやり方が違うとも書いているが、PX4の時計がGazeboの時計と足並みをそろえて進む点は同じである）。PCが重くてGazeboが遅れても、PX4の時計も同じだけ遅れるので、PX4の制御は乱れない。

PX4とROS 2の間では、uXRCE-DDSの時刻合わせ（パラメータ `UXRCE_DDS_SYNCT`。既定で有効）が働く。PX4は、Agent（PCの時計）と自分の時計のずれを測り、次のように直す。

- PX4からROS 2へ出すとき: `timestamp` と `timestamp_sample` を、PCの時計の値に直す（フェーズ2の4-2節）
- ROS 2からPX4が受け取るとき: 同じ2つの項目を、PX4の時計の値に直す（直した値が今より先になるときは、今の時刻にする。値が0のときも、受け取った時刻を入れる）

そのため、自作のノードは、PX4へ送る指令の `timestamp` を、PCの時計で付ければよい（フェーズ3の `now_us()`）。

### 2-3. この教材の選び方

この教材では、ROS 2の側の時計をすべて、PCの時計にそろえた。

- 自作のノードとNav2は、既定のまま、PCの時計を使う（`use_sim_time` を使わない）
- PX4とROS 2の間は、2-2節の時刻合わせに任せる
- Gazeboから `ros_gz_bridge` で出すLiDARの値だけは、時刻がGazeboの時計になっている（フェーズ4の5-2節）。そこで、中継のパラメータ `override_timestamps_with_wall_time` で、PCの時計の値に付け替える（フェーズ6-1の2-4節）

もう1つのやり方は、ROS 2の側をすべて、Gazeboの時計にそろえることである。PX4の文書によると、その場合は、`/clock` を `ros_gz_bridge` で中継し、すべてのノードで `use_sim_time` を `true` にし、さらにPX4の側で、uXRCE-DDSの時刻合わせ（`UXRCE_DDS_SYNCT`）を止める。そうすると、Gazeboの時計が、ROS 2とPX4の両方のただ1つの時計になる。PX4の文書は、RTFが1から離れるときや、ROS 2がGazeboと直接やり取りするときに、このやり方が理にかなうとしている。この教材も `ros_gz_bridge` でGazeboと直接やり取りするが、Gazeboから受け取るのはLiDARの値だけなので、その時刻を付け替えることで、PCの時計にそろえる形に収めた。

この教材がPCの時計を選んだ理由は、次のとおりである。

1. **変える場所が少ない**: PCの時計なら、変えるのは中継の1つのパラメータだけである。Gazeboの時計にそろえると、すべてのノード（Nav2の部品を含む）の設定と、PX4のパラメータ（変えたら起動し直しが要る）を変えることになり、1つでも忘れると時刻が食い違う。
2. **PX4の手本と同じ**: PX4の文書の手本（ROS 2のユーザーガイドとオフボード制御の例）は、PCの時計を使う形で書かれている。フェーズ3のノードは、この形にならった。
3. **実機の形に近い**: 実機には、Gazeboの時計が無い。ノードはコンパニオンコンピュータの時計を使い、PX4との間はuXRCE-DDSの時刻合わせが、時計のずれ・進み方の違い・通信の遅れを測って補う（フェーズ2の3節の「実機では」）。PCの時計にそろえる形は、この形とほとんど同じで、実機でふつう要らなくなるのは、LiDARの時刻の付け替えだけである（ドライバの時刻の付け方による。フェーズ4の8節）。

### 2-4. 気をつける点: RTFが100 %から離れるとき

PX4の文書は、PCの時計を使うやり方は、RTFが1（100 %）にとても近いときにだけ使える、としている。PX4の文書は理由を書いていないが、RTFが下がると、PX4と機体の動き（Gazeboの時計で進む）と、ノードのタイマー（PCの時計で進む）の進み方がずれるためと考えられる（筆者の整理）。たとえば、RTFが50 %のとき、ノードが0.5秒ごとに経路を計画し直すと、シミュレーションの中では0.25秒ごとに計画し直していることになる。

PCが重くてRTFが大きく下がるときは、次を考える。

- ほかの重いプログラムを閉じる、Gazeboを画面なしで起動する（`HEADLESS=1 make px4_sitl gz_x500` のように、PX4の起動のコマンドの前に `HEADLESS=1` を付ける。Gazeboのウィンドウが開かなくなる。フェーズ1の3節）など、PCの負荷を下げて、RTFを100 %に近づける（どれだけ上がるかはPCによる）
- それでも足りないときは、2-3節のもう1つのやり方（すべてをGazeboの時計にそろえる）に切り替える。PX4の文書も、RTFが1から離れるときは、こちらのやり方を挙げている

この教材の手順書は、RTFが100 %に近い状態を前提に、表示の例と周期を書いている。

## 出典

この資料の技術的な記述は、次の文書とファイルを読んで、自分の言葉でまとめたもの（逐語の転載ではない）。

- PX4 User Guide（v1.17。[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)、Dronecode/PX4）: [ROS 2](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/ros2/index.md)（ROS 2との組み合わせを勧める記述、XRCE-DDSの代わりにMAVROSでもつなげること、MAVROSはMAVROSのプロジェクトが支えていること）、[ROS 2 User Guide](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/ros2/user_guide.md) の「ROS, Gazebo and PX4 time synchronization」（2-3節・2-4節の2つのやり方、RTFの条件、`/clock` の中継と `use_sim_time`、`UXRCE_DDS_SYNCT` を止めること、Gazebo Classicのロックステップとの違い）、[Gazebo Simulation](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/sim_gazebo_gz/index.md)（ロックステップで動き、止められないこと）
- PX4 v1.17のソース: [`src/modules/simulation/gz_bridge/GZBridge.cpp`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/simulation/gz_bridge/GZBridge.cpp)（Gazeboの時計を受け取るたびに、PX4の時計をそろえること）、[`Tools/msg/templates/ucdr/msg.h.em`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/Tools/msg/templates/ucdr/msg.h.em) と [`src/modules/uxrce_dds_client/dds_topics.h.em`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/dds_topics.h.em)（出すときと受け取るときの `timestamp`・`timestamp_sample` の直し方）、[`src/modules/uxrce_dds_client/module.yaml`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/module.yaml)（`UXRCE_DDS_SYNCT` の既定値と、変えたら起動し直しが要ること）、[`ROMFS/px4fmu_common/init.d-posix/px4-rc.mavlink`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/ROMFS/px4fmu_common/init.d-posix/px4-rc.mavlink)（SITLの14540番のポート）
- [mavlink/mavros](https://github.com/mavlink/mavros/tree/ros2)（`ros2` ブランチ。BSD・GPLv3・LGPLv3の3つのライセンス）: `README.md` と `mavros/README.md`（MAVLinkをROS 2のトピック・サービスに直すこと、シリアル・UDP・TCPでつなぐこと、PX4とArduPilotで試されていること、プラグインの作り）、`docs/frames.md`（NEDとENUの変換）
- [ArduPilot/ardupilot](https://github.com/ArduPilot/ardupilot)（`master`）: `libraries/AP_DDS/README.md`（ArduPilotにも、Micro XRCE-DDSのクライアントでROS 2とつなぐ仕組みがあること）
- [ros/rosdistro](https://github.com/ros/rosdistro)（`jazzy/distribution.yaml`）: Jazzy向けに `mavros` が登録されていること
- 2-1節の `use_sim_time` の仕組み: 親プロジェクト [ros2MinimalPhysicalAi](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi) の Tips集の1節（CC BY 4.0、著作権者は同じ）へのリンクだけで、文章は写していない
