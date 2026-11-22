#!/bin/bash
# pushの前の機械点検（dev/public_release_review.md の1-2・2-2・3-2節）。
# 読み取りだけで、ファイルを変えず、外部へ通信しない。リポジトリの最上位で実行する。
# 使い方: bash dev/check_before_push.sh
# 各見出しの下に何も表示されなければ問題ない（見方は点検の文書の各節）。
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

EXCL='users\.noreply\.github\.com|noreply@anthropic\.com|@example\.(com|org)|git@github\.com'
MAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
CRED='api[_-]?key|secret|token|passw(or)?d|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]|github_pat_|sk-[A-Za-z0-9]{10}'
PATHS='/home/[a-z][a-z0-9_-]*|[A-Za-z]:\\+Users\\+|/mnt/c/Users/|/tmp/claude'
# 未pushのコミットの追加行（origin/main が無ければ全履歴）
if git rev-parse -q --verify origin/main >/dev/null; then RANGE='origin/main..HEAD'; else RANGE='HEAD'; fi
added() { git log "$RANGE" -p | grep -E '^\+' | grep -vE '^\+\+\+ '; }

echo "== 未pushのコミット（$RANGE）"
git log --oneline "$RANGE"

echo "== 1-2 名義（全履歴。noreply以外が出たら調べる）"
git log --all --format='%an <%ae> | %cn <%ce>' | sort | uniq -c

echo "== 1-2 メールアドレス（今の版・全履歴）"
git grep -nIE "$MAIL" | grep -vE "$EXCL"
git log --all -p | grep -oE "$MAIL" | grep -vE "$EXCL" | sort | uniq -c

echo "== 1-2 認証情報らしい語（未pushの追加行。説明文の一般的な語にも当たるので1件ずつ読む）"
added | grep -iE "$CRED" | cut -c1-200

echo "== 1-2 ユーザー名入りのパス・作業用フォルダのパス（未pushの追加行）"
added | grep -E "$PATHS" | cut -c1-200

echo "== 1-2 アカウント名（未pushの追加行。著作権者の表示とリポジトリのURLは問題ない）"
added | grep -iE "SanghunIm1991" | cut -c1-200

echo "== 1-2 追跡してはいけないもの"
git ls-files | grep -E '^(notes|ws|ros2_ws|px4_ws|build|install|log|PX4-Autopilot|Micro-XRCE-DDS-Agent|\.vscode|\.idea)/|^\.claude/settings\.local\.json$|(^|/)(Thumbs\.db|Desktop\.ini|\.DS_Store)$|\.(env|pem|key|tar|vhdx|ulg)$|rosbag2_'

echo "== 2-2 Markdown・SVG・設定・ライセンス・確かめた画像・このスクリプト以外のファイル"
git ls-files | grep -vE '\.(md|svg)$|^\.git(attributes|ignore)$|^LICENSE(-APACHE-2\.0)?$|^docs/img/phase1_gazebo\.png$|^docs/img/phase4_(gazebo_walls|gazebo_no_vehicle|rviz2)\.png$|^docs/img/phase6_rviz2_[1-5]\.png$|^dev/check_before_push\.sh$'

echo "== 2-2 模型のファイル"
git ls-files | grep -iE '\.(sdf|world|dae|stl|obj|fbx|glb|gltf|urdf|xacro)$'

echo "== 2-2 SVGの外部の画像・リンク"
git grep -nE '<image|href="https?:' -- 'docs/img/*.svg'

echo "== 2-3 40文字以上続く英文（未pushの追加行。公式の文書の逐語の抜粋でないかを読む）"
added | grep -oE '[A-Za-z][A-Za-z ,.!-]{40,}' | sort -u

echo "== 改行がLFでないファイル"
git ls-files --eol | grep -v 'i/lf' | grep -v 'i/-text'

echo "== 3-2 文書間のリンク切れ"
python3 -I - <<'PY'
import pathlib, re
bad = 0
for md in [pathlib.Path('README.md'), pathlib.Path('CLAUDE.md'), *sorted(pathlib.Path('docs').glob('*.md')), *sorted(pathlib.Path('dev').glob('*.md'))]:
    for n, line in enumerate(md.read_text(encoding='utf-8').splitlines(), 1):
        for target in re.findall(r'\]\(([^)\s]+)\)', line):
            if re.match(r'[a-z]+:', target):
                continue
            if not (md.parent / target.split('#')[0]).resolve().exists():
                bad += 1
                print(f'{md}:{n}: {target}')
print(f'リンク切れ: {bad}件')
PY

echo "== 3-2 新しい外部のURL（未pushの追加行。実在を確かめる。GitHubの blob は raw.githubusercontent.com の同じパスで）"
added | grep -oE 'https?://[^ )>|`]+' | sort -u
