"""구회차 청해 mp3 → faster-whisper 일본어 전사 → script_html 생성.

소스(nihonez)에 transcript 가 없는 회차의 청해 음성을 전사해
회차 JSON 의 listening script_html 을 채운다. (N1 의 transcribe-listening.py 대응)

서브섹션 오디오 1개에 여러 문제가 연속 재생되므로, 서브섹션 전체 전사를
해당 서브섹션의 모든 문제 script_html 에 부여한다.

    python3 scripts/transcribe-listening.py            # 스크립트 없는 회차 자동
    python3 scripts/transcribe-listening.py n2_2023-12 # 특정 회차

출력: /tmp/scripts_<eid>.json  ({qid: script_html})  → expl_tools.py merge_script 로 병합
"""
import html as htmllib
import json
import sys
import time
from pathlib import Path
from faster_whisper import WhisperModel

ROOT = Path(__file__).resolve().parent.parent
EX = ROOT / "assets" / "data" / "exams"
AUDIO = ROOT / "assets" / "audio"

NEED = ["n3_2017-12", "n3_2018-vol2", "n3_2022-07", "n3_2022-12",
        "n3_2023-07", "n3_2023-12", "n3_2024-07"]

_THREADS = int(__import__("os").environ.get("WHISPER_THREADS", "8"))
MODEL = WhisperModel("medium", device="cpu", compute_type="int8", cpu_threads=_THREADS)


def transcribe(path: Path) -> str:
    segments, _ = MODEL.transcribe(str(path), language="ja", beam_size=1,
                                   vad_filter=True,
                                   vad_parameters=dict(min_silence_duration_ms=600))
    return "".join(s.text for s in segments).strip()


def script_html(text: str) -> str:
    lines = [htmllib.escape(t.strip()) for t in text.replace("。", "。\n").splitlines() if t.strip()]
    body = "<br>".join(lines)
    return f'<div class="jlpt-passages"><div class="passage">{body}</div></div>'


def run(eid: str):
    d = json.loads((EX / f"{eid}.json").read_text())
    out = {}
    for s in d["listening"]["subsections"]:
        ap = AUDIO / eid / f"{s['type']}.mp3"
        if not ap.exists():
            sys.stdout.write(f"MISSING {eid}/{s['type']}.mp3\n"); sys.stdout.flush()
            continue
        t0 = time.time()
        text = transcribe(ap)
        sh = script_html(text)
        for q in s["questions"]:
            out[q["id"]] = sh
        sys.stdout.write(f"DONE {eid}/{s['type']} chars={len(text)} "
                         f"qs={len(s['questions'])} {time.time()-t0:.0f}s\n")
        sys.stdout.flush()
    Path(f"/tmp/scripts_{eid}.json").write_text(json.dumps(out, ensure_ascii=False))
    sys.stdout.write(f"WROTE /tmp/scripts_{eid}.json ({len(out)} questions)\n"); sys.stdout.flush()


def main():
    ids = [sys.argv[1]] if len(sys.argv) > 1 else NEED
    for eid in ids:
        sys.stdout.write(f"=== {eid} ===\n"); sys.stdout.flush()
        run(eid)
    sys.stdout.write("ALL DONE\n"); sys.stdout.flush()


if __name__ == "__main__":
    main()
