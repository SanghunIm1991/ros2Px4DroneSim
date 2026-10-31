# ros2Px4DroneSim

PX4・Gazebo・ROS 2を使い、3Dの環境でドローンを飛ばし、障害物をセンサで検知したら経路計画を更新するシミュレーションを、WSL2 + Ubuntu 24.04 + ROS 2 Jazzyで段階的に組み立てる学習教材です。

> **作成中です。** 下の「読む順番」の手順書は、主な表示を実際に動かして確かめたものです（一部の表示は想定のままで、[一覧](docs/pending_checks.md) にあります）。フェーズ4〜6と間章の手順書は下書きで、表示の多くが想定のままです（[学習計画](docs/learning_plan.md) の5節に一覧があります）。確かめ終えたものから、「読む順番」に加えます。

## 読む順番

| 順 | 文書 | 内容 | 前提 |
|---|---|---|---|
| 1 | [フェーズ0: ドローンとPX4の用語と仕組み](docs/phase0_drone_px4.md) | マルチコプターが飛ぶ仕組み、PX4の役割、SITL、飛行モード、MAVLinkとuXRCE-DDS、座標系、安全の仕組み、この教材の完成形（読み物。コマンドは実行しない） | なし |
| 2 | [環境構築](docs/setup_px4_gazebo.md) | WSL2・Ubuntu 24.04・ROS 2 Jazzyの上に、Gazebo・PX4（v1.17）・QGroundControlを導入する | WindowsのPC。WSL2とROS 2の詳しい説明は、親プロジェクトの [環境構築の手順書](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/setup_wsl2_ros2.md) の1〜5節 |
| 3 | [フェーズ1: PX4とGazeboで飛ばす](docs/phase1_first_flight.md) | PX4のシミュレーションとQGroundControlで、ドローンを離陸・移動・着陸させ、PX4のシェルでも離陸・帰還させて、飛行モードの移り変わりを見る（最初のゴール） | 1・2 |
| 4 | [フェーズ2: ROS 2から、機体の状態を見る](docs/phase2_ros2_observe.md) | PX4とROS 2をつなぐMicro XRCE-DDS Agentと `px4_msgs` をビルドし、機体の位置と状態を `ros2 topic` で見る。QoSの指定と、値がNEDであることを確かめる | 3。親プロジェクトの [フェーズ2](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase2_packages.md) の1-1節（ワークスペースの構成）・1-2節（ビルドと実行の流れ）・2-1節（ワークスペースを作る）・2-4節（ビルドする）・2-5節（環境に登録して実行する） |
| 5 | [フェーズ3-0: 自作のノードとQoSの復習](docs/phase3_0_node_qos.md) | 機体の高さを表示する小さなノードを書き、購読・タイマー・ログとQoSの指定、`ros2 node` での観察を確かめる | 4。親プロジェクトの [フェーズ2](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/phase2_packages.md) の2-2節（Pythonパッケージを作る）・2-4節（ビルドする）・2-5節（環境に登録して実行する） |
| 6 | [フェーズ3: ROS 2から指令して、機体を飛ばす](docs/phase3_offboard.md) | ROS 2のノードからオフボード制御の指令を送り、機体を離陸させ、経由点を順に回らせて着陸させる | 5（親プロジェクトの前提は5と同じ） |

1と2は、どちらを先にしてもかまいません（環境構築の完了条件にPX4のシェルやQGroundControlが出てくるので、1を先に読むと分かりやすくなります）。続くフェーズ4〜6と間章の手順書（下書き）は、[学習計画](docs/learning_plan.md) の5節に一覧があります。

各手順書では、コマンドを実行する手順の直後に「期待する結果」として、表示の例と、その読み方を載せています。実行の環境を用意せずに、読み物として読むこともできます。表示の出どころ（実際に確かめた表示か、仕様から想定した表示か）は、各手順書の冒頭に書いています。時刻・版の数字・パスなど、環境や実行ごとに変わる部分は、その旨を書いています。

## ターミナルの番号

各手順書では、同時に動かすプログラムごとに、別のターミナルを開きます。コマンドの例の `# T1` のような行は、どのターミナルで実行するかを示します。T1〜T4は、どの手順書でも同じプログラムに使い、使わない番号は飛ばします（開きません）。T5以降は、その手順書の作業（ビルド・自作のノード・`ros2` のコマンド・RViz2等）に使い、各手順書の冒頭の表（T1とT2だけを使う手順書では文）で割り振ります。

| ターミナル | 動かすもの | 使う手順書 |
|---|---|---|
| T1 | PX4のシミュレーション（PX4のシェルの `pxh>` もここ） | 環境構築の6節と、フェーズ1以降のすべて |
| T2 | QGroundControl | 環境構築の6節と、フェーズ1以降のすべて |
| T3 | Micro XRCE-DDS Agent（PX4とROS 2の中継） | フェーズ2・3-0・3・6と、Nav2の間章 |
| T4 | `ros_gz_bridge`（GazeboのLiDARの値をROS 2へ中継） | フェーズ4・5（課題）・6と、間章2つ |
| T5以降 | その手順書の作業 | 各手順書の表のとおり |

## 親プロジェクトとの関係

この教材は、ROS 2の最低限の構成で、フィジカルAIの開発に必要な技術スタックを一通り身に着ける教材 [ros2MinimalPhysicalAi](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi)（以下「親プロジェクト」）から派生したものです。ROS 2の基礎（ワークスペースとパッケージ・ノード・launch等）は親プロジェクトの手順書を参照し、この教材では、ドローンに固有の用語の解説・環境構築と、既存のパッケージを活用したシミュレーションの組み立てを扱います。

## 計画と記録の文書

| 文書 | 内容 |
|---|---|
| [docs/idea_origin.md](docs/idea_origin.md) | 構想（目的・ゴール・6つの段階・技術を選んだ理由・先に確かめること） |
| [docs/learning_plan.md](docs/learning_plan.md) | 学習計画（各フェーズの内容・前提・完了条件、作る予定の手順書） |
| [docs/handoff_from_parent.md](docs/handoff_from_parent.md) | 立ち上げの経緯・親プロジェクトから引き継いだ知見・未決事項 |
| [docs/qa_log.md](docs/qa_log.md) | 判断・承認の記録 |
| [docs/pending_checks.md](docs/pending_checks.md) | 手順書の期待する結果のうち、想定のままで、実際の表示で確かめる項目の一覧 |
| [docs/public_release_review.md](docs/public_release_review.md) | 公開前と更新のたびの点検の観点と実施記録 |

## ライセンス

- サンプルコードとコマンド: [Apache License 2.0](LICENSE-APACHE-2.0)
- 文章と図: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

詳しくは [LICENSE](LICENSE) を参照してください。著作権者は SanghunIm1991 です。
