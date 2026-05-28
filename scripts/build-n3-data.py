"""N3 exam 데이터 빌더 — nihonez.com 로그인 세션으로 시험 콘텐츠를 받아
N1(jlpt-app) 과 동일한 스키마의 assets/data/exams/n2_<id>.json 을 생성한다.

데이터 소스 (사이트 개편 후 현재 구조):
  1. 로그인된 시험 페이지 HTML (?start=test)
       - window.testData : 섹션/서브섹션 구조 (question_from/to, category, type)
       - DOM .test-subsection : intro(h3), 청해 <audio>, 독해 .jlpt-passages,
         .question-container(문제 본문/밑줄어/선택지)
  2. admin-ajax submit_jlpt_test (mode=practice, test_slug_in_question_post_type)
       → question_results[qid] = correct_answer, question_type, explaination,
         listening_script, listening_script_translation, possible_points

쿠키: /tmp/nz_cookie.txt (Chrome Profile 1 wordpress_logged_in_* 복호화본)

사용:
    python3 scripts/build-n3-data.py            # 11회차 전체 → assets/data/exams/
    python3 scripts/build-n3-data.py n2_2025-07 # 특정 회차
    OUT=/tmp/out python3 scripts/build-n3-data.py n2_2025-07   # 출력 경로 변경
"""
from __future__ import annotations
import html as htmllib
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = Path(os.environ.get("OUT") or (ROOT / "assets" / "data" / "exams"))
COOKIE = Path("/tmp/nz_cookie.txt").read_text().strip()
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")

EXAMS = {
    "n3_2025-07": "jlpt-n3-past-test-july-2025-real-exam",
    "n3_2024-12": "jlpt-n3-past-test-december-2024-real-exam",
    "n3_2024-07": "jlpt-n3-past-test-july-2024-real-exam",
    "n3_2023-12": "jlpt-n3-past-test-december-2023-real-exam",
    "n3_2023-07": "jlpt-n3-past-test-july-2023-real-exam",
    "n3_2022-12": "jlpt-n3-past-test-december-2022-real-exam",
    "n3_2022-07": "jlpt-n3-past-test-july-2022-real-exam",
    "n3_2021-12": "jlpt-n3-past-test-december-2021-real-exam",
    "n3_2021-07": "jlpt-n3-past-test-july-2021-real-exam",
    "n3_2020-12": "jlpt-n3-past-test-december-2020-real-exam",
    "n3_2019-12": "jlpt-n3-past-test-december-2019-real-exam",
    "n3_2019-07": "jlpt-n3-past-test-july-2019-real-exam",
    "n3_2018-12": "jlpt-n3-past-test-december-2018-real-exam",
    "n3_2018-07": "jlpt-n3-past-test-july-2018-real-exam",
    "n3_2017-12": "jlpt-n3-past-test-december-2017-real-exam",
    "n3_2018-vol2": "jlpt-official-practice-workbook-vol-2-published-2018-n3",
}
TITLE = {
    "n3_2025-07": "JLPT N3 Mock Test – July 2025",
    "n3_2024-12": "JLPT N3 Mock Test – December 2024",
    "n3_2024-07": "JLPT N3 Mock Test – July 2024",
    "n3_2023-12": "JLPT N3 Mock Test – December 2023",
    "n3_2023-07": "JLPT N3 Mock Test – July 2023",
    "n3_2022-12": "JLPT N3 Mock Test – December 2022",
    "n3_2022-07": "JLPT N3 Mock Test – July 2022",
    "n3_2021-12": "JLPT N3 Mock Test – December 2021",
    "n3_2021-07": "JLPT N3 Mock Test – July 2021",
    "n3_2020-12": "JLPT N3 Mock Test – December 2020",
    "n3_2019-12": "JLPT N3 Mock Test – December 2019",
    "n3_2019-07": "JLPT N3 Mock Test – July 2019",
    "n3_2018-12": "JLPT N3 Mock Test – December 2018",
    "n3_2018-07": "JLPT N3 Mock Test – July 2018",
    "n3_2017-12": "JLPT N3 Mock Test – December 2017",
    "n3_2018-vol2": "JLPT N3 Mock Test – Vol 2 (2018)",
}
LISTENING_TYPES = ["task-based-comprehension", "comprehension-of-key-points",
                   "comprehension-general-outline", "quick-response",
                   "listening-integrated-comprehension"]


