# Release 배포 가이드

`release` 브랜치에 push 하면 `.github/workflows/release.yml` 워크플로우가
자동으로:
- **Android** `.aab` 빌드 → Play Console **내부 테스트** 트랙 업로드
- **iOS** `.ipa` 빌드 → **TestFlight** 업로드

빌드 번호는 GitHub Actions run 번호를 그대로 사용하므로 매번 단조 증가.

## 앱 식별자

| 플랫폼 | Identifier |
|---|---|
| iOS Bundle ID | `com.coby.jlpt.n3` |
| Android applicationId | `com.coby.jlpt.n3` |
| Apple Team ID | `3Y8YH8GWMM` |
| Apple Bundle ID 등록 | `TKX388RUG9` (API 로 자동 등록 완료) |
| iOS Provisioning Profile | `JLPT N3 AppStore` (API 로 자동 발급 완료) |

## ✅ 자동 등록 완료된 GitHub Secrets (13개)

모두 `gh secret set` CLI 로 일괄 등록됨.

| Secret | 출처 |
|---|---|
| `CERTIFICATE_BASE64` | `distribution.p12` |
| `CERTIFICATE_PASSWORD` | `king9205` |
| `KEYCHAIN_PASSWORD` | 랜덤 hex 16 |
| `APP_STORE_CONNECT_KEY_ID` | `MR4GXBK56L` |
| `APP_STORE_CONNECT_ISSUER_ID` | `bf885471-be9d-4c59-a418-bb0324c74837` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `AuthKey_MR4GXBK56L.p8` base64 |
| `IOS_TEAM_ID` | `3Y8YH8GWMM` |
| `PROVISIONING_PROFILE_BASE64` | App Store Connect API 로 발급 |
| `ANDROID_KEYSTORE_BASE64` | `keystore.rtf` 추출 (taba-key) |
| `ANDROID_KEYSTORE_PASSWORD` | `king9205` |
| `ANDROID_KEY_ALIAS` | `taba-key` |
| `ANDROID_KEY_PASSWORD` | `king9205` |
| `PLAY_SERVICE_ACCOUNT_JSON` | `taba-478813-405f9356702b.json` |

## ❌ 사람 손이 필요한 2단계 (앱 등록 자체는 API 가 막혀있음)

### 1. App Store Connect 에 앱 등록

https://appstoreconnect.apple.com → **My Apps → "+" → New App**

- Platform: iOS
- Name: `엔쓰리노트`
- Primary Language: Korean (Korea)
- Bundle ID: `com.coby.jlpt.n3 - JLPT N3` (목록에 보임 — API 로 이미 등록됨)
- SKU: `JLPT-N3-001` (또는 아무 unique 값)
- User Access: Full Access

### 2. Play Console 에 앱 등록

https://play.google.com/console → **앱 만들기**

- 앱 이름: `엔쓰리노트`
- 기본 언어: 한국어
- 앱 또는 게임: 앱
- 무료 또는 유료: 무료
- 정책 동의

생성 후 **사용자 및 권한 → 새 사용자 초대**:
- 이메일: `taba-ci-cd@taba-478813.iam.gserviceaccount.com`
- 권한: 모든 앱 접근 권한 또는 jlpt-app 에 대해 **"릴리스 관리자"** 권한

## 트리거

위 두 단계 끝나면:

```bash
cd /Users/doyoung_kim/Documents/Git/jlpt-app
git checkout -b release
git push origin release
```

또는 GitHub Actions 탭 → "Release" 워크플로우 → **Run workflow** 수동 실행.

## 빌드 번호

워크플로우가 `--build-number=$GITHUB_RUN_NUMBER` 를 자동 주입하므로
`pubspec.yaml` 의 `+N` 부분은 안 건드려도 됨. `version` 의 semver
(`x.y.z`) 만 사람이 올림.

## 빌드 산출물

CI 가 실패해도 `.aab` / `.ipa` 는 Actions 의 Artifacts 에서 다운로드 가능.

## 로컬 재현

```bash
flutter build appbundle --release --build-number=999
flutter build ipa --release --build-number=999
```
