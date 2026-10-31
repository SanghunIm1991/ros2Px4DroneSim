# 環境構築: Gazebo・PX4・QGroundControl（WSL2 + Ubuntu 24.04 + ROS 2 Jazzy）

WindowsのPCのWSL2（Windowsの上でLinuxを動かす仕組み）に入れたUbuntu 24.04とROS 2 Jazzyの上に、3Dの物理シミュレータのGazebo、ドローンのフライトコントローラのソフトウェアのPX4、地上局のソフトウェアのQGroundControlを導入する。[学習計画](learning_plan.md) の最初の作業で、ここで作った環境を、フェーズ1以降のすべての手順書で使う。

- 想定環境: Windows 11（WSL2が使えるWindows 10でもよい）。CPUの仮想化支援機能が有効であること
- 所要の目安: 半日程度（ダウンロードとPX4のビルドに時間がかかる。回線とPCの速さで大きく前後する）
- 必須の範囲: 2〜6節のすべて

> **この手順書の位置づけ**: WSL2・Ubuntu・ROS 2の導入（2節）は、親プロジェクトの [環境構築の手順書](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/setup_wsl2_ros2.md) と同じもので、ここには最低限の実行の手順だけを載せる。各手順の意味や、つまずいたときの詳しい対処は、そちらを読む。親プロジェクトの手順書で既にROS 2 Jazzyを導入している場合は、2節は2-4の確認だけでよい。PX4・Gazebo・QGroundControlの導入（3〜5節）は、この教材で書いたもの。PCとROS 2の導入から始める場合も、この手順書だけで進められる。
>
> **期待する結果の出どころ**: 2節の表示は、親プロジェクトの手順書と同じもの（そこでの注記のとおり、筆者の環境で確かめたものと、仕様から想定したものが混ざる）。3節の `gz sim --version` の表示と、4-1の仮想環境の表示、4-2のソースの取得の表示、4-3の導入のスクリプトの表示、4-4の2通りのGazeboの表示、4-5のビルドの表示、5節のQGroundControlの導入の表示、6節のT1とT2の表示は、筆者の環境で確かめたもの。版の数字・時刻・パスなど、環境や実行ごとに変わる部分は、その旨を各所に書いた。

## 0. 学習目標と完了条件

この手順書を終えると、次のことができるようになる。

1. WSL2のUbuntu 24.04で、ROS 2 Jazzyが動く（2節）。
2. ROS 2のパッケージとして入れたGazebo（Harmonic）の版を確かめられる（3節）。
3. PX4のソース（v1.17.0）を取得し、PX4専用のPythonの仮想環境の中で、PX4に付属する導入のスクリプトを実行し、PX4をビルドできる（4節）。
4. QGroundControlを、WSLの中で起動できる（5節）。

**完了条件**（すべて満たしたら完了）:

1. `ros2 run demo_nodes_cpp talker` と `ros2 run demo_nodes_py listener` の間でメッセージが届く（2-4）。
2. `make px4_sitl gz_x500` で、Gazeboの画面にドローン（`x500`）が現れ、PX4のシェルのプロンプト `pxh>` が表示される（6節）。
3. そのまま起動したQGroundControlが、シミュレーションの機体につながり、地図の上に機体が表示される（6節）。

## 1. 全体像

この手順書で入れるものと、置き場所は次のとおり。どれもWSLのUbuntuの中に入れる。

| 入れるもの | 何に使うか | 置き場所・入れ方 | 節 |
|---|---|---|---|
| ROS 2 Jazzy | ROS 2のノードとツール | aptのパッケージ（`/opt/ros/jazzy`） | 2節 |
| Gazebo Harmonic（ROS 2のパッケージ） | 3Dの物理シミュレータと、ROS 2とつなぐ道具（`ros_gz`） | aptのパッケージ `ros-jazzy-ros-gz`（`/opt/ros/jazzy` の下） | 3節 |
| PX4専用のPythonの仮想環境 | PX4のビルドに要るPythonのパッケージを、ROS 2のPythonと分けて入れる | `~/px4-venv` | 4-1 |
| PX4のソース（v1.17.0） | フライトコントローラのソフトウェア。PC上でシミュレーションとして動かす（SITL） | `~/PX4-Autopilot` | 4-2 |
| PX4のビルドの道具・Gazebo Harmonic（Gazebo公式のパッケージ） | PX4のビルドと、PX4のシミュレーションが使うGazebo | PX4の導入のスクリプトがaptで入れる | 4-3 |
| QGroundControl（v5.1.5） | 地上局のソフトウェア。機体の位置を地図で見て、離陸・移動・着陸を指示する | `~/qgc` にAppImage（1つのファイルで動くアプリの形）を置く | 5節 |

このほかに、PX4とROS 2をつなぐMicro XRCE-DDS Agentと、PX4のトピックの型（`px4_msgs`）はフェーズ2で、経路の計画に使うNav2はフェーズ6で入れる（使う直前に入れる）。