# ── HTTP ──────────────────────────────────────────────────────────
def http_get(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Cookie": COOKIE})
    return urllib.request.urlopen(req, timeout=90).read().decode("utf-8", "replace")


def http_post(url: str, data: dict) -> bytes:
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={
        "User-Agent": UA, "Cookie": COOKIE,
        "Content-Type": "application/x-www-form-urlencoded"})
    return urllib.request.urlopen(req, timeout=120).read()


# ── HTML helpers ─────────────────────────────────────────────────
def strip_to_text(frag: str, keep_breaks=True) -> str:
    """ruby reading(<rt>) 제거, <br>→\\n, 나머지 태그 제거, 엔티티 복원."""
    frag = re.sub(r"<rt>.*?</rt>", "", frag, flags=re.S)
    frag = re.sub(r"<rp>.*?</rp>", "", frag, flags=re.S)
    if keep_breaks:
        frag = re.sub(r"<br\s*/?>", "\n", frag)
        frag = re.sub(r"</(p|div|h3)>", "\n", frag)
    frag = re.sub(r"<[^>]+>", "", frag)
    frag = htmllib.unescape(frag)
    frag = re.sub(r"[ \t]+", " ", frag)
    frag = re.sub(r"\n{3,}", "\n\n", frag)
    return frag.strip()


def extract_balanced(s: str, start: int, tag="div") -> tuple[str, int]:
    """s[start] 가 <tag ...> 시작이라 가정, 균형 맞는 닫힘까지 반환 → (block, end_idx)."""
    open_re = re.compile(rf"<{tag}\b", re.I)
    close_re = re.compile(rf"</{tag}>", re.I)
    depth = 0
    i = start
    while i < len(s):
        mo = open_re.match(s, i)
        mc = close_re.match(s, i)
        if mo:
            depth += 1
            i = mo.end()
        elif mc:
            depth -= 1
            i = mc.end()
            if depth == 0:
                return s[start:i], i
        else:
            i += 1
    return s[start:], len(s)


# ── parse one question-container block ───────────────────────────
def parse_question(block: str) -> dict | None:
    mid = re.search(r'id="question-(\d+)"', block)
    if not mid:
        return None
    qid = mid.group(1)
    mo = re.search(r'class="question-order">(\d+)<', block)
    order = int(mo.group(1)) if mo else None
    mc = re.search(r'class="question-content">(.*?)</div>', block, re.S)
    content = mc.group(1) if mc else ""
    mu = re.search(r'text-decoration:\s*underline[^>]*>(.*?)</span>', content, re.S)
    stem_u = strip_to_text(mu.group(1), keep_breaks=False) if mu else ""
    stem = strip_to_text(content, keep_breaks=False)
    opts = []
    for cm in re.finditer(r'class="choice-text-furigana">(.*?)</span>', block, re.S):
        opts.append(strip_to_text(cm.group(1), keep_breaks=False))
    if not opts:  # some choices may lack furigana span; fall back to answer label text
        for cm in re.finditer(r'class="answer-choice"[^>]*>(.*?)</label>', block, re.S):
            t = re.sub(r'class="answer-order">.*?</span>', "", cm.group(1), flags=re.S)
            opts.append(strip_to_text(t, keep_breaks=False))
    return {"id": qid, "order": order, "stem": stem, "stem_u": stem_u, "opts": opts}


