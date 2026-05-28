"""expl_ko 작업 보조 도구.

digest: 한 회차의 문제를 해설 작성에 필요한 최소 필드로 추려 출력.
    python3 scripts/expl_tools.py digest n2_2025-07 reading
    python3 scripts/expl_tools.py digest n2_2025-07 listening

merge: {qid: "expl_ko 텍스트"} JSON 을 회차 파일의 expl_ko 에 병합.
    python3 scripts/expl_tools.py merge n2_2025-07 /tmp/explko_n2_2025-07.json

status: 전체 회차의 expl_ko 채움 현황.
    python3 scripts/expl_tools.py status
"""
import json
import re
import sys
import glob
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EX = ROOT / "assets" / "data" / "exams"


def trim(s, n):
    s = re.sub(r"<[^>]+>", "", s or "")
    s = re.sub(r"\s+", " ", s).strip()
    return s[:n]


def digest(eid, kind):
    d = json.loads((EX / f"{eid}.json").read_text())
    rows = []
    if kind == "reading":
        pas = d["passages"]
        last_p = None
        for q in d["questions"]:
            item = {"id": q["id"], "n": q["n"], "cat": q["category"],
                    "stem": trim(q["stem"], 160), "u": q.get("stem_u", ""),
                    "opts": q["opts"], "ans": (q["correct"] + 1),
                    "en": trim(q["expl"], 360)}
            pk = q.get("passage")
            if pk and pk in pas and pk != last_p:
                item["passage"] = trim(pas[pk]["ja"], 500)
                last_p = pk
            elif pk:
                item["passage_ref"] = pk
            rows.append(item)
    else:
        for s in d["listening"]["subsections"]:
            for q in s["questions"]:
                rows.append({"id": q["id"], "n": q["n"], "type": s["type"],
                             "opts": q["opts"], "ans": (q["correct"] + 1),
                             "script": trim(q["script_html"], 600),
                             "en": trim(q.get("explanation_en", ""), 300)})
    for r in rows:
        print(json.dumps(r, ensure_ascii=False))


def merge(eid, path):
    d = json.loads((EX / f"{eid}.json").read_text())
    m = json.loads(Path(path).read_text())
    n = 0
    for q in d["questions"]:
        if q["id"] in m and m[q["id"]]:
            q["expl_ko"] = m[q["id"]]; n += 1
    for s in d["listening"]["subsections"]:
        for q in s["questions"]:
            if q["id"] in m and m[q["id"]]:
                q["expl_ko"] = m[q["id"]]; n += 1
    (EX / f"{eid}.json").write_text(json.dumps(d, ensure_ascii=False, indent=2))
    print(f"merged {n} expl_ko into {eid}.json")


def merge_script(eid, path):
    """{qid: script_html} 를 청해 script_html 에 병합 (Whisper 전사용)."""
    d = json.loads((EX / f"{eid}.json").read_text())
    m = json.loads(Path(path).read_text())
    n = 0
    for s in d["listening"]["subsections"]:
        for q in s["questions"]:
            if q["id"] in m and m[q["id"]]:
                q["script_html"] = m[q["id"]]; n += 1
    (EX / f"{eid}.json").write_text(json.dumps(d, ensure_ascii=False, indent=2))
    print(f"merged {n} script_html into {eid}.json")


def status():
    for f in sorted(glob.glob(str(EX / "n?_*.json"))):
        d = json.loads(Path(f).read_text())
        rq = d["questions"]
        lq = [q for s in d["listening"]["subsections"] for q in s["questions"]]
        rk = sum(1 for q in rq if (q.get("expl_ko") or "").strip())
        lk = sum(1 for q in lq if (q.get("expl_ko") or "").strip())
        ls = sum(1 for q in lq if (q.get("script_html") or "").strip())
        print(f"  {d['test_id']}: reading expl_ko {rk}/{len(rq)} | "
              f"listening expl_ko {lk}/{len(lq)} | script {ls}/{len(lq)}")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "digest":
        digest(sys.argv[2], sys.argv[3])
    elif cmd == "merge":
        merge(sys.argv[2], sys.argv[3])
    elif cmd == "merge_script":
        merge_script(sys.argv[2], sys.argv[3])
    elif cmd == "status":
        status()
