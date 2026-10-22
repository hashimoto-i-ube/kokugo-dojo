#!/usr/bin/env python3
"""content/src の原稿から content/packs/*.json と content/manifest.json を生成する。

使い方:
    python3 scripts/build_content.py          # 生成
    python3 scripts/build_content.py --check  # 生成物が最新か検査のみ（CI 用）

原稿の形式は docs/CONTENT_FORMAT.md を参照。
内容が変わったパックだけ version を当日の日付（YYYY.M.D[.n]）に更新する。
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "content" / "src"
OUT = ROOT / "content" / "packs"
MANIFEST = ROOT / "content" / "manifest.json"
SCHEMA = 1
SUBJECTS = {"kanji", "vocabulary", "modernReading", "kobunWords", "kobunGrammar", "kanbun", "knowledge"}
FIELD_SEP = re.compile(r"(?<=\s)\|(?=\s|$)")  # 列の区切り（前後に空白のある |）
SEP = ";"  # 誤答選択肢の区切り

errors: list[str] = []


def err(where: str, msg: str) -> None:
    errors.append(f"{where}: {msg}")


def plain(s: str) -> str:
    s = re.sub(r"\{([^{}|]*)\|[^{}]*\}", r"\1", s)
    s = re.sub(r"\[\[([^\]]*?)(\|[^\]]*)?\]\]", r"\1", s)
    return s.replace("**", "")


def check_markup(where: str, s: str) -> None:
    if s.count("[[") != s.count("]]"):
        err(where, f"傍線 [[ ]] の対応が取れていません: {s}")
    if s.count("**") % 2:
        err(where, f"傍点 ** の対応が取れていません: {s}")
    if s.count("{") != s.count("}"):
        err(where, f"ルビ {{ }} の対応が取れていません: {s}")


def item_id(deck_id: str, prompt: str, answer: str) -> str:
    h = hashlib.sha1(f"{plain(prompt)}\t{plain(answer)}".encode()).hexdigest()[:8]
    return f"{deck_id}-{h}"


def parse_deck(path: Path) -> dict:
    meta: dict[str, str] = {}
    items = []
    lines = path.read_text(encoding="utf-8").splitlines()
    header_seen = False
    for n, raw in enumerate(lines, 1):
        where = f"{path.relative_to(ROOT)}:{n}"
        if not raw.strip():
            continue
        if raw.startswith("#"):
            if ":" in raw:
                k, v = raw[1:].split(":", 1)
                meta[k.strip()] = v.strip()
            continue
        cols = [c.strip() for c in FIELD_SEP.split(raw)]
        if not header_seen and cols[0] == "level":
            header_seen = True
            continue
        while len(cols) < 6:
            cols.append("")
        level, prompt, answer, note, distractors, explicit_id = (c.strip() for c in cols[:6])
        if not level.isdigit() or not 1 <= int(level) <= 5:
            err(where, f"level は 1〜5: {level!r}")
            continue
        if not prompt or not answer:
            err(where, "prompt / answer が空です")
            continue
        for s in (prompt, answer, note):
            check_markup(where, s)
        it = {
            "id": explicit_id or item_id(meta.get("id", path.stem), prompt, answer),
            "level": int(level),
            "prompt": prompt.replace("\\n", "\n"),
            "answer": answer,
        }
        if distractors:
            it["distractors"] = [d.strip() for d in distractors.split(SEP) if d.strip()]
            if answer in it["distractors"]:
                err(where, "誤答に正解が含まれています")
        if note:
            it["note"] = note.replace("\\n", "\n")
        items.append(it)
    deck_id = meta.get("id")
    if not deck_id:
        err(str(path), "#id がありません")
        deck_id = path.stem
    kind = meta.get("kind", "flash")
    if kind == "choice":
        for it in items:
            if len(it.get("distractors", [])) < 2:
                err(str(path), f"choice 形式は誤答 2 つ以上が必要: {it['prompt']}")
    deck = {"id": deck_id, "title": meta.get("title", deck_id), "kind": kind, "items": items}
    for k in ("description", "instruction", "writing"):
        if meta.get(k):
            deck[k] = meta[k]
    if meta.get("kanbun", "").lower() == "true":
        deck["kanbun"] = True
    return deck


def parse_lesson(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"\s*<!--(.*?)-->", text, re.S)
    if not m:
        err(str(path), "先頭に <!-- id: / title: / level: --> が必要です")
        return {}
    meta = dict(
        (k.strip(), v.strip())
        for k, v in (line.split(":", 1) for line in m.group(1).strip().splitlines() if ":" in line)
    )
    return {
        "id": meta["id"],
        "title": meta["title"],
        "level": int(meta.get("level", 1)),
        "body": text[m.end():].strip(),
    }


def parse_passage(path: Path) -> dict:
    p = json.loads(path.read_text(encoding="utf-8"))
    for k in ("id", "title", "genre", "level", "text", "questions"):
        if k not in p:
            err(str(path), f"{k} がありません")
    if isinstance(p.get("text"), list):
        p["text"] = "\n\n".join(p["text"])
    check_markup(str(path), p.get("text", ""))
    for i, q in enumerate(p.get("questions", [])):
        q.setdefault("id", f"{p['id']}-q{i + 1}")
        if not 0 <= q.get("answer", -1) < len(q.get("choices", [])):
            err(str(path), f"問{i + 1} の answer が choices の範囲外です")
    return p


def build_pack(pack_dir: Path) -> dict:
    meta = json.loads((pack_dir / "pack.json").read_text(encoding="utf-8"))
    if meta.get("subject") not in SUBJECTS:
        err(str(pack_dir), f"subject が不正: {meta.get('subject')}")
    pack = {
        "schemaVersion": SCHEMA,
        "id": meta["id"],
        "subject": meta["subject"],
        "title": meta["title"],
        "version": "",
        "curriculum": meta.get("curriculum", "H30"),
        "decks": [parse_deck(p) for p in sorted(pack_dir.glob("*.deck"))],
    }
    lessons = [parse_lesson(p) for p in sorted((pack_dir / "lessons").glob("*.html"))]
    passages = [parse_passage(p) for p in sorted((pack_dir / "passages").glob("*.json"))]
    if lessons:
        pack["lessons"] = [l for l in lessons if l]
    if passages:
        pack["passages"] = passages
    return pack


def next_version(old: str | None, today: dt.date) -> str:
    base = f"{today.year}.{today.month}.{today.day}"
    if old and (old == base or old.startswith(base + ".")):
        parts = old.split(".")
        n = int(parts[3]) + 1 if len(parts) > 3 else 1
        return f"{base}.{n}"
    return base


def dumps(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, indent=1) + "\n"


def main() -> int:
    check_only = "--check" in sys.argv
    today = dt.date.today()
    meta = json.loads((SRC / "meta.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    stale = []
    outputs: list[tuple[Path, str]] = []
    seen_ids: dict[str, str] = {}
    for pack_dir in sorted(p for p in SRC.iterdir() if (p / "pack.json").exists()):
        pack = build_pack(pack_dir)
        for d in pack["decks"]:
            for it in d["items"]:
                if it["id"] in seen_ids:
                    err(d["id"], f"ID 重複 {it['id']}（{plain(it['prompt'])}）")
                seen_ids[it["id"]] = d["id"]
        out = OUT / f"{pack['id']}.json"
        old = json.loads(out.read_text(encoding="utf-8")) if out.exists() else None
        old_version = old.get("version") if old else None
        if old and {**old, "version": ""} == pack:
            pack["version"] = old_version
        else:
            pack["version"] = next_version(old_version, today)
            stale.append(pack["id"])
        text = dumps(pack)
        outputs.append((out, text))
        data = text.encode()
        entries.append({
            "id": pack["id"],
            "file": f"packs/{out.name}",
            "version": pack["version"],
            "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
        })
        n_items = sum(len(d["items"]) for d in pack["decks"])
        n_q = sum(len(p["questions"]) for p in pack.get("passages", []))
        print(f"{pack['id']:<14} v{pack['version']:<12} 項目 {n_items:>4}  読解設問 {n_q:>3}  解説 {len(pack.get('lessons', []))}")

    if errors:
        print("\n".join(["", "エラー:"] + errors), file=sys.stderr)
        return 1
    manifest = {
        "schemaVersion": SCHEMA,
        "minAppVersion": meta["minAppVersion"],
        "curriculum": meta["curriculum"],
        "curriculumNote": meta.get("curriculumNote"),
        "generatedAt": today.isoformat(),
        "packs": entries,
    }
    if not check_only:
        for path, text in outputs:
            path.write_text(text, encoding="utf-8")
    if check_only:
        if stale:
            print(f"\n未生成の変更があります: {', '.join(stale)}（build_content.py を実行してください）", file=sys.stderr)
            return 1
        print("\nOK")
        return 0
    old_manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else None
    if old_manifest and {**old_manifest, "generatedAt": ""} == {**manifest, "generatedAt": ""}:
        manifest["generatedAt"] = old_manifest["generatedAt"]
    MANIFEST.write_text(dumps(manifest), encoding="utf-8")
    print(f"\n合計 {len(seen_ids)} 項目を生成しました")
    return 0


if __name__ == "__main__":
    sys.exit(main())