# ── parse full page DOM into subsections ─────────────────────────
def parse_subsections(html: str) -> list[dict]:
    subs = []
    for m in re.finditer(r'<div class="test-subsection" id="subsection-(\d+)-(\d+)"', html):
        sec, sub = int(m.group(1)), int(m.group(2))
        block, _ = extract_balanced(html, m.start())
        # intro (first h3)
        mh = re.search(r"<h3>(.*?)</h3>", block, re.S)
        intro_html = mh.group(1).strip() if mh else ""
        # audio
        ma = re.search(r'<audio[^>]*>\s*<source[^>]*src="([^"]+)"', block, re.S)
        audio_src = ma.group(1) if ma else None
        # passage-question-groups (passage + its questions)
        groups = []
        consumed = set()
        for pg in re.finditer(r'<div class="passage-question-group"', block):
            gblock, _ = extract_balanced(block, pg.start())
            # passage text
            ptexts = []
            for pm in re.finditer(r'<div class="jlpt-passages">(.*?)</div>\s*</div>', gblock, re.S):
                pass
            # grab passage area: everything inside jlpt-passages-wrapper's .passage(s)
            for pm in re.finditer(r'<div class="passage">(.*?)</div>', gblock, re.S):
                t = strip_to_text(pm.group(1))
                if t:
                    ptexts.append(t)
            passage_text = "\n\n".join(ptexts).strip()
            qs = []
            for qm in re.finditer(r'<div class="question-container"', gblock):
                qb, _ = extract_balanced(gblock, qm.start())
                q = parse_question(qb)
                if q:
                    qs.append(q)
                    consumed.add(q["id"])
            groups.append({"passage": passage_text, "questions": qs})
        # loose questions (not in any passage group)
        loose = []
        for qm in re.finditer(r'<div class="question-container"', block):
            qb, _ = extract_balanced(block, qm.start())
            q = parse_question(qb)
            if q and q["id"] not in consumed:
                loose.append(q)
        subs.append({"sec": sec, "sub": sub, "intro_html": intro_html,
                     "audio_src": audio_src, "groups": groups, "loose": loose})
    return subs


def extract_testdata(html: str) -> dict:
    m = re.search(r"(?:window\.testData|var\s+testData)\s*=\s*", html)
    i = m.end()
    while html[i] in " \n\t":
        i += 1
    depth = 0
    start = i
    instr = False
    esc = False
    q = ""
    while i < len(html):
        c = html[i]
        if instr:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == q:
                instr = False
        else:
            if c in "\"'":
                instr = True
                q = c
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return json.loads(html[start:i + 1])
        i += 1
    raise RuntimeError("testData not found")


def title_case_slug(slug: str) -> str:
    return " ".join(w.capitalize() for w in slug.replace("_", "-").split("-"))


