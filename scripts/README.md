# scripts/ — N3 데이터 수집 파이프라인

N1 의 `jlpt/scripts/` (다른 레포) 와 같은 흐름:
1. nihonez.com 페이지에서 reading 문제 + listening 메타 추출
2. listening admin-ajax 호출로 정답/스크립트 받음
3. mp3 다운로드
4. (선택) Whisper 로 listening script 재생성
5. 한국어 해설 작성
6. `assets/data/index.json` 빌드

## 의존성

```bash
pip install requests beautifulsoup4 lxml
```

## 실행

```bash
# 11회차 전체
python3 scripts/scrape-n3.py

# 특정 회차만
python3 scripts/scrape-n3.py n3_2025-07
```

## 현재 상태

✅ URL 11개 목록 + admin-ajax 호출 코드 (N1 scrape-listening.py 와 동일 패턴)
❌ `parse_reading()` 안 — reading 문제 selector 미구현 (TODO)
❌ listening 부분도 미구현 (jlpt 레포의 scripts/scrape-listening.py 의
   parse_listening_page 함수 가져와서 N3 에 맞게 어댑트 필요)
❌ Whisper transcribe — N1 의 transcribe-listening.py 참고
❌ 한국어 해설 ~700개 작성

## 다음 작업 단계

1. `parse_reading()` 채우기:
   - 페이지 DOM 또는 `testData` JS 변수 분석
   - 각 subsection 의 question 배열 → `Question[]` 변환
   - passage 별도 dict 로 분리
2. listening 부분 통합:
   - jlpt 레포의 scrape-listening.py 복사 후 N3 URL 로 어댑트
   - mp3 다운로드 경로: `assets/audio/n2_<id>/<mondai-type>.mp3`
3. 한국어 해설:
   - 영어 explanation_en 을 한국어로 번역 (LLM)
   - 정답/핵심 이유/오답 분석 블록 단위로 구조화
4. `assets/data/index.json` 빌드:
   - 각 exam 의 questions/listening 카운트 + category_totals 집계
