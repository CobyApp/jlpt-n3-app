"""nihonez.com 에서 JLPT N3 reading + listening 크롤링.

기반: jlpt 레포의 scripts/scrape-listening.py (N1) 패턴을 N3 URL 로 어댑트.

수행 단계
1. 11개 N3 시험 페이지에서 reading 문제 + passages 추출
2. listening 페이지 (?start=test&section_id=...) 에서 admin-ajax 호출 →
   question_results JSON 받아옴 (정답 + script + opts)
3. mp3 다운로드 → assets/audio/n2_<id>/<mondai-type>.mp3
4. assets/data/exams/n2_<id>.json 저장

사용
    pip install requests beautifulsoup4 lxml
    python3 scripts/scrape-n3.py            # 11개 전부
    python3 scripts/scrape-n3.py n2_2025-07 # 특정 회차만

TODO 표시
  reading 문제 추출 selector — 페이지 DOM 분석 후 채워야 함.
  listening 부분은 N1 scrape-listening.py 의 parse_listening_page 그대로
  사용 가능 (URL 만 N3 로 바꿈).
"""
from __future__ import annotations
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DATA = ROOT / "assets" / "data" / "exams"
OUT_AUDIO = ROOT / "assets" / "audio"
OUT_DATA.mkdir(parents=True, exist_ok=True)
OUT_AUDIO.mkdir(parents=True, exist_ok=True)

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36")

EXAMS = {
    "n2_2025-07": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-july-2025-real-exam/",
    "n2_2024-12": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-december-2024-real-exam/",
    "n2_2024-07": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-july-2024-real-exam/",
    "n2_2023-12": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-december-2023-real-exam/",
    "n2_2023-07": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-july-2023-real-exam/",
    "n2_2022-12": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-december-2022-real-exam/",
    "n2_2022-07": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-july-2022-real-exam/",
    "n2_2021-12": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-december-2021-real-exam/",
    "n2_2021-07": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-july-2021-real-exam/",
    "n2_2020-12": "https://nihonez.com/jlpt-test/jlpt-n3-past-test-december-2020-real-exam/",
    "n2_2018-vol2": "https://nihonez.com/jlpt-test/jlpt-n3-mock-test-vol-2/",
}


def http_get(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", errors="replace")


def http_post(url: str, data: dict) -> bytes:
    body = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(
        url, data=body,
        headers={"User-Agent": UA,
                 "Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def parse_test_data(html: str) -> dict:
    """페이지 JS 의 jlptTestData / testData 추출."""
    m = re.search(r"var\s+jlptTestData\s*=\s*({.*?});", html, re.S)
    if not m:
        raise RuntimeError("jlptTestData not found — login required?")
    jlpt = json.loads(m.group(1))

    m = re.search(r"var\s+testData\s*=\s*", html)
    if not m:
        raise RuntimeError("testData not found — try ?start=test param")
    start = m.end()
    depth, i = 0, start
    while i < len(html):
        c = html[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    test_data = json.loads(html[start:end])

    return {
        "ajaxurl": jlpt["ajaxurl"],
        "nonce": jlpt["nonce"],
        "test_data": test_data,
    }


def submit_test(ajaxurl: str, nonce: str, test_id: str, test_slug: str) -> dict:
    """admin-ajax 호출 → 정답/스크립트 받아옴."""
    raw = http_post(ajaxurl, {
        "action": "submit_jlpt_test",
        "security": nonce,
        "test_id": test_id,
        "answers": "{}",
        "test_slug": test_slug,
    })
    obj = json.loads(raw)
    if not obj.get("success"):
        raise RuntimeError(f"admin-ajax failed: {obj}")
    return obj["data"]["question_results"]


# ── TODO: reading questions / passages 추출 ───────────────────────
def parse_reading(html: str, test_data: dict) -> tuple[list, dict]:
    """
    nihonez N3 페이지에서 reading 문제 + passages 추출.

    N3 의 testData.sections[0]['subsections'] 구조를 분석 후 채워야 함.
    각 subsection 의 questions 배열에서 stem / opts / passage_ref 등을 추출.

    return: (questions[], passages{})
    """
    # TODO: 페이지 DOM 또는 testData JS 변수에서 reading 추출
    return [], {}


def scrape_one(exam_id: str, url: str):
    out = OUT_DATA / f"{exam_id}.json"
    sys.stderr.write(f"=== {exam_id} ===\n")

    # Test mode 로 페이지 fetch
    html = http_get(url + "?start=test")
    info = parse_test_data(html)

    # Reading
    questions, passages = parse_reading(html, info["test_data"])

    # Listening — N1 의 parse_listening_page 패턴 그대로 사용 가능
    # (구현은 jlpt repo 의 scripts/scrape-listening.py 참조)
    # TODO: 여기 listening 부분 가져오기

    out_data = {
        "test_id": exam_id,
        "title": f"JLPT N3 Mock Test — {exam_id}",
        "source_url": url,
        "scraped_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "passages": passages,
        "questions": questions,
        "listening": None,  # TODO
    }
    out.write_text(json.dumps(out_data, ensure_ascii=False, indent=2))
    sys.stderr.write(f"  wrote {out} ({len(questions)} questions, "
                     f"{len(passages)} passages)\n")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    items = [(k, v) for k, v in EXAMS.items() if not target or k == target]
    for exam_id, url in items:
        try:
            scrape_one(exam_id, url)
        except Exception as e:
            sys.stderr.write(f"  FAILED: {e}\n")
        time.sleep(1)  # be nice to the server


if __name__ == "__main__":
    main()
