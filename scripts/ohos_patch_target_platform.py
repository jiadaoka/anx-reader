#!/usr/bin/env python
"""给第三方包补上 `TargetPlatform.ohos` 分支。

鸿蒙版 Flutter 给 `TargetPlatform` 加了一个 `ohos` 取值，Dart 的 switch 穷尽性
检查会让没有这个分支的第三方包直接编译失败。这个脚本在**构建前**把缺失的
`case TargetPlatform.ohos:` 插到同一个 switch 的第一个 case 上（共用它的分支体），
构建后可用 `restore` 把文件改回去。

只动 `PACKAGES` 里列出的包，且只改 pub 缓存里的源文件；备份放在
`build/ohos/target-platform-backup/`。

用法：
    python scripts/ohos_patch_target_platform.py status
    python scripts/ohos_patch_target_platform.py apply
    python scripts/ohos_patch_target_platform.py restore
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

# 需要补丁的包：都是因为 TargetPlatform.ohos 而编译失败的第三方依赖。
PACKAGES = ("flex_color_scheme", "flutter_math_fork", "mongol")

CASE_RE = re.compile(r"\bcase\s+TargetPlatform\.([A-Za-z_][A-Za-z0-9_]*)\s*:")
SWITCH_RE = re.compile(r"\bswitch\s*\(")

BACKUP_DIR = "build/ohos/target-platform-backup"


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def uri_to_path(uri: str) -> Path | None:
    """把 package_config 里的 file:// URI 转成本机路径。

    不能简单去掉 `file:///` 前缀：Linux 上 `file:///home/x` 去掉后是相对路径
    `home/x`，Windows 上 `file:///C:/x` 去掉后才是 `C:/x`。
    """
    parsed = urlparse(uri)
    if parsed.scheme not in ("", "file"):
        return None
    path = unquote(parsed.path)
    if os.name == "nt" and re.match(r"^/[A-Za-z]:", path):
        path = path[1:]
    return Path(path)


def load_package_dirs() -> dict[str, Path]:
    """从 .dart_tool/package_config.json 里找出目标包的实际目录。"""
    config_path = repo_root() / ".dart_tool" / "package_config.json"
    if not config_path.exists():
        raise SystemExit("找不到 .dart_tool/package_config.json，先跑 flutter pub get")

    config = json.loads(config_path.read_text(encoding="utf-8"))
    wanted = set(PACKAGES)
    found: dict[str, Path] = {}
    for package in config.get("packages", []):
        name = package.get("name")
        if name not in wanted:
            continue
        path = uri_to_path(package.get("rootUri", ""))
        if path is not None:
            found[name] = path
    return found


def find_block_end(text: str, open_index: int) -> int:
    """从 `{` 的位置开始，返回与之配对的 `}` 下标。"""
    depth = 0
    index = open_index
    length = len(text)
    in_string: str | None = None
    while index < length:
        char = text[index]
        if in_string is not None:
            if char == "\\":
                index += 2
                continue
            if char == in_string:
                in_string = None
            index += 1
            continue
        if char in "'\"":
            in_string = char
        elif char == "/" and index + 1 < length and text[index + 1] == "/":
            newline = text.find("\n", index)
            index = length if newline < 0 else newline
            continue
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return -1


def patch_source(text: str) -> tuple[str, int]:
    """返回 (新文本, 插入数量)。"""
    insertions: list[int] = []
    for match in SWITCH_RE.finditer(text):
        close_paren = text.find(")", match.end())
        if close_paren < 0:
            continue
        open_brace = text.find("{", close_paren)
        if open_brace < 0:
            continue
        end = find_block_end(text, open_brace)
        if end < 0:
            continue
        block = text[open_brace:end]
        cases = list(CASE_RE.finditer(block))
        if not cases:
            continue
        if any(case.group(1) == "ohos" for case in cases):
            continue
        first = cases[0]
        case_start = open_brace + first.start()
        line_start = text.rfind("\n", 0, case_start) + 1
        indent = text[line_start:case_start]
        insertions.append(case_start)

    if not insertions:
        return text, 0

    pieces: list[str] = []
    cursor = 0
    for position in insertions:
        line_start = text.rfind("\n", 0, position) + 1
        indent = text[line_start:position]
        pieces.append(text[cursor:position])
        pieces.append(f"case TargetPlatform.ohos:\n{indent}")
        cursor = position
    pieces.append(text[cursor:])
    return "".join(pieces), len(insertions)


def iter_dart_files(path: Path):
    for dart in sorted(path.rglob("*.dart")):
        if dart.is_file():
            yield dart


def backup_key(path: Path) -> str:
    return hashlib.sha1(str(path).encode("utf-8")).hexdigest()[:16]


def apply_patch() -> int:
    package_dirs = load_package_dirs()
    missing = [name for name in PACKAGES if name not in package_dirs]
    if missing:
        print(f"[skip] 依赖图里没有：{', '.join(missing)}")

    backup_root = repo_root() / BACKUP_DIR
    backup_root.mkdir(parents=True, exist_ok=True)

    changed_files = 0
    changed_sites = 0
    for name, package_dir in sorted(package_dirs.items()):
        for dart in iter_dart_files(package_dir / "lib"):
            original = dart.read_text(encoding="utf-8")
            patched, count = patch_source(original)
            if count == 0:
                continue
            key = backup_key(dart)
            backup_file = backup_root / f"{key}.dart"
            if not backup_file.exists():
                backup_file.write_text(original, encoding="utf-8")
                (backup_root / f"{key}.json").write_text(
                    json.dumps({"path": str(dart)}), encoding="utf-8"
                )
            dart.write_text(patched, encoding="utf-8")
            changed_files += 1
            changed_sites += count
            print(f"[patch] {name}: {dart.name} (+{count})")

    if changed_files == 0:
        print("[ok] 没有需要补的 switch")
    else:
        print(f"[ok] 改了 {changed_files} 个文件，插入 {changed_sites} 个 case")
    return 0


def restore_patch() -> int:
    backup_root = repo_root() / BACKUP_DIR
    if not backup_root.exists():
        print("[ok] 没有备份，无需还原")
        return 0

    restored = 0
    for meta in sorted(backup_root.glob("*.json")):
        key = meta.stem
        backup_file = backup_root / f"{key}.dart"
        target = Path(json.loads(meta.read_text(encoding="utf-8"))["path"])
        if not backup_file.exists():
            continue
        if target.exists():
            target.write_text(backup_file.read_text(encoding="utf-8"), encoding="utf-8")
        backup_file.unlink()
        meta.unlink()
        restored += 1
        print(f"[restore] {target.name}")

    if restored == 0:
        print("[ok] 没有需要还原的文件")
    return 0


def show_status() -> int:
    backup_root = repo_root() / BACKUP_DIR
    if not backup_root.exists():
        print("[status] 干净（没有补丁备份）")
        return 0
    metas = sorted(backup_root.glob("*.json"))
    print(f"[status] 有 {len(metas)} 个文件处于已打补丁状态")
    for meta in metas:
        print(f"  {json.loads(meta.read_text(encoding='utf-8'))['path']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="补 TargetPlatform.ohos 分支")
    parser.add_argument("action", choices=("apply", "restore", "status"))
    args = parser.parse_args()
    if args.action == "apply":
        return apply_patch()
    if args.action == "restore":
        return restore_patch()
    return show_status()


if __name__ == "__main__":
    sys.exit(main())
