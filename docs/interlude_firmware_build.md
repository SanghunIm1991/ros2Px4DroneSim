# 間章: 実機向けのファームウェアをビルドする ― マイコン向けのツールチェーンと、書き込みの流れ

[学習計画](learning_plan.md) の間章（任意）。この教材では、PX4をいつもPCの上のプログラム（SITL）としてビルドしてきた。この章では、同じソースを、実機のフライトコントローラ（マイコン）で動くファームウェアとしてビルドする方法を見る。マイコン向けのツールチェーンの導入、ビルド、できたファイルをQGroundControlで基板へ書き込む流れ、`dds_topics.yaml` を変えてビルドし直す例を扱う。

- 想定環境: [環境構築](setup_px4_gazebo.md) を終えたWSL2のUbuntu 24.04。読むのは、[フェーズ6-2](phase6_2_replan_flight.md) と [間章「シミュレーションから実機へ」](interlude_sim_to_real.md) の後を勧める
- 所要の目安: 1コマ（読むだけなら30分。ツールチェーンの導入とビルドを試すなら、導入とビルドの待ち時間が加わる）
- 必須の範囲: なし（任意の章）。読む場合は1〜5節。2節と3節のコマンドを実行するかは任意（4節は読み物）
- 前提（親プロジェクト）: なし

> **この手順書の位置づけ**: 環境構築の4-3節では、マイコン向けのツールチェーンを入れない指定（`--no-nuttx`）で、PX4の導入のスクリプトを実行した。この章は、その指定を外したときに何が入り、何ができるようになるかを説明する。実機の基板が無くても、2節と3節（導入とビルド）は試せる。4節の書き込みには、実機の基板が要る。
>
> **期待する結果の出どころ**: （作成中）この章のコマンドと表示は、すべて、PX4 v1.17の文書とソース（`~/PX4-Autopilot`）から想定したもので、ツールチェーンを導入した環境で実行して確かめてはいない。ビルドの表示のうち、数・時刻・パスは実行ごとに変わる。実機への書き込みは、実機の基板が無いので確かめていない。

この章では、ターミナルを1つだけ使う。

| ターミナル | 動かすもの | 仮想環境 `~/px4-venv` |
|---|---|---|
| T5 | 導入のスクリプトとビルド | 使う |