Gazebo Harmonicが、ROS 2のパッケージと、Gazebo公式のパッケージの2通りで入ることになる。どちらも同じ版の系列（Harmonic）で、4-4で、2通りが入ったことと、どちらが使われるかを確かめる。

PX4のビルドに要るPythonのパッケージを仮想環境に入れるのは、PX4の導入のスクリプトが、仮想環境の外では、Pythonのパッケージを `pip`（Pythonのパッケージの導入の道具）で `~/.local` に入れるためである。`~/.local` に入ったパッケージは、ROS 2がaptで入れたPythonのパッケージ（`numpy` 等）より優先して読み込まれ、版が違うと、ROS 2のPythonのノードが動かなくなることがある。仮想環境に入れておけば、ROS 2の側には影響しない。

## 2. WSL2・Ubuntu・ROS 2（最低限の手順）

詳しい説明・つまずいたときの対処は、親プロジェクトの [環境構築の手順書](https://github.com/SanghunIm1991/ros2MinimalPhysicalAi/blob/main/docs/setup_wsl2_ros2.md) の1〜5節にある。

### 2-1. WSL2とUbuntu 24.04（Windows側）

**管理者権限**のPowerShellで実行する。再起動を求められたら再起動し、Ubuntuの初回起動で、Linuxのユーザー名とパスワードを設定する（Windowsのアカウントとは別のもの）。

```powershell
wsl --install -d Ubuntu-24.04

wsl -l -v
```

**期待する結果**（`wsl -l -v`。表示の言語はWindowsの設定による）:

```text
  NAME            STATE           VERSION
* Ubuntu-24.04    Running         2
```

`VERSION` が `2` であればよい。

### 2-2. Ubuntuの更新（Ubuntuの中）

ここから先は、Ubuntuのターミナルで実行する。作業はホーム（`~`）の下で行う（`/mnt/c` などWindowsのドライブの下で作業すると、ビルドが非常に遅くなる）。

```bash
cd ~

sudo apt update && sudo apt upgrade

lsb_release -a
```

**期待する結果**（`lsb_release -a`。`Description` の末尾の小さな版数は、更新によって変わる）:

```text
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 24.04.1 LTS
Release:        24.04
Codename:       noble
```

`Release` が `24.04` であればよい。

### 2-3. ROS 2 Jazzy（Ubuntuの中・公式の手順）

ROS 2の公式の導入のページ（[Ubuntu (deb packages)](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html)）の手順に従う。下のコマンドは、親プロジェクトの手順書の4節（ROS 2の公式の文書から抜粋したもの）と同じで、コメントを省いた。ROS 2の文書は [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) で公開されている。版によって変わりうるので、**実行する前に公式のページと照らし、食い違いがあれば公式のページを正とする**。

ロケール（文字の扱いの設定）をUTF-8にする（`locale` の表示の `LANG=` が既に `UTF-8` で終わっていれば不要）。

```bash
sudo apt update && sudo apt install locales

sudo locale-gen en_US en_US.UTF-8

sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

export LANG=en_US.UTF-8
```

ROS 2のaptの取得元を追加する。

```bash
sudo apt install software-properties-common

sudo add-apt-repository universe

sudo apt update && sudo apt install curl -y

export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F'"' '{print $4}')

curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"

dpkg -I /tmp/ros2-apt-source.deb

sudo dpkg -i /tmp/ros2-apt-source.deb
```

`sudo dpkg -i` は、GitHubから取得したパッケージを管理者の権限で入れる操作なので、その前の `dpkg -I` の表示で、`Package:` が `ros2-apt-source` であることを確かめてから実行する。

開発の道具とROS 2の本体を入れ、新しいターミナルでもROS 2が使えるように `~/.bashrc` に読み込みの行を足す。

```bash
sudo apt update && sudo apt install ros-dev-tools

sudo apt upgrade

sudo apt install ros-jazzy-desktop

echo 'source /opt/ros/jazzy/setup.bash' >> ~/.bashrc

source ~/.bashrc
```

**期待する結果**: `apt install` は、入れるパッケージの一覧を表示し、`Do you want to continue? [Y/n]` と聞くので `Y` で進める。最後にエラー（`E:` で始まる行）が出ずにプロンプトへ戻れば成功。`echo` と `source` は何も表示しない。`~/.bashrc` に同じ行が既にある場合は、`echo` の行は実行しない（2回書かれても動くが、無駄になる）。

### 2-4. ROS 2の動作の確認

```bash
printenv ROS_DISTRO

# T1
ros2 run demo_nodes_cpp talker

# T2
ros2 run demo_nodes_py listener
```

**期待する結果**（時刻の数字は実行ごとに変わる）:

```text
$ printenv ROS_DISTRO
jazzy

# T1（talker）
[INFO] [1790072000.123456789] [talker]: Publishing: 'Hello World: 1'
[INFO] [1790072001.123456789] [talker]: Publishing: 'Hello World: 2'

# T2（listener）
[INFO] [1790072001.124567890] [listener]: I heard: [Hello World: 2]
```

T2に `I heard:` の行が出れば、ROS 2の通信が動いている。T1・T2とも Ctrl+C で止める。

## 3. Gazebo（ROS 2のパッケージ）

ROS 2 Jazzyと組み合わせて使うGazeboの版はHarmonicで、ROS 2のパッケージ `ros-jazzy-ros-gz` を入れると、Gazebo Harmonicの本体と、GazeboとROS 2をつなぐ道具（`ros_gz`。フェーズ4で使う `ros_gz_bridge` を含む）がまとめて入る。

```bash
sudo apt install ros-jazzy-ros-gz

gz sim --version
```

**期待する結果**（`gz sim --version`。小さな版数は更新によって変わる）:

```text
Gazebo Sim, version 8.15.0
Copyright (C) 2018 Open Source Robotics Foundation.
Released under the Apache 2.0 License.
```

`version 8.` で始まっていれば、Gazebo Harmonic（Gazebo Simの8番台）が入っている。`gz` が見つからない（`command not found`）場合は、`source /opt/ros/jazzy/setup.bash` を実行し直す（このパッケージの `gz` は、ROS 2の読み込みで使えるようになる）。

## 4. PX4

### 4-1. PX4専用のPythonの仮想環境

PX4のビルドに要るPythonのパッケージを入れる仮想環境（Pythonのパッケージを、ほかと分けて入れておく場所）を `~/px4-venv` に作り、有効にする。`--system-site-packages` は、仮想環境の中からも、aptで入れたPythonのパッケージを使えるようにする指定である。

```bash
python3 -m venv --system-site-packages ~/px4-venv

source ~/px4-venv/bin/activate

command -v python3
```

**期待する結果**（`<ユーザー名>` は各自のもの）:

```text
(px4-venv) $ command -v python3
/home/<ユーザー名>/px4-venv/bin/python3
```

プロンプトの先頭に `(px4-venv)` が付き、`python3` が仮想環境の中のものになっていれば、仮想環境が有効になっている。`python3 -m venv` が `ensurepip is not available` のエラーで止まる場合は、`sudo apt install python3-venv` を実行してからやり直す。

仮想環境は、ターミナルごとに有効にする。**PX4のビルドと起動（4-3・4-5・6節）の前には、毎回 `source ~/px4-venv/bin/activate` を実行する。** 止めるときは `deactivate` を実行する。`~/.bashrc` に有効にする行を書くと、ROS 2のノードを動かすターミナルでも仮想環境が有効になってしまうので、書かない。

### 4-2. PX4のソースの取得（v1.17.0）

PX4の公式の文書の手順（特定の版のソースを取る方法）に従って、ホームの下にPX4のソースを取得し、v1.17.0に切り替える。`make submodulesclean` は、PX4が中で使うほかのリポジトリ（サブモジュール）を、その版に合わせて取得し直す。

```bash
cd ~

git clone https://github.com/PX4/PX4-Autopilot.git

cd ~/PX4-Autopilot

git checkout v1.17.0

make submodulesclean

git describe --tags
```

**期待する結果**（抜粋。`git clone` の件数・容量・速さは、取得する時期と回線によって変わる）:

```text
$ git clone https://github.com/PX4/PX4-Autopilot.git
Cloning into 'PX4-Autopilot'...
...
Resolving deltas: 100% (432781/432781), done.

$ git checkout v1.17.0
Note: switching to 'v1.17.0'.

You are in 'detached HEAD' state. ...

HEAD is now at d6f12ad1c4 Update NuttX fmu-v6x config use with Zenoh (#26213)

$ make submodulesclean
Synchronizing submodule url for 'Tools/simulation/flightgear/flightgear_bridge'
...
Synchronizing submodule url for 'Tools/simulation/gz'
...
Submodule path 'Tools/simulation/gz': checked out 'b6127f4ec20de867e215fb5f78ae88b80f371909'
...
Submodule path 'test/fuzztest': checked out '1e47f9d7437de5c3ee4cb0ac860d5ec875478059'

$ git describe --tags
v1.17.0
```

`detached HEAD` は、ブランチではなく版の印（タグ）の位置にいることを示す表示で、異常ではない。`HEAD is now at d6f12ad1c4` の `d6f12ad1c4` は、v1.17.0のタグが指すコミットである。`make submodulesclean` は、サブモジュールごとに `Synchronizing ...` と `Submodule path ... checked out ...` の行を出す。`Tools/simulation/gz` は、Gazebo用の機体とワールドの模型が入ったサブモジュールで、6節で使う。`git describe --tags` が `v1.17.0` を示せばよい。`git clone` と `make submodulesclean` は、多くのファイルを取得するので時間がかかる（`git clone` だけで数百MBある）。

### 4-3. PX4の導入のスクリプト

4-1の仮想環境が有効なターミナルで、PX4に付属する導入のスクリプト `Tools/setup/ubuntu.sh` を実行する。`--no-nuttx` は、実機のフライトコントローラ（マイコン）に書き込むための道具を省く指定で、シミュレーションだけを使うこの教材では要らない。

```bash
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

bash ./Tools/setup/ubuntu.sh --no-nuttx
```

このスクリプトは、次のことを行う（v1.17.0のスクリプトを読んで確かめた）。

- aptで、PX4のビルドの道具を入れる（`sudo` のパスワードを聞かれる）。
- Gazebo公式のaptの取得元（`packages.osrfoundation.org`）を追加し、Gazebo Harmonic（`gz-harmonic`）を入れる。このとき「Earlier versions will be removed」（古い版は削除される）と表示するが、削除する処理は無い。3節で入れたROS 2のパッケージのGazeboは、そのまま残る。
- `pip` で、PX4のビルドに要るPythonのパッケージ（約30個）を入れる。仮想環境が有効なので、`~/px4-venv` の中に入る。

**期待する結果**（抜粋。時刻と、パッケージの数・版・容量は、取得する時期と、既に入っているものによって変わる。`<ユーザー名>` は各自のもの）:

```text
[ubuntu.sh] Starting...
[ubuntu.sh] arch: x86_64
[ubuntu.sh] Ubuntu 24.04
[ubuntu.sh] Installing PX4 general dependencies
[sudo] password for <ユーザー名>:
...
cmake is already the newest version (3.28.3-1build7).
...
2 upgraded, 56 newly installed, 0 to remove and 64 not upgraded.
...

[ubuntu.sh] Installing PX4 Python3 dependencies
...
  Attempting uninstall: numpy
    Found existing installation: numpy 1.26.4
    Not uninstalling numpy at /usr/lib/python3/dist-packages, outside environment /home/<ユーザー名>/px4-venv
    Can't uninstall 'numpy'. No files were found to uninstall.
...
ERROR: pip's dependency resolver does not currently take into account all the packages that are installed. This behaviour is the source of the following dependency conflicts.
scipy 1.11.4 requires numpy<1.28.0,>=1.21.6, but you have numpy 2.5.4 which is incompatible.
Successfully installed cerberus-1.3.8 ... numpy-2.5.4 ... pymavlink-2.4.50 ... pyulog-1.3.0 ...

[ubuntu.sh] Installing PX4 simulation dependencies
...
[ubuntu.sh] Gazebo (Harmonic) will be installed
[ubuntu.sh] Earlier versions will be removed
...
<日時> (<速さ>) - ‘/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg’ saved [1222/1222]

Get:1 http://packages.osrfoundation.org/gazebo/ubuntu-stable noble InRelease [4,273 B]
...
7 upgraded, 203 newly installed, 0 to remove and 57 not upgraded.
...
Setting up libgz-sim8:amd64 (8.15.0-1~noble) ...
...
Setting up gz-harmonic (1.0.0-1~noble) ...
...
Processing triggers for hicolor-icon-theme (0.17-2) ...
```

表示は長く、3つの段階（`[ubuntu.sh] Installing ...` の行で区切られる）に分かれる。

- **ビルドの道具（apt）**: 既に入っているものは `is already the newest version` と表示され、足りないもの（`ninja-build`・`ccache`・`gdb` 等）が入る。
- **Pythonのパッケージ（pip）**: `Not uninstalling numpy at /usr/lib/python3/dist-packages, outside environment .../px4-venv` は、aptで入れたnumpy（ROS 2が使うもの）には手を付けず、仮想環境の中に新しい版を入れた、という意味である。仮想環境を使った狙いどおりの動きである。続く `ERROR: ... scipy ... requires numpy<1.28.0 ...` は、仮想環境の中で、aptで入れたscipyと、新しく入れたnumpyの版が合わないことを知らせる表示で、導入の失敗ではない（直後に `Successfully installed` が出る）。この食い違いは仮想環境の中だけのものなので、仮想環境を有効にしていないターミナル（ROS 2のノードを動かすターミナル）には影響しない。4-1の「`~/.bashrc` に有効にする行を書かない」は、このためでもある。逆に、仮想環境を有効にしたターミナルでは、ROS 2のノードやツールを動かさない（新しいnumpyが読み込まれ、ROS 2のPythonのパッケージと合わないおそれがある）。
- **シミュレーションの道具（apt）**: Gazebo公式の取得元の鍵（`/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg`）を保存し、取得元（`packages.osrfoundation.org`）を追加して、`gz-harmonic` と、その部品（`libgz-sim8` 等。200個ほど）を入れる。「Earlier versions will be removed」と表示されるが、aptの集計は `0 to remove` で、何も削除されない。

最後の行は `Processing triggers ...` のようなaptの表示で、スクリプトは終わりの案内を出さずにプロンプトへ戻る。途中で止まらず、エラー（`E:` で始まるaptの行や、Pythonの `Traceback`）が出ずにプロンプトへ戻れば成功である。

スクリプトが終わったら、WSLを再起動する（入れたものを確実に反映させるため。PX4の公式の文書の手順）。Ubuntuのターミナルを `exit` で閉じ、Windowsの PowerShell で次を実行してから、Ubuntuのターミナルを開き直す。

```powershell
wsl --shutdown
```

**期待する結果**: 何も表示されない。開いていたUbuntuのターミナルはすべて閉じる。

### 4-4. 2通りのGazeboの確認

3節のGazebo（ROS 2のパッケージ）と、4-3のGazebo（Gazebo公式のパッケージ）が両方入ったことと、`gz` のコマンドがどちらを使うかを確かめる。

```bash
dpkg -l gz-harmonic | tail -1

which -a gz

gz sim --version
```

**期待する結果**（小さな版数は、取得する時期によって変わる）:

```text
$ dpkg -l gz-harmonic | tail -1
ii  gz-harmonic    1.0.0-1~noble amd64        Collection of Gazebo packages - Harmonic

$ which -a gz
/opt/ros/jazzy/opt/gz_tools_vendor/bin/gz
/usr/bin/gz
/bin/gz

$ gz sim --version
Gazebo Sim, version 8.15.0
Copyright (C) 2018 Open Source Robotics Foundation.
Released under the Apache 2.0 License.
```

`dpkg -l` の行が `ii` で始まれば、Gazebo公式のパッケージが入っている（`1.0.0` は、Harmonicの部品をまとめるパッケージの版で、Gazebo Simの版ではない）。`which -a gz` は、`gz` の候補を、使われる順に表示する。ROS 2を読み込んだターミナルでは、ROS 2のパッケージの `gz`（`/opt/ros/jazzy/...`）が先に使われる。`/usr/bin/gz` と `/bin/gz` は同じファイルである（Ubuntu 24.04では `/bin` が `/usr/bin` を指しているため、2回表示される）。`which -a gz` の先頭にROS 2のパッケージの `gz` が残り、4-3のaptの集計が `0 to remove` だったので、4-3の導入で、ROS 2のパッケージのGazeboは削除も置き換えもされていない。`gz sim --version` は3節と同じ8.15.0で、Gazebo公式のパッケージの中身（`libgz-sim8`）も同じ8.15.0である。どちらもHarmonic（8番台）なので、PX4のシミュレーションと、フェーズ4のROS 2との中継は、同じ系列のGazeboの間で動く見込みである（実際につながるかは、フェーズ4で確かめる）。

### 4-5. PX4のビルド

仮想環境を有効にして、PX4をシミュレーション用にビルドする。

```bash
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl
```

**期待する結果**（抜粋。時間・件数・版の数字は、環境と取得する時期によって変わる。`<ユーザー名>` と `<ホスト名>` は各自のもの）:

```text
-- PX4_GIT_TAG: v1.17.0
CMake Warning (dev) at CMakeLists.txt:176 (find_package):
  Policy CMP0148 is not set: The FindPythonInterp and FindPythonLibs modules
  are removed.  ...
-- Found PythonInterp: /home/<ユーザー名>/px4-venv/bin/python3 (found suitable version "3.12.3", minimum required is "3")
-- PX4 config: px4_sitl_default
-- PX4 platform: posix
-- PX4 lockstep: enabled
...
-- Looking for gz-transport13 -- found version 13.6.0
...
-- Looking for gz-sim8 -- found version 8.15.0
...
-- Looking for gz-sensors8-gpu_lidar -- found version 8.2.2
...
-- Configuring done (<秒数>s)
-- Generating done (<秒数>s)
-- Build files have been written to: /home/<ユーザー名>/PX4-Autopilot/build/px4_sitl_default
[0/1141] git submodule src/modules/uxrce_dds_client/Micro-XRCE-DDS-Client
...
[13/1141] Performing download step (git clone) for 'OpticalFlow'
...
[1141/1141] Linking CXX shared library src/examples/dyn_hello/examples__dyn_hello.px4mod
(px4-venv) <ユーザー名>@<ホスト名>:~/PX4-Autopilot$
```

ビルドは2段階で進む。

- **構成（`--` で始まる行）**: ビルドに使う道具と部品を探す。`PX4_GIT_TAG: v1.17.0` は、4-2で切り替えた版をビルドすることを示す。`Found PythonInterp: .../px4-venv/bin/python3` は、仮想環境のPythonを使うことを示す（仮想環境を有効にし忘れると、ここが `/usr/bin/python3` になり、足りないパッケージのエラーで止まることがある）。`gz-sim8` 等の行は、PX4とGazeboをつなぐ部品のために、Gazebo Harmonicの部品を見つけたことを示す（3節と同じ8.15.0）。`CMake Warning (dev)` は、PX4の開発者向けの警告で、ビルドには影響しない。
- **コンパイル（`[番号/総数]` の行）**: 総数（この版では1141前後）に向かって進む。途中で、一部の部品（`OpticalFlow` 等）をGitHubから取得する。初めてのビルドは時間がかかり、2回目からは変わったところだけをビルドするので速い。

最後の行が `[総数/総数]` で、エラー（`error:` や `FAILED:`）が出ずにプロンプトへ戻れば成功である。`make px4_sitl` はビルドだけで、PX4は起動しない（起動は6節で行う）。4-3の表示にあった、仮想環境の中のnumpyとscipyの版の食い違いは、ビルドでは問題にならない。

## 5. QGroundControl

QGroundControl（QGC）を、WSLの中で動かすLinux版のAppImageで入れる。PX4の公式の文書（WSLの環境のページ）は、WSLの中のLinux版を、シミュレーションにつなぐいちばん簡単な方法としている。開発中のビルドではなく、安定版のリリース（v5.1.5）を使う。

QGCの公式の導入の手順に従って、QGCの実行に要るライブラリを入れる。

```bash
sudo apt install -y libfuse2 libxcb-xinerama0 libxkbcommon-x11-0 libxcb-cursor0
```

**期待する結果**（抜粋。既に入っているものと、パッケージの数・版は、環境と取得する時期によって変わる。`<ユーザー名>` は各自のもの）:

```text
[sudo] password for <ユーザー名>:
...
Note, selecting 'libfuse2t64' instead of 'libfuse2'
libxcb-xinerama0 is already the newest version (1.15-1ubuntu2).
libxcb-xinerama0 set to manually installed.
libxkbcommon-x11-0 is already the newest version (1.6.0-1build1).
libxkbcommon-x11-0 set to manually installed.
The following NEW packages will be installed:
  libfuse2t64 libxcb-cursor0
0 upgraded, 2 newly installed, 0 to remove and 57 not upgraded.
...
Setting up libxcb-cursor0:amd64 (0.1.4-1build1) ...
Setting up libfuse2t64:amd64 (2.9.9-8.1build1) ...
Processing triggers for libc-bin (2.39-0ubuntu8.9) ...
```

`Note, selecting 'libfuse2t64' instead of 'libfuse2'` は、Ubuntu 24.04では `libfuse2` の代わりに `libfuse2t64` を入れる、という意味である（AppImageの実行に要るもの）。`is already the newest version` は、ROS 2やGazeboと一緒に既に入っていたもので、`set to manually installed` は、今後は自分で入れたものとして扱う、という意味である（どちらも問題ない）。エラー（`E:` で始まる行）が出ずにプロンプトへ戻れば成功。

QGCの公式の手順には、ほかに、シリアルポート（実機をUSBでつなぐときの口）を使うための設定（`dialout` のグループへの追加と、ModemManagerの停止）がある。WSLの中のQGCは、シミュレーションにつなぐだけで、シリアルポートを使わないので、この教材では行わない。

AppImageを取得する（約200MB）。AppImageは、取得したファイルをそのまま実行する形なので、取得元は、QGroundControlのGitHubの公式のリリースのページ（[v5.1.5](https://github.com/mavlink/qgroundcontrol/releases/tag/v5.1.5)）に限り、検索で見つけた別の配布元は使わない。取得したら、実行する前に、ファイルのSHA-256のハッシュ（ファイルの中身から計算する指紋。1文字でも違うと値が変わる）を計算し、リリースのページの添付ファイルの一覧で `QGroundControl-x86_64.AppImage` の横に表示される `sha256:` の値と同じかを確かめる。

```bash
mkdir -p ~/qgc

cd ~/qgc

wget https://github.com/mavlink/qgroundcontrol/releases/download/v5.1.5/QGroundControl-x86_64.AppImage

sha256sum QGroundControl-x86_64.AppImage
```

**期待する結果**（抜粋。時刻・速さ・接続先のアドレスは、実行ごとに変わる。`sha256sum` の値はv5.1.5のこのファイルに固有で、GitHubのリリースの情報と一致することを確かめたもの）:

```text
$ wget https://github.com/mavlink/qgroundcontrol/releases/download/v5.1.5/QGroundControl-x86_64.AppImage
--<日時>--  https://github.com/mavlink/qgroundcontrol/releases/download/v5.1.5/QGroundControl-x86_64.AppImage
...
HTTP request sent, awaiting response... 302 Found
Location: https://release-assets.githubusercontent.com/github-production-release-asset/... [following]
...
HTTP request sent, awaiting response... 200 OK
Length: 195332600 (186M) [application/octet-stream]
Saving to: ‘QGroundControl-x86_64.AppImage’
...
<日時> (<速さ>) - ‘QGroundControl-x86_64.AppImage’ saved [195332600/195332600]

$ sha256sum QGroundControl-x86_64.AppImage
9a47e4cf269d9e4f897f582f6b19aa7ebf1e9e67c9d68a532a45b541354bc344  QGroundControl-x86_64.AppImage
```

`302 Found` と `Location:` は、GitHubが、実際のファイルの置き場所（`release-assets.githubusercontent.com`。GitHubがリリースの添付ファイルを置く場所）へ案内したことを示す。`wget` はその案内に従い、`200 OK` で取得を始める。`saved [195332600/195332600]` は、全体を最後まで受け取ったことを示す。

左の値が、リリースのページの `sha256:` の値と一致すれば、取得したファイルは公開されたものと同じである。一致しない場合は、実行せずに消し（`rm QGroundControl-x86_64.AppImage`）、取得し直す。何度やっても一致しない場合は、使わない。

一致したら、実行できるようにする。

```bash
chmod +x QGroundControl-x86_64.AppImage

ls -l
```

**期待する結果**（`<ユーザー名>` は各自のもの。`total` の値と日時は、環境によって変わる）:

```text
total 190756
-rwxr-xr-x 1 <ユーザー名> <ユーザー名> 195332600 Oct  2 01:34 QGroundControl-x86_64.AppImage
```

左端に `x`（実行の許可）が付いていればよい。サイズ（`195332600`）は、`wget` の `saved [195332600/195332600]` と同じである。日時は、取得した日時ではなく、配布元に置かれたファイルの日時になる（`wget` は、配布元が知らせるファイルの更新の日時を、取得したファイルに付けるため）。起動は6節で、PX4のシミュレーションと一緒に行う。

## 6. 確かめる（完了条件）

PX4のシミュレーションとQGCを、別々のターミナルで起動する。

```bash
# T1
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_sitl gz_x500

# T2
cd ~/qgc

./QGroundControl-x86_64.AppImage
```

**期待する結果**（抜粋。時刻・待つ回数・ID・ログのファイル名は、実行ごとに変わる。`<ユーザー名>` は各自のもの。T2の行の先頭の数字は、起動からの秒数）:

```text
# T1（PX4のシミュレーション）
...
px4 starting.

INFO  [px4] startup script: /bin/sh etc/init.d-posix/rcS 0
INFO  [init] found model autostart file as SYS_AUTOSTART=4001
...
INFO  [init] Gazebo simulator 8.15.0
INFO  [init] Starting gazebo with world: /home/<ユーザー名>/PX4-Autopilot/Tools/simulation/gz/worlds/default.sdf
INFO  [init] Starting gz gui
INFO  [init] Waiting for Gazebo world...
...
INFO  [init] Gazebo world is ready
INFO  [init] Spawning Gazebo model
Warning [Utils.cc:132] [/sdf/model[@name="x500_base"]/link[@name="base_link"]/sensor[@name="air_pressure_sensor"]/gz_frame_id:...]: XML Element[gz_frame_id], child of element[sensor], not defined in SDF. Copying[gz_frame_id] as children of [sensor].
...
INFO  [gz_bridge] world: default, model: x500_0
...
INFO  [uxrce_dds_client] init UDP agent IP:127.0.0.1, port:8888
WARN  [health_and_arming_checks] Preflight Fail: No connection to the GCS
INFO  [tone_alarm] home set
INFO  [mavlink] mode: Normal, data rate: 4000000 B/s on udp port 18570 remote port 14550
...
INFO  [logger] Opened full log file: ./log/<日付>/<時刻>.ulg
...
INFO  [px4] Startup script returned successfully
pxh> INFO  [commander] Ready for takeoff!

# T2（QGroundControl）
     0.327 Using Qt multimedia with FFmpeg version 7.1.3 LGPL version 2.1 or later - qt.multimedia.ffmpeg - (unknown:0)
...
MESA: error: ZINK: failed to choose pdev
libEGL warning: egl: failed to create dri2 screen
    37.969 Critical: Error loading text-to-speech plug-in "speechd" - default - (unknown:0)
...
    63.285 Warning: void QGCPositionManager::_positionError(QGeoPositionInfoSource::Error) Positioning error: QGeoPositionInfoSource::AccessError - PositionManager.QGCPositionManager - (QGCPositionManager::_positionError:171)
```

T1は、次の順に進む。

- **PX4の起動**: `SYS_AUTOSTART=4001` は、機体の種類（x500）の設定を読み込んだことを示す。初めての起動では、その後に `CAL_ACC0_ID: curr: 0 -> new: ...` のような、パラメータを初期値に書き換える行が続く。
- **Gazeboの起動**: `Gazebo simulator 8.15.0` は、Gazebo Harmonic（8.15.0）で起動したことを示す（ROS 2のパッケージのものとGazebo公式のもののどちらかは、この表示からは区別できない。どちらも同じ版である）。Gazeboのウィンドウが開くまで、`Waiting for Gazebo world...` が何度か続く。`Spawning Gazebo model` の後、Gazeboの画面の地面の上にドローン（`x500`）が現れる（ウィンドウが開いてから、ドローンが表示されるまで、数秒かかることがある）。`Warning [Utils.cc:132] ... gz_frame_id ... not defined in SDF` は、機体の模型のファイルに、Gazeboの模型の書式（SDF）の規格に無い項目があることを知らせる警告で、Gazeboはその項目をそのまま残して読み込みを続け、機体は現れる。
- **通信の準備**: `uxrce_dds_client` の行は、ROS 2とつなぐ部品が、UDPの8888番でAgentを待つことを示す（Agentはフェーズ2で使う。今は起動していないので、つながらなくてよい）。`mavlink` の行は、QGC（UDPの14550番）などと話す口を開いたことを示す。
- **QGCとの接続**: `Preflight Fail: No connection to the GCS` は、地上局（GCS。ここではQGC）がつながっていないので、まだ飛べない、という意味である。T2でQGCを起動して機体につながると、`Ready for takeoff!` が表示される。この行は、`pxh>` のプロンプトの後ろに続けて表示されることがある（PX4の表示が、入力を待つプロンプトの後から割り込むため）。

T1の `pxh>` は、PX4のシェルのプロンプトである。続けてコマンドを打つと、PX4に直接指示できる（フェーズ1で使う）。

T2のQGCの表示は、警告が多いが、ウィンドウが開いて動いていれば問題ない。`libEGL warning` と `MESA: error: ZINK ...` は、WSLのグラフィックスの機能の一部が使えないことを知らせる表示で、ウィンドウが表示されれば問題ない。`speechd` の行は、読み上げの機能が無いことを、`Positioning error` の行は、PCの位置を取得できないことを知らせる表示で、どちらもシミュレーションの機体とつなぐのには関係ない。

QGCのウィンドウが開き、しばらくすると、自動でシミュレーションの機体につながり、地図の上に機体の印（オレンジ色の矢じりの形で、機体が向いている方向を指す）が表示される。この状態になれば、この手順書は完了である。止めるときは、T2のQGCのウィンドウを閉じ、T1で Ctrl+C を押す（`pxh>` で `shutdown` と打ってもよい）。Ctrl+C で止めると、T1の最後に次の表示が出るが、止め方として正しいので問題ない。

```text
PX4 Exiting...
pxh> Exiting NOW.
ninja: build stopped: interrupted by user.
make: *** [Makefile:227: px4_sitl] Interrupt
```

## つまずきやすい点

- **ビルドが非常に遅い・権限のエラーが出る**: `/mnt/c` などWindowsのドライブの下で作業している。ホーム（`~`）の下にソースを置く（4-2）。
- **`make px4_sitl` が、Pythonのモジュールが無い（`ModuleNotFoundError`）で止まる**: 仮想環境が有効になっていない。`source ~/px4-venv/bin/activate` を実行し、プロンプトの先頭に `(px4-venv)` が付いていることを確かめてからやり直す（4-1）。
- **`ninja: error: unknown target 'gz_x500'` で止まる**: PX4の公式の文書は、`make distclean` で生成物を消してから、もう一度 `make px4_sitl gz_x500` を実行するよう案内している。
- **`gz` が見つからない**: ROS 2を読み込んでいない。`source /opt/ros/jazzy/setup.bash` を実行する（3節）。
- **QGCが機体につながらない**: QGCを、PX4のシミュレーションと同じWSLの中で起動しているかを確かめる。Windows版のQGCを使う場合は、WSLのIPアドレスへの接続の設定が別に要る（PX4の公式の文書のWSLの環境のページ）。この教材では、WSLの中のQGCを使う。

## 次へ

[フェーズ0](phase0_drone_px4.md)（ドローンとPX4の用語と仕組みの読み物）をまだ読んでいなければ、先に読む。読み終えていれば、学習計画（[`docs/learning_plan.md`](learning_plan.md)）のフェーズ1（[PX4とGazeboで、ドローンを離陸・移動・着陸させる](phase1_first_flight.md)）へ進む。

## 出典

- 2節のコマンドは、ROS 2の公式の文書（[Installation: Ubuntu (deb packages)](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html)、Open Robotics、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)）から、親プロジェクトの手順書が抜粋したものを、コメントを省き、`~/.bashrc` への追記をコマンドにして載せた（改変あり）。
- 4-2の `git clone`・`git checkout`・`make submodulesclean`、4-3の `ubuntu.sh` の実行とWSLの再起動、4-5と6節の `make` のコマンドは、PX4の公式の文書（PX4 User Guide v1.17: [Windows Development Environment (WSL2-Based)](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/dev_setup/dev_env_windows_wsl.md)、[Git Examples](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/contribute/git_examples.md)、[Building PX4 Software](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/dev_setup/building_px4.md)、[Gazebo Simulation](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/sim_gazebo_gz/index.md)、Dronecode/PX4、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)）の手順に従ったもの。仮想環境の中で実行する形と、`--no-nuttx` の指定は、この教材で加えた（改変あり）。4-3のスクリプトの説明は、v1.17.0の [`Tools/setup/ubuntu.sh`](https://github.com/PX4/PX4-Autopilot/blob/v1.17.0/Tools/setup/ubuntu.sh) を読んで、自分の言葉でまとめたもの。
- 5節のライブラリの導入とAppImageの扱いは、QGroundControlの公式の文書（[Download and Install](https://docs.qgroundcontrol.com/master/en/qgc-user-guide/getting_started/download_and_install.html)）の手順を参考に書いた。AppImageの取得元は、QGroundControlのGitHubのリリース（[v5.1.5](https://github.com/mavlink/qgroundcontrol/releases/tag/v5.1.5)）。
- 3節の `gz sim --version` の表示は、Gazebo（Open Source Robotics Foundation、Apache License 2.0）の表示。
- 4〜6節の期待する結果は、PX4（PX4-Autopilot）・Gazebo・QGroundControlと、apt・pip・git・wget等のツールが出した表示を、筆者の環境で実行して抜粋したもの（説明に要る行に絞り、ユーザー名・ホスト名・日時・実測値の一部を伏せた）。
- WSL2の導入: [Install WSL](https://learn.microsoft.com/windows/wsl/install)（Microsoft）
