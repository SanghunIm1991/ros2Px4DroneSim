# ros2Px4DroneSim

PX4・Gazebo・ROS 2を使い、3Dの環境でドローンを飛ばし、障害物をセンサで検知したら経路計画を更新するシミュレーションを、WSL2 + Ubuntu 24.04 + ROS 2 Jazzyで段階的に組み立てる学習教材です。

> **作成中です。** 教材の本文（手順書）はまだありません。今あるのは、計画と記録の文書だけです。

## 親プロジェクトとの関係

この教材は、ROS 2の最低限の構成で、フィジカルAIの開発に必要な技術スタックを一通り身に着ける教材 [ros2MinimalPhysicalAi](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi)（以下「親プロジェクト」）から派生したものです。ROS 2の基礎（ワークスペースとパッケージ・ノード・launch等）は親プロジェクトの手順書を参照し、この教材では、ドローンに固有の用語の解説・環境構築と、既存のパッケージを活用したシミュレーションの組み立てを扱います。

## 計画と記録の文書

| 文書 | 内容 |
|---|---|
| [docs/handoff_from_parent.md](docs/handoff_from_parent.md) | 立ち上げの経緯・親プロジェクトから引き継いだ知見・未決事項 |
| [docs/qa_log.md](docs/qa_log.md) | 判断・承認の記録 |
| [docs/public_release_review.md](docs/public_release_review.md) | 公開前と更新のたびの点検の観点と実施記録 |

## ライセンス

- サンプルコードとコマンド: [Apache License 2.0](LICENSE-APACHE-2.0)
- 文章と図: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

詳しくは [LICENSE](LICENSE) を参照してください。著作権者は SanghunIm1991 です。