def build(exam_id: str):
    slug = EXAMS[exam_id]
    url = f"https://nihonez.com/jlpt-test/{slug}/"
    sys.stderr.write(f"=== {exam_id} ({slug}) ===\n")
    html = http_get(url + "?start=test")
    td = extract_testdata(html)
    nonce = re.search(r'"nonce"\s*:\s*"([^"]+)"', html).group(1)
    ajax = re.search(r'"ajaxurl"\s*:\s*"([^"]+)"', html).group(1)
    test_id = str(td.get("testId"))
    qids = sorted(set(re.findall(r'name="question-(\d+)"', html)), key=int)

    # submit (practice mode) → question_results
    answers = {q: "0" for q in qids}
    resp = http_post(ajax, {
        "action": "submit_jlpt_test", "security": nonce, "test_id": test_id,
        "answers": json.dumps(answers),
        "test_slug_in_question_post_type": td.get("test_slug_in_question_post_type"),
        "mode": "practice", "time_spent": "60",
    })
    qr = json.loads(resp)["data"]["question_results"]
    if not isinstance(qr, dict) or not qr:
        raise RuntimeError(f"empty question_results for {exam_id}")

    subs = parse_subsections(html)
    td_secs = td["sections"]

    reading_questions = []
    passages = {}
    listening = {"section_url": url, "title": "聴解", "subsections": []}

    for s in subs:
        sec, sub = s["sec"], s["sub"]
        td_sub = td_secs[sec]["subsections"][sub] if sec < len(td_secs) and sub < len(td_secs[sec]["subsections"]) else {}
        if s["audio_src"] is not None or sec == len(td_secs) - 1 and s["audio_src"]:
            pass  # handled below by listening branch

        is_listening = (s["audio_src"] is not None) or (td_secs[sec].get("english_title", "").lower().startswith("listening"))

        if not is_listening:
            # reading/vocab/grammar
            def emit(q, passage_key):
                qr_q = qr.get(q["id"], {})
                ca = qr_q.get("correct_answer")
                correct = (int(ca) - 1) if ca not in (None, "") else None
                reading_questions.append({
                    "n": q["order"], "id": q["id"], "passage": passage_key,
                    "stem": q["stem"], "opts": q["opts"], "correct": correct,
                    "category": qr_q.get("question_type", ""),
                    "expl": (qr_q.get("explaination") or "").strip(),
                    "expl_ko": "", "stem_u": q["stem_u"],
                })
            for g in s["groups"]:
                if not g["questions"]:
                    continue
                key = f"p_question-{g['questions'][0]['id']}"
                if g["passage"]:
                    passages[key] = {"ja": g["passage"]}
                for q in g["questions"]:
                    emit(q, key if g["passage"] else None)
            for q in s["loose"]:
                emit(q, None)
        else:
            # listening subsection
            qs_out = []
            allq = [q for g in s["groups"] for q in g["questions"]] + s["loose"]
            allq.sort(key=lambda q: (q["order"] is None, q["order"] or 0))
            slug_type = td_sub.get("question_type") or LISTENING_TYPES[len(listening["subsections"])]
            for q in allq:
                qr_q = qr.get(q["id"], {})
                ca = qr_q.get("correct_answer")
                correct = (int(ca) - 1) if ca not in (None, "") else None
                # source listening_script is already full HTML (<div class="jlpt-passages">…)
                script_html = (qr_q.get("listening_script") or "").strip()
                qs_out.append({
                    "id": q["id"], "n": q["order"], "opts_html": q["opts"], "opts": q["opts"],
                    "correct": correct, "script_html": script_html,
                    "translation_en": (qr_q.get("listening_script_translation") or "").strip(),
                    "explanation_en": (qr_q.get("explaination") or "").strip(),
                    "points": qr_q.get("possible_points"), "expl_ko": "",
                })
            order = len(listening["subsections"]) + 1
            listening["subsections"].append({
                "order": order, "title": td_sub.get("title", f"問題{order}"),
                "english_title": title_case_slug(slug_type),
                "type": slug_type, "intro_html": s["intro_html"],
                "audio_url": f"https://taba.asia/jlpt-audio/{exam_id}/{slug_type}.mp3",
                "audio_source_url": s["audio_src"], "questions": qs_out,
            })

    out = {
        "test_id": exam_id, "title": TITLE.get(exam_id, exam_id),
        "source_url": url, "scraped_at": time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime()),
        "passages": passages, "questions": reading_questions, "listening": listening,
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / f"{exam_id}.json").write_text(json.dumps(out, ensure_ascii=False, indent=2))
    nlq = sum(len(ss["questions"]) for ss in listening["subsections"])
    sys.stderr.write(f"  wrote {exam_id}.json  reading={len(reading_questions)} "
                     f"passages={len(passages)} listen_subs={len(listening['subsections'])} "
                     f"listen_q={nlq}\n")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    ids = [target] if target else list(EXAMS.keys())
    for eid in ids:
        try:
            build(eid)
        except Exception as e:
            sys.stderr.write(f"  FAILED {eid}: {e!r}\n")
        time.sleep(1)


if __name__ == "__main__":
    main()