ターミナルの番号は、[READMEの「ターミナルの番号」](../README.md#ターミナルの番号)のとおり、T1〜T4がどの手順書でも同じプログラムで、T5以降がそのページの作業用である。この章では、PX4のシミュレーションを起動しないので、T1〜T4は開かない。

## 0. 学習目標と完了条件

この章を終えると、次のことができるようになる。

1. SITL向けのビルドと実機向けのビルドの違いと、マイコン向けのツールチェーンが要る理由を説明できる（1節）。
2. ビルドの目標の名前（`px4_fmu-v6x_default` 等）の読み方と、基板ごとの設定のファイルの役割を説明できる（1節）。
3. マイコン向けのツールチェーンを導入し、実機向けのファームウェアをビルドできる（2節・3節）。
4. できたファームウェアを、QGroundControlで基板へ書き込む流れと、WSL2での注意を説明できる（4節）。
5. `dds_topics.yaml` を変えてビルドし直すときに、どこを変え、何を保守することになるかを説明できる（5節）。

**完了条件**: 7節の問いに、自分の言葉で答えられる。2節と3節を試した場合は、加えて、`build/px4_fmu-v6x_default/` に `px4_fmu-v6x_default.px4` ができることを確かめる。

## 1. SITL向けと実機向けで、何が違うか

### 1-1. 同じソースから、2種類のプログラムを作る

環境構築の4-5節で実行した `make px4_sitl` は、PX4を、PCの上で動くふつうのLinuxのプログラムとしてビルドした。PCのコンパイラ（`gcc`）が、PCのCPU（x86-64）向けの機械語を作り、できたプログラムは、PCのLinuxの上で動いた。

実機のフライトコントローラは、事情が違う。たとえば、Pixhawk 6X（Holybro社。PX4の文書が挙げるPixhawkの規格の基板の1つ）には、STM32H7というマイコンが載っている。CPUはArmのCortex-M7で、OSは、Linuxではなく、NuttXというリアルタイムOS（フェーズ0の3-1節）である。PCとは、CPUの種類も、OSも違う。そのため、PCの上で、マイコン向けの機械語を作る道具が要る。

ほかの種類のCPU向けのプログラムを作ることを、**クロスコンパイル**という。そのためのコンパイラ・リンカ（部品をつないで1つのプログラムにする道具）・ライブラリの一式を、**ツールチェーン**と呼ぶ。PixhawkなどのArmのマイコンの基板向けのPX4のビルドでは、Arm向けのGCC（`arm-none-eabi-gcc`）を使う（NuttXで動く基板には、ESP32のように別の種類のCPUのものもあり、そのツールチェーンは別である）。名前の `arm` はCPUの種類、`none` はOSを前提にしない（マイコンの上で直接動く）こと、`eabi` はArmの決めた呼び出しの約束（関数に値を渡す決まり等）に従うことを表す。

| 観点 | SITL向け（この教材） | 実機向け（この章） |
|---|---|---|
| ビルドの目標 | `px4_sitl_default`（`make px4_sitl`） | 基板ごと（例: `px4_fmu-v6x_default`） |
| 動く場所 | PCのLinuxの上のプログラム | フライトコントローラのマイコン（NuttXの上） |
| コンパイラ | PCの `gcc` | Arm向けの `arm-none-eabi-gcc`（2節で入れる） |
| できるもの | `build/px4_sitl_default/bin/px4` | `build/px4_fmu-v6x_default/px4_fmu-v6x_default.px4` |
| センサ・モーター | Gazeboが計算する（`gz_bridge` がドライバの代わり。フェーズ0の4節） | 本物のセンサとモーター（PX4のドライバが読む・回す） |

推定・制御・フェイルセーフの判断など、PX4の大部分のコードは、どちらでも同じである。違うのは、OSとのつなぎ目と、センサ・モーターとのつなぎ目である。

### 1-2. ビルドの目標の名前と、基板ごとの設定

実機向けのビルドの目標の名前は、`<作り手>_<基板>_<設定>` の形をしている。`px4_fmu-v6x_default` なら、PX4のプロジェクトの基板の定義（`px4`）の、FMUv6Xという規格の基板（`fmu-v6x`）の、標準の設定（`default`）である。末尾の `_default` は省略でき、`make px4_fmu-v6x` と同じになる。FMUv6Xの規格の基板は、Pixhawk 6Xのほかにもある。手元の基板に合う名前は、PX4の文書の各基板のページか、`make list_config_targets` の一覧で確かめる。

基板ごとの定義は、PX4のソースの `boards/<作り手>/<基板>/` にある（FMUv6Xなら `boards/px4/fmu-v6x/`）。その中の `default.px4board` に、使うツールチェーンとCPU（`arm-none-eabi` と `cortex-m7`）、シリアルの割り当て、ファームウェアに入れるドライバとモジュール（uXRCE-DDSのクライアントを含む）が書かれている。同じフォルダの、`default` 以外の名前の `.px4board`（`multicopter` 等）は、`default` の差分として、別の設定のファームウェアを作るためのものである。この設定は、[間章（フライトコントローラ）](interlude_flight_controller.md) の4節の【C】（基板に合わせる設定）の層に当たる。

### 1-3. 自分でビルドする必要があるのは、どんなときか

PX4の文書によると、実機でPX4をただ試すだけなら、自分でビルドする必要はない。QGroundControlが、PX4の公式の、ビルド済みのファームウェアを取ってきて、基板へ書き込める（4節）。自分でビルドするのは、PX4の中を変えたいときである。たとえば、次のような場合である。

- 公式のビルドに入っていないドライバやモジュールを入れたい（【C】の層）
- 自作のモジュールや、uXRCE-DDSで出すトピックを足したい（【D】の層。5節）
- 製品として、使うPX4の版を決め、自分の機体の設定を入れたファームウェアを作りたい（[間章（フライトコントローラ）](interlude_flight_controller.md) の3-2節の【7】）

## 2. マイコン向けのツールチェーンを入れる

> この節のコマンドは任意である。実行すると、ROS 2とGazeboと共通の環境に、ツールチェーンと、その周りの道具が入る（何が入るかは、コマンドの後に書く）。読むだけでもよい。

### 2-1. 導入のスクリプトを、指定を外して実行する

PX4の文書の手順では、環境構築の4-3節と同じ導入のスクリプト `Tools/setup/ubuntu.sh` を、`--no-nuttx` を付けずに実行する。シミュレーションの道具は、環境構築の4-3節で入れてあるので、この章では、シミュレーションの道具を省く指定 `--no-sim-tools`（PX4の文書が用意している指定）を付ける。付けないと、Gazeboなどのパッケージの導入の段階ももう一度走り、新しい版があれば更新されることがある。環境構築と同じく、仮想環境を有効にしてから実行する（PX4のビルドに要るPythonのパッケージを、ROS 2のPythonと分けて入れるため。環境構築の4-1節）。

```bash
# T5
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

bash ./Tools/setup/ubuntu.sh --no-sim-tools
```

**期待する結果**（想定。途中で `sudo` のパスワードを聞かれる）: スクリプトは、環境構築の4-3節と同じ導入のうち、ビルドの道具とPythonのパッケージの段階を、もう一度進める（入っているものは、新しい版が無ければ、そのまま進む）。続けて、`[ubuntu.sh] NuttX Installing Dependencies` で始まる行の後で、マイコン向けの道具を入れる。最後に、エラーで止まらずにプロンプトに戻れば、導入は終わっている。

`--no-nuttx` を外すと、スクリプトは、次のものを足す（PX4 v1.17の `Tools/setup/ubuntu.sh` を読んで確かめた。PCがx86-64の場合）。

- **aptのパッケージ**（Ubuntuの公式のリポジトリから）: Arm向けのGCCと、その標準のライブラリ（`gcc-arm-none-eabi`・`libnewlib-arm-none-eabi`・`libstdc++-arm-none-eabi-newlib`）、NuttXのビルドに使う道具（設定の道具の `kconfig-frontends`、起動のときのファイルの一式を作る `genromfs` 等）、マイコンのデバッガ（`gdb-multiarch`）、clangの道具など、約40個
- **ESP32向けのコンパイラ**: ESP32（Espressif社のマイコン）の基板向けのビルドに使うコンパイラを、GitHubのEspressif社のリリースから取ってきて、`/opt` に展開する。取ってきた圧縮のファイルは、`~/PX4-Autopilot/Tools/setup/` に残る（Gitの追跡の外のファイルとして、`git status` に出る）。さらに、`~/.bashrc` の末尾に、そのコンパイラをPATHに足す1行を書き足す（Pixhawkの基板のビルドには使わない。スクリプトは、同じ行があるかを確かめずに足すので、もう一度実行すると、同じ行が増える）
- **グループ**: シリアルポート（USBでつないだ基板等）を使えるように、ユーザーを `dialout` グループに加える（WSL2の中からは、USBでつないだ機器をそのままでは使えないので、WSL2では、この追加はふつう効かない。4-2節。QGroundControlを起動したときの権限のメッセージ〈環境構築の5節〉は、表示が変わることがある）

スクリプトを読んだ範囲では、ROS 2やGazeboのパッケージを消す処理は無い。ただし、入るものはすべて、ROS 2とGazeboと共通の環境に入る（この教材は、ROS 2・Gazebo・PX4を、1つのUbuntuの環境で使っている）。また、既に入っているパッケージも、新しい版があれば更新されることがある。

`~/.bashrc` に足された行は、導入の後に、次のコマンドで確かめられる。

```bash
# T5
tail -n 3 ~/.bashrc
```

**期待する結果**（想定。最後の行の前には、それまでの `~/.bashrc` の末尾の行が出る）:

```text
...
export PATH=$PATH:/opt/xtensa-esp-elf/bin/
```

最後の行が、スクリプトが足した行である。ESP32の基板向けにビルドしないなら、この行は消してよい。

スクリプトが終わったら、環境構築の4-3節と同じく、WSLを再起動する（入れたもの、とくにグループの変更を確実に反映させるため）。Ubuntuのターミナルを `exit` で閉じ、WindowsのPowerShellで、次を実行する。

```powershell
wsl --shutdown
```

**期待する結果**: 何も表示されない。開いていたUbuntuのターミナルはすべて閉じる。もう一度Ubuntuのターミナルを開くと、WSLが起動し直す。

### 2-2. 入ったことを確かめる

```bash
# T5
arm-none-eabi-gcc --version
```

**期待する結果**（想定。PX4の文書の、Ubuntuの開発環境のページに載っている版。著作権の表示の行は省いた）:

```text
arm-none-eabi-gcc (15:13.2.rel1-2) 13.2.1 20231009
```

Arm向けのGCCの版が表示されれば、ツールチェーンは入っている。括弧の中は、Ubuntu 24.04のパッケージの版である。`command not found` になる場合は、2-1節のスクリプトが途中で止まっていないかを、スクリプトの表示で確かめる。

## 3. 実機向けにビルドする

### 3-1. ビルドする

例として、Pixhawk 6X（FMUv6X）向けにビルドする。手元に別の基板がある場合は、1-2節の方法で、その基板の目標の名前に替える。

```bash
# T5
source ~/px4-venv/bin/activate

cd ~/PX4-Autopilot

make px4_fmu-v6x_default
```

**期待する結果**（想定・抜粋。行の数・メモリの使用量・パスは、実行ごとと環境で変わる。`<使用量>` の単位〈B・KB等〉も、値によって変わる。`<username>` はUbuntuのユーザー名）:

```text
...
Memory region         Used Size  Region Size  %age Used
...
           FLASH:     <使用量>      1920 KB     <割合>%
...
[<n>/<n>] Creating /home/<username>/PX4-Autopilot/build/px4_fmu-v6x_default/px4_fmu-v6x_default.px4
```

最初に、`px4_sitl` のときと同じく、ビルドの構成の行（`--` で始まる行）が並び、続けて、ファイルを1つずつコンパイルする行が進む。実機向けのビルドでは、PX4のコードに加えて、NuttXそのものもコンパイルする。

- **`Memory region` の表**: ビルドの終わり近くに、リンカ（1-1節）が、マイコンのメモリの区画ごとの使用量を表示する。`FLASH` は、プログラムを置く、電源を切っても消えないメモリで（動いている間は読み出して使い、4節の書き込みのときに書き換える）、Pixhawk 6Xの定義では、使える大きさが1920 KBである（`boards/px4/fmu-v6x/nuttx-config/scripts/script.ld`）。ここが100 %を超えると、`region 'FLASH' overflowed by …` のようなエラーで、ビルドが止まる（区画の名前は、基板のリンカのスクリプトによって変わる）。PCと違い、マイコンのメモリは小さく、入れるモジュールを増やすと、この上限に当たることがある（PX4の文書は、とくにFLASHが1 MBの古い基板で起きやすいとしている）。
- **最後の行**: できたファームウェアのファイル（`.px4`）の場所である。ビルドの結果は、目標ごとに `build/` の下の別のフォルダに入るので、SITLのビルド（`build/px4_sitl_default/`）とは混ざらない。この教材のシミュレーションは、これまでどおり使える。

できたファイルは、次のコマンドで確かめられる。

```bash
# T5
ls -l ~/PX4-Autopilot/build/px4_fmu-v6x_default/*.px4
```

**期待する結果**（想定。大きさ・日時は実行ごとに変わる。`<username>` はUbuntuのユーザー名）:

```text
-rw-r--r-- 1 <username> <username> <大きさ> <日時> /home/<username>/PX4-Autopilot/build/px4_fmu-v6x_default/px4_fmu-v6x_default.px4
```

`px4_fmu-v6x_default.px4` の行が1つ出れば、ファームウェアのファイルはできている。

### 3-2. できたファイルの中身

`.px4` のファイルは、PX4のスクリプト（`Tools/px_mkfw.py`）が作る、テキストの形式（JSON）のファイルである。中には、次のものが入っている。

- ファームウェアの本体（圧縮して、文字に直したもの）
- **基板の番号**（`board_id`。FMUv6Xは53）。`make … upload`（4-2節）で使う、PX4の書き込みのスクリプト（`Tools/px_uploader.py`）は、強制の指定が無い限り、つないだ基板の番号と合わないファイルを書き込まない
- パラメータと機体の設定の一覧（説明などの情報）
- ビルドしたソースのGitの版の識別（`git_identity`）

基板の番号が入っているので、別の基板向けのファイルを、誤って書き込みにくい作りになっている。

## 4. 基板へ書き込む流れ（読み物）

> この節は、実機の基板が無いので確かめていない。PX4 v1.17の文書（ファームウェアの書き込みのページと、WSL2の開発環境のページ）を元にした説明である。実際に書き込むときは、その時点の公式の文書の手順に従う。

### 4-1. QGroundControlで書き込む

ファームウェアは、QGroundControlの機体の設定の画面（**Q** のアイコン → **Vehicle Setup** → **Firmware**）から、USBでつないだ基板へ書き込む。流れは、次のとおりである。

1. 書き込みを始める前に、機体とのUSBのつながり（テレメトリの無線の通信機を通したものも含む）をすべて外し、電池をつながない。
2. QGroundControlで、Firmwareの画面を開いてから、基板をPCのUSBポートに直接つなぐ（USBハブを通さない）。
3. PX4（PX4 Flight Stack）を選び、**Advanced settings** にチェックを入れ、一覧から **Custom firmware file...** を選ぶ。
4. 続けて開くファイルの選択の画面で、3節でビルドした `.px4` のファイルを選び、書き込みを始める。
5. 書き込みの段階（古いファームウェアの消去・書き込み等）が進み、終わると、基板が再起動して、QGroundControlにつながり直す。

自分でビルドしたのではない、公式の安定版を書き込む場合は、3の **Custom firmware file...** の代わりに、標準の選択（PX4 Pro Stable Release）のまま進める。

初めて書き込んだ基板では、続けて、新しい機体と同じく、機体の設定（機体の種類の選択）から始めて、センサの較正などを行う（[間章（フライトコントローラ）](interlude_flight_controller.md) の3-2節の【3】）。

### 4-2. WSL2での注意: Windows版のQGroundControlを使う

この教材の環境では、QGroundControlを、WSLの中のLinux版として使ってきた（環境構築の5節）。PX4の文書によると、WSL2の中からは、PCにUSBでつないだ基板（シリアルの機器）を、そのまま（標準の機能では）使えない。そのため、そのままでは、WSL2の中のQGroundControlから基板へ書き込めない。PX4のビルドには、`make px4_fmu-v6x_default upload` のように、末尾に `upload` を付けて、ビルドしたらすぐUSBで書き込む使い方もあるが、これも、そのままではWSL2で使えない。PX4の文書は、USBの機器をWSL2へ渡す道具（USBIPD-WIN）を使えば、WSL2の中から `upload` で書き込めるとも書いているが、この教材では扱わない。

PX4の文書が、WSL2の場合の手順として示すのは、次の流れである。

1. WSL2の中で、3節のとおりにビルドする。
2. Windows版のQGroundControlを使って、4-1節の流れで書き込む。
3. ファイルの選択の画面では、左の一覧の「Linux」（ペンギンのアイコン）から、Ubuntuの中のファイルを開く。場所は `Ubuntu\home\<username>\PX4-Autopilot\build\px4_fmu-v6x_default\px4_fmu-v6x_default.px4` である（`<username>` はUbuntuのユーザー名）。

Windows版のQGroundControlは、WSLの中のLinux版とは別に、Windowsに導入することになる。導入するかどうかは、実機の基板を手にしたときに決めればよい。

## 5. 応用: トピックを足して、ビルドし直す（説明だけ）

> この節は、変更の仕方の説明である。この教材では、実際に変えてビルドし、動かして確かめてはいない。

### 5-1. 何のために変えるか

[間章「シミュレーションから実機へ」](interlude_sim_to_real.md) の3-3節で、LiDARをフライトコントローラにつなぐ形では、PX4が受け取った障害物の距離を、ROS 2の側へ出すトピックが、既定の一覧に無いことを見た。PX4 v1.17の `dds_topics.yaml` の一覧には、ROS 2からPX4へ渡す `/fmu/in/obstacle_distance` はあるが、PX4からROS 2へ出す `/fmu/out/obstacle_distance` は無い。PX4の文書によると、uXRCE-DDSで出し入れするトピックは、ビルドのときに、この一覧から決まる（ファームウェアに組み込まれる）。そのため、トピックを足すには、一覧を変えて、PX4をビルドし直すことになる。

### 5-2. 変える場所

一覧のファイルは、PX4のソースの `src/modules/uxrce_dds_client/dds_topics.yaml` である。主に、`publications:`（PX4から出すトピック）の一覧と、`subscriptions:`（PX4が受け取るトピック）の一覧がある（ほかに、同じ種類のトピックを複数受け取るための `subscriptions_multi:` がある）。1つのトピックは、ROS 2の側の名前（`topic`）と型（`type`）の組で書く。`topic` の最後の部分（`/fmu/out/` の後ろ）は、PX4の中のuORBのトピックの名前と同じにする（ビルドのときに、この部分から、どのuORBのトピックを出すかが決まる）。出す頻度の上限（`rate_limit`。書かなければ毎秒100回）も書ける。

障害物の距離を出すなら、`publications:` の一覧の中に、次の2行を足す（一覧の中のほかの項目と、行の先頭の空白をそろえる）。

ファイル: `~/PX4-Autopilot/src/modules/uxrce_dds_client/dds_topics.yaml`（`publications:` の一覧に足す部分）

```yaml
  - topic: /fmu/out/obstacle_distance
    type: px4_msgs::msg::ObstacleDistance
```

型の [`ObstacleDistance`](https://github.com/PX4/px4_msgs/blob/release/1.17/msg/ObstacleDistance.msg) は、`/fmu/in/obstacle_distance` で既に使っている型で、`px4_msgs`（`release/1.17`）にもある。そのため、この例では、ROS 2の側の `px4_msgs` は変えなくてよい。新しいuORBのメッセージを自分で作ったり、メッセージの中身を変えたりした場合は、PX4の文書のとおり、PX4のソースの `msg/` の定義を、ワークスペースの `px4_msgs` にも写して、ROS 2の側もビルドし直す必要がある（PX4とROS 2の側で、型の定義が同じでないと、値を読めない。フェーズ0の7節）。

どのuORBのトピックに値が入るかは、センサとドライバによって違う。`obstacle_distance` は、向きごとの距離を出すセンサ（回転して測る距離センサ等）の値が入るトピックである。1つの向きだけを測る距離センサの値は `distance_sensor` に入るので、その場合は、`/fmu/out/distance_sensor`（型 `px4_msgs::msg::DistanceSensor`）を足すことになる。

変えたら、3節と同じ `make px4_fmu-v6x_default` で、実機向けにビルドし直す。同じ変更は、SITLのビルド（`make px4_sitl`）にも効く。SITLでは、フェーズ5と同じLiDAR付きの機体の起動（`make px4_sitl gz_x500_lidar_2d_walls`）で、`gz_bridge` が、GazeboのLiDARの値から作った `obstacle_distance` を出している（フェーズ5の7節）。そのため、SITLでビルドし直し、その起動とAgent（T3）を動かせば、実機の基板が無くても、`/fmu/out/obstacle_distance` がROS 2に出るかを確かめられるはずである（この教材では確かめていない）。

### 5-3. 変えた後に背負うもの

`dds_topics.yaml` は、PX4のソースの中のファイルである。変えると、自分のPX4は、公式の版と違うものになる（[間章（フライトコントローラ）](interlude_flight_controller.md) の4節の【D】の層）。そのため、次のことを考えておく。

- **変更を記録する**: PX4のソースはGitで管理されているので、`git diff` で、公式の版からの違いを見られる。変更は、自分のブランチ（例: `git switch -c my-dds-topics` で、今の版から作る）にコミットしておくと、どの版に何を足したかが分かる（環境構築の4-2節では、v1.17.0の版を、ブランチを作らずに取り出している）。
- **版を上げるたびに見直す**: PX4の版を上げると、`dds_topics.yaml` そのものも変わる（トピックが足されたり、型の版が上がったりする）。版を上げるたびに、自分の変更を新しい版に移し直し、SITLで確かめ直す。
- **公式の版に戻す**: 変更をやめるときは、`git checkout v1.17.0 -- src/modules/uxrce_dds_client/dds_topics.yaml` で、このファイルをv1.17.0の中身に戻し、ビルドし直す。コミットしていない変更は、この操作で消え、取り戻せない。自分のブランチにコミットした場合は、`git switch --detach v1.17.0` で、ソース全体を公式の版に戻すこともできる（ブランチのコミットは残る）。

PX4の中の値の粗さ（5°ごとの区画）や、ROS 2の側で [`sensor_msgs/msg/LaserScan`](https://github.com/ros2/common_interfaces/blob/jazzy/sensor_msgs/msg/LaserScan.msg) の形に直すノードが要ることは、[間章「シミュレーションから実機へ」](interlude_sim_to_real.md) の3-3節のとおりで、トピックを足しても変わらない。足す前に、ほかの道（センサをコンパニオンコンピュータにつなぐ等）で目的を果たせないかを、先に考える。

## 6. まとめ

- 実機のフライトコントローラは、PCとCPUもOSも違うので、マイコン向けのツールチェーン（Arm向けのGCC等）で、クロスコンパイルする（1-1節）。
- ビルドの目標の名前は、基板と設定を表す。基板ごとの定義は `boards/` にあり、入れるモジュールなどを決める（1-2節）。PX4を変えないなら、自分でビルドしなくても、公式のファームウェアを書き込める（1-3節）。
- ツールチェーンは、導入のスクリプトを `--no-nuttx` なしで実行すると入る。共通の環境に、aptのパッケージ・ESP32向けのコンパイラ（`~/.bashrc` への1行を含む）・グループの変更が加わる（2節）。
- `make <目標>` でビルドすると、`build/<目標>/<目標>.px4` ができる。マイコンのメモリの上限を、ビルドの表示で確かめる（3節）。
- 書き込みは、QGroundControlのFirmwareの画面から行う。WSL2では、Windows版のQGroundControlを使う（4節）。
- `dds_topics.yaml` を変えれば、出し入れするトピックを足せるが、PX4を自分で保守することになる（5節）。

## 7. 確かめの問い

答えを見ずに、自分の言葉で答えてから開く。

**問い1**: SITLのビルドには要らなかったマイコン向けのツールチェーンが、実機向けのビルドには要るのはなぜか。

<details>
<summary>答え</summary>

SITLのPX4は、PCのLinuxの上で動くプログラムなので、PCのCPU（x86-64）向けに、PCの `gcc` でビルドすればよい。実機のフライトコントローラ（例: Pixhawk 6X）は、Armのマイコン（Cortex-M7）の上で、NuttXというリアルタイムOSで動く。CPUの種類もOSも違うので、PCの上で、Arm向けの機械語を作るツールチェーン（`arm-none-eabi-gcc` 等）が要る（1-1節）。

</details>

**問い2**: PX4を一切変えずに、手元のPixhawkの基板でPX4を試したい。この章の2節と3節（ツールチェーンの導入とビルド）は必要か。

<details>
<summary>答え</summary>

必要ない。PX4の文書のとおり、QGroundControlのFirmwareの画面で、標準の選択のまま進めれば、公式のビルド済みのファームウェアを書き込める（1-3節・4-1節）。自分でビルドするのは、ドライバやモジュール、トピックを足すなど、PX4の中を変えたいときである。ただし、WSL2の環境では、書き込みにWindows版のQGroundControlを使う（4-2節）。

</details>

**問い3**: 向きごとの距離を測るLiDAR（回転して測るもの）をフライトコントローラにつなぎ、PX4が受け取った障害物の距離を、ROS 2の側の計画にも使いたい。何を変え、そのあと何に気をつけ続ける必要があるか。

<details>
<summary>答え</summary>

PX4のソースの `dds_topics.yaml` の `publications:` に、`/fmu/out/obstacle_distance`（型 `px4_msgs::msg::ObstacleDistance`）を足して、PX4をビルドし直し、書き込む（5-2節）。型は既にあるので、`px4_msgs` は変えなくてよい。そのあとは、公式と違うPX4を自分で保守することになる。変更をGitで記録し、PX4の版を上げるたびに移し直して、SITLで確かめ直す（5-3節）。また、届く値は5°ごとの区画で粗いので、地図づくりに使うには、`LaserScan` などの形に直すノードも要る（[間章「シミュレーションから実機へ」](interlude_sim_to_real.md) の3-3節）。

</details>

**問い4**: ファームウェアに部品を足していったら、ビルドが `region 'FLASH' overflowed by …` のようなエラーで止まった。何が起きていて、どうすればよいか。

<details>
<summary>答え</summary>

ファームウェアの大きさが、マイコンのFLASH（プログラムを置くメモリ）の上限を超えた（3-1節）。PCと違い、マイコンのメモリは小さい。基板の設定（`.px4board`）で、使わないドライバやモジュールを外して小さくする。PX4の文書は、公式の版をそのままビルドしてこのエラーが出る場合は、PX4が指定する版と違うGCCを使っていることが多い、ともしている（その場合は、2節の手順で入る版を使う）。

</details>

## 8. 用語集

| 用語 | 意味 | 初出 |
|---|---|---|
| クロスコンパイル | ビルドするPCとは別の種類のCPU向けに、プログラムを作ること | 1-1 |
| ツールチェーン | プログラムを作るためのコンパイラ・リンカ・ライブラリの一式 | 1-1 |
| リンカ | コンパイルした部品をつないで、1つのプログラムにする道具 | 1-1 |
| `arm-none-eabi-gcc` | OSを前提にしないArmのマイコン向けのGCC。PixhawkなどのArmの基板向けのPX4のビルドで使う | 1-1 |
| NuttX | PX4が実機で使うリアルタイムOS（決まった時間の内に処理を終えることを重んじるOS） | 1-1 |
| ビルドの目標 | `make` に渡す、何向けにビルドするかの名前（`px4_sitl_default`・`px4_fmu-v6x_default` 等） | 1-2 |
| `.px4board` | 基板ごとの、ビルドに入れるモジュールやシリアルの割り当てなどの設定のファイル | 1-2 |
| ESP32 | Espressif社のマイコン。PX4の一部の基板で使う | 2-1 |
| FLASH | マイコンの中の、プログラムを置くメモリ。電源を切っても消えない。動いている間は読み出して使い、ファームウェアの書き込みで書き換える | 3-1 |
| `.px4` のファイル | 実機向けのビルドでできる、ファームウェアの本体と基板の番号・パラメータの一覧などをまとめたファイル | 3-2 |
| 基板の番号（`board_id`） | 基板の種類を表す番号。合わない基板への書き込みを防ぐのに使う | 3-2 |

## 次へ

この章は任意で、ここで一段落する。実機の構成全体の考え方は、[間章「シミュレーションから実機へ」](interlude_sim_to_real.md) に戻って確かめる。PX4の調整する部分と根幹の境界は、[間章（フライトコントローラ）](interlude_flight_controller.md) の4節にある。

## 出典

この手順書の技術的な記述は、次の文書とファイルを読んで、自分の言葉でまとめたもの（逐語の転載ではない）。

- PX4 User Guide（v1.17。[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)、Dronecode/PX4）: [Building PX4 Software](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/dev_setup/building_px4.md)（NuttX向けのビルドの目標と名前の読み方、`_default` の省略、Pixhawkの規格の基板の一覧、`upload`、`make list_config_targets`、FLASHがあふれるエラー、試すだけならビルドが要らないこと）、[Ubuntu Development Environment](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/dev_setup/dev_env_linux_ubuntu.md)（`ubuntu.sh` と `--no-nuttx`・`--no-sim-tools`、導入の後の再起動、2-2節の `arm-none-eabi-gcc --version` の表示）、[Windows Development Environment (WSL2-Based)](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/dev_setup/dev_env_windows_wsl.md)（WSL2の中からはUSBの基板をそのままでは使えないことと、USBIPD-WINを使う方法もあること、Windows版のQGroundControlで書き込む手順とファイルの場所）、[Loading Firmware](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/config/firmware.md)（書き込みの前の注意、Firmwareの画面の流れ、Custom firmware file）、[uXRCE-DDS](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/docs/en/middleware/uxrce_dds.md)（トピックの一覧がビルドのときに決まること、`dds_topics.yaml` の形と `rate_limit`、メッセージを変えたときの `px4_msgs` の写し方）。2節・3節・4節の手順は、これらの文書の手順に従い、例の基板とワークスペースの場所をこの教材で決めた（改変あり）。
- PX4 v1.17のソース（作成に使った環境に取得したもの）: [`Tools/setup/ubuntu.sh`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/Tools/setup/ubuntu.sh)（`--no-nuttx` を外したときに入るもの）、[`boards/px4/fmu-v6x/default.px4board`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/boards/px4/fmu-v6x/default.px4board)（ツールチェーンとCPU）、[`boards/px4/fmu-v6x/nuttx-config/scripts/script.ld`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/boards/px4/fmu-v6x/nuttx-config/scripts/script.ld)（FLASHの大きさ）、[`boards/px4/fmu-v6x/firmware.prototype`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/boards/px4/fmu-v6x/firmware.prototype)（基板の番号）、[`platforms/nuttx/CMakeLists.txt`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/platforms/nuttx/CMakeLists.txt)（メモリの使用量の表示と、`.px4` を作る手順）、[`Tools/px_mkfw.py`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/Tools/px_mkfw.py)（`.px4` の中身）、[`Tools/px_uploader.py`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/Tools/px_uploader.py)（基板の番号の照らし合わせ）、[`src/modules/uxrce_dds_client/dds_topics.yaml`](https://github.com/PX4/PX4-Autopilot/blob/release/1.17/src/modules/uxrce_dds_client/dds_topics.yaml)（v1.17の一覧に `/fmu/out/obstacle_distance` が無いこと）
- [PX4/px4_msgs](https://github.com/PX4/px4_msgs)（`release/1.17`、BSD 3-Clause License、PX4 Development Team）: `ObstacleDistance.msg`（5-2節の型が既にあること）
- PX4 v1.17のソース（続き）: `src/modules/uxrce_dds_client/generate_dds_topics.py`（`topic` の最後の部分から、出すuORBのトピックが決まること）、`msg/ObstacleDistance.msg`、`src/modules/simulation/gz_bridge/GZBridge.cpp`（SITLで `obstacle_distance` を出すこと）
- 5-2節の `dds_topics.yaml` に足す2行は、v1.17の `dds_topics.yaml` のほかの項目と同じ形で、この教材で書いたもの
