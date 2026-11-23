#!/bin/bash
# 手順書のサンプルと、確かめたファイルが一致するかを比べる（learning-text-authoring の「サンプルは確かめてから書く」の機械点検）。
# 読み取りだけで、ファイルを変えず、外部へ通信しない。リポジトリの最上位で実行する。
# 使い方: bash dev/check_samples.sh <確かめたファイルを置いたフォルダ> [docs/のページ ...]
#   docs/ の各ページの「ファイル: `<パス>`」の行の直後のコードブロックを抜き出し、
#   フォルダの中の同じ名前のファイル（下の階層も探す）と比べる。
#   「（末尾に足す）」のように行の後ろに注記があるブロックは、ファイルの一部なので比べない。
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
DIR=${1:-}
[ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: bash dev/check_samples.sh <確かめたファイルを置いたフォルダ> [docs/のページ ...]"; exit 2; }
shift
python3 - "$DIR" "$@" <<'PY'
import difflib, pathlib, re, sys
base = pathlib.Path(sys.argv[1])
pages = [pathlib.Path(p) for p in sys.argv[2:]] or sorted(pathlib.Path('docs').glob('*.md'))
found = {}
for f in base.rglob('*'):
    if f.is_file():
        found.setdefault(f.name, []).append(f)
same = diff = none = part = 0
for page in pages:
    lines = page.read_text(encoding='utf-8').splitlines()
    for i, line in enumerate(lines):
        m = re.match(r'^ファイル: `([^`]+)`(.*)$', line)
        if not m:
            continue
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j >= len(lines) or not lines[j].startswith('```'):
            continue
        k = j + 1
        while k < len(lines) and lines[k] != '```':
            k += 1
        block = lines[j + 1:k]
        name = pathlib.PurePosixPath(m.group(1)).name
        where = f'{page}:{i + 1} {m.group(1)}'
        if m.group(2).strip():
            part += 1
            print(f'部分（比べない）: {where}{m.group(2)}')
            continue
        cands = found.get(name, [])
        if not cands:
            none += 1
            continue
        if len(cands) > 1:
            print(f'同じ名前が複数: {where} → {", ".join(map(str, cands))}')
        ref = cands[0].read_text(encoding='utf-8').splitlines()
        if block == ref:
            same += 1
            print(f'一致: {where} = {cands[0]}')
        else:
            diff += 1
            print(f'不一致: {where} ≠ {cands[0]}')
            for d in list(difflib.unified_diff(ref, block, 'checked', 'page', lineterm='', n=0))[:20]:
                print('    ' + d)
print(f'一致 {same}件・不一致 {diff}件・比べる先なし {none}件・部分 {part}件')
PY
