# ros2Px4DroneSim

PX4・Gazebo・ROS 2を使い、3Dの環境でドローンを飛ばし、障害物をセンサで検知したら経路計画を更新するシミュレーションを、WSL2 + Ubuntu 24.04 + ROS 2 Jazzyで段階的に組み立てる学習教材です。

> **作成中です。** 手順書は、フェーズ0（読み物）と環境構築のものがあります。

## 読む順番

| 順 | 文書 | 内容 | 前提 |
|---|---|---|---|
| 1 | [フェーズ0: ドローンとPX4の用語と仕組み](docs/phase0_drone_px4.md) | マルチコプターが飛ぶ仕組み、PX4の役割、SITL、飛行モード、MAVLinkとuXRCE-DDS、座標系、安全の仕組み、この教材の完成形（読み物。コマンドは実行しない） | なし |
| 2 | [環境構築](docs/setup_px4_gazebo.md) | WSL2・Ubuntu 24.04・ROS 2 Jazzyの上に、Gazebo・PX4（v1.17）・QGroundControlを導入する | WindowsのPC。WSL2とROS 2の詳しい説明は、親プロジェクトの [環境構築の手順書](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/setup_wsl2_ros2.md) の1〜5節 |

1と2は、どちらを先にしてもかまいません（環境構築の完了条件にPX4のシェルやQGroundControlが出てくるので、1を先に読むと分かりやすくなります）。続くフェーズ1〜6は、[学習計画](docs/learning_plan.md) に予定を書いています。

各手順書では、コマンドを実行する手順の直後に「期待する結果」として、表示の例と、その読み方を載せています。実行の環境を用意せずに、読み物として読むこともできます。表示の出どころ（実際に確かめた表示か、仕様から想定した表示か）は、各手順書の冒頭に書いています。時刻・版の数字・パスなど、環境や実行ごとに変わる部分は、その旨を書いています。

## 親プロジェクトとの関係

この教材は、ROS 2の最低限の構成で、フィジカルAIの開発に必要な技術スタックを一通り身に着ける教材 [ros2MinimalPhysicalAi](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi)（以下「親プロジェクト」）から派生したものです。ROS 2の基礎（ワークスペースとパッケージ・ノード・launch等）は親プロジェクトの手順書を参照し、この教材では、ドローンに固有の用語の解説・環境構築と、既存のパッケージを活用したシミュレーションの組み立てを扱います。

## 計画と記録の文書

| 文書 | 内容 |
|---|---|
| [docs/idea_origin.md](docs/idea_origin.md) | 構想（目的・ゴール・6つの段階・技術を選んだ理由・先に確かめること） |
| [docs/learning_plan.md](docs/learning_plan.md) | 学習計画（各フェーズの内容・前提・完了条件、作る予定の手順書） |
| [docs/handoff_from_parent.md](docs/handoff_from_parent.md) | 立ち上げの経緯・親プロジェクトから引き継いだ知見・未決事項 |
| [docs/qa_log.md](docs/qa_log.md) | 判断・承認の記録 |
| [docs/public_release_review.md](docs/public_release_review.md) | 公開前と更新のたびの点検の観点と実施記録 |

## ライセンス

- サンプルコードとコマンド: [Apache License 2.0](LICENSE-APACHE-2.0)
- 文章と図: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

詳しくは [LICENSE](LICENSE) を参照してください。著作権者は SanghunIm1991 です。
