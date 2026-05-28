# 엔쓰리노트 (JLPT N3)

JLPT N3 학습 앱 — `jlpt-app` (N1) 의 자매 프로젝트. Flutter 골격 + 주황 테마 + N3 식별자까지 완성. **데이터 (문제/청해 mp3) 는 아직 비어있음** — `scripts/scrape-n2.py` 로 nihonez.com 에서 수집해야 함.

## 빠른 실행

```bash
flutter pub get
flutter run
```

⚠️ 현재 `assets/data/index.json` 의 exams 배열이 비어있어 홈 화면이 비어 보입니다. 데이터 수집 후에야 회차 / 영역 카드가 채워짐.

## 식별자

| 플랫폼 | Identifier |
|---|---|
| iOS Bundle ID | `com.coby.jlpt.n3` |
| Android applicationId | `com.coby.jlpt.n3` |
| 앱 이름 | 엔쓰리노트 |
| 브랜드 컬러 | orange-500 (#F97316) |

## 디렉토리 구조

```
jlpt-n3-app/
├── lib/                  # Flutter 코드 (N1 와 동일)
├── assets/
│   ├── data/
│   │   ├── index.json    # 빈 placeholder
│   │   ├── exams/        # 비어있음 — 크롤링 후 채움
│   │   ├── vocab.json    # N1 의 일본어 사전 그대로 (공용)
│   │   └── kanji_ko.json
│   ├── audio/            # 비어있음 — 크롤링 후 채움
│   └── icon/             # N3 주황 jelly 아이콘
├── scripts/              # 크롤링/처리 스크립트
│   ├── scrape-n2.py
│   └── README.md
├── docs/                 # GitHub Pages (랜딩/정책)
└── .github/workflows/
    └── release.yml       # CI (Play/TestFlight upload 는 비활성 — secret 셋업 후 toggle)
```

## 데이터 수집

`scripts/README.md` 참고. nihonez.com 의 N3 페이지 11개에서 reading + listening + mp3 를 받아와 `assets/` 채우는 작업.

## 스토어 배포

`docs/STORE.md` 의 N1 텍스트를 N3 로 다듬어 사용. App Store Connect / Play Console 에 앱 등록 후 N1 과 동일한 secret 들을 GitHub repo 에 등록하면 자동 배포 가능.

## 라이선스

© 2026 Doyoung Kim
