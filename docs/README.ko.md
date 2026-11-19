> [!IMPORTANT]
> **sniplite for Mac.** 이 저장소는 **macOS** 버전만 관리합니다([`macos`](../macos/README.md), [Releases](https://github.com/codeime/sniplite/releases/latest)에서 다운로드). **Windows** 버전은 원래 저장소에서 다운로드하세요: [MrTangLuyao/sniplite](https://github.com/MrTangLuyao/sniplite/releases/latest).

<div align="center">

<img src="../pics/macos/icon.png" width="96" alt="sniplite 아이콘">

# sniplite

**아주 가볍고 빠른 macOS 화면 캡처·고정 도구**

[![English](https://img.shields.io/badge/English-eaeef2?style=flat-square)](../README.md) [![简体中文](https://img.shields.io/badge/%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-eaeef2?style=flat-square)](README.zh-CN.md) [![繁體中文](https://img.shields.io/badge/%E7%B9%81%E9%AB%94%E4%B8%AD%E6%96%87-eaeef2?style=flat-square)](README.zh-TW.md) [![日本語](https://img.shields.io/badge/%E6%97%A5%E6%9C%AC%E8%AA%9E-eaeef2?style=flat-square)](README.ja.md) [![한국어](https://img.shields.io/badge/%ED%95%9C%EA%B5%AD%EC%96%B4-1677e5?style=flat-square)](README.ko.md) [![Français](https://img.shields.io/badge/Fran%C3%A7ais-eaeef2?style=flat-square)](README.fr.md) [![Deutsch](https://img.shields.io/badge/Deutsch-eaeef2?style=flat-square)](README.de.md) [![Español](https://img.shields.io/badge/Espa%C3%B1ol-eaeef2?style=flat-square)](README.es.md)

[![버전](https://img.shields.io/github/v/release/codeime/sniplite?label=%EB%B2%84%EC%A0%84&style=flat-square&color=1677e5)](https://github.com/codeime/sniplite/releases) [![시스템](https://img.shields.io/badge/%EC%8B%9C%EC%8A%A4%ED%85%9C-macOS%2014%2B-3b82f6?style=flat-square)](#다운로드) [![라이선스](https://img.shields.io/badge/%EB%9D%BC%EC%9D%B4%EC%84%A0%EC%8A%A4-MIT-3b82f6?style=flat-square)](../LICENSE)

[**다운로드**](#다운로드) | [기본 단축키](#기본-단축키) | [자주 묻는 질문](#자주-묻는-질문)

<img src="../pics/macos/edit.png" alt="영역을 선택하고 그 위에 바로 원, 화살표, 텍스트, 번호를 그립니다" width="66%">
<br>
<img src="../pics/macos/select.png" alt="캡처 전에 마우스 아래의 창과 컨트롤을 자동으로 찾아 주고, 돋보기로 픽셀과 색을 확인할 수 있습니다" width="32.5%"> <img src="../pics/macos/pin.png" alt="스크린샷이나 텍스트를 모든 창 위에 고정하고 휠로 확대/축소합니다" width="32.5%">
<br>
<img src="../pics/macos/ocr.png" alt="선택한 영역의 글자를 읽습니다. 표는 열을 유지합니다" width="66%">

</div>

## 특징

- **빠름**: F1을 누르면 바로 캡처할 수 있고, 모든 디스플레이를 지원합니다
- **자동 선택**: 마우스 아래의 창이나 창 안의 요소(버튼, 입력란, 목록)를 자동으로 고르고, 휠로 바깥쪽까지 넓힐 수 있습니다
- **그리기**: 사각형, 타원, 직선, 화살표, 펜, 형광펜, 글자, 번호, 모자이크. 도구마다 굵기와 불투명도를 기억하고, 그린 것은 나중에 다시 골라 바꿀 수 있습니다
- **고정**: 캡처나 복사한 내용을 모든 창 위에 고정합니다. 확대·축소, 불투명도 조절, 다시 편집이 됩니다
- **글자 인식**: 캡처의 글자를 표의 열까지 살려 읽습니다. Apple의 Vision으로 이 Mac에서 동작합니다(선택, 기본은 꺼짐)
- **가벼움**: 약 2 MB, Apple 실리콘과 Intel을 기본 지원, 대기 중 메모리 약 15–25 MB
- **깔끔함**: 오픈 소스, 광고 없음, 데이터를 모으거나 보내지 않습니다
- **언어**: English, 简体中文, 繁體中文 (시스템을 따름)

## 다운로드

[Releases](https://github.com/codeime/sniplite/releases/latest)에서 `sniplite_<버전>_macos.zip`을 내려받아 압축을 풀고 `sniplite.app`을 "응용 프로그램"으로 옮기세요. macOS 14 Sonoma 이상이 필요합니다.

sniplite는 Apple 공증을 받지 않아 처음에는 macOS가 막습니다("열 수 없음" 또는 "손상됨"). "응용 프로그램"으로 옮긴 뒤 한 번 실행하세요:

```bash
xattr -dr com.apple.quarantine "/Applications/sniplite.app"
```

> [!TIP]
> sniplite는 메뉴 막대(네 모서리 틀과 번개 아이콘)에 있고 Dock에는 나타나지 않습니다. 처음 실행하면 필요한 권한을 보여 줍니다: 캡처를 위한 "화면 기록"과, F1–F12 키와 창 안의 요소를 찾기 위한 "손쉬운 사용"입니다.

## 기본 단축키

| 키 | 동작 |
| --- | --- |
| **F1** | 캡처 |
| **⇧F1** | 빠른 캡처: 마우스가 있는 화면을 바로 파일로 저장(설정에서 켠 경우) |
| **F3** | 복사한 이미지나 글자를 고정 |
| **⇧F3** | 모든 고정 숨기기 / 보이기 |
| **F4** / **⇧F4** | 캡처하고 글자 읽기 / 복사(글자 인식이 켜져 있을 때) |
| **Enter** / 더블 클릭 | 캡처 복사 |
| **⌘S** | 저장 |
| **⌘T** / 가운데 클릭 | 고정 |
| **⌘Z** / **⇧⌘Z** | 실행 취소 / 다시 실행 |
| **Esc** / 오른쪽 클릭 | 한 단계 뒤로, 마지막에는 취소 |
| **화살표 키**, **W A S D** | 1픽셀 이동, Shift를 누르면 10픽셀 |
| **휠** / 두 손가락 | 선택 중: 더 크거나 작은 요소, 도구 사용 중: 굵기, 고정 위: 확대·축소 |
| **⌥ + 휠** | 도구 사용 중: 불투명도, 고정 위: 고정의 불투명도 |
| **⌘E** (고정 위) | 고정에 다시 그리기 |

모든 단축키는 [macOS 버전 README](../macos/README.md#shortcuts)에 있습니다. 전역 단축키는 설정에서 바꿀 수 있습니다.

## 자주 묻는 질문

**"열 수 없음" 또는 "손상됨"이라고 나오는 이유는?**

Apple 공증을 받지 않았기 때문입니다. [다운로드](#다운로드)의 `xattr` 명령을 한 번 실행하면 내려받은 파일에 붙는 표시가 지워집니다.

**F1을 누르면 밝기가 바뀌는 이유는?**

F1–F12 단축키에는 손쉬운 사용 권한이 필요합니다(macOS 27에서는 "Device Control and Data Access"). 메뉴 막대 아이콘의 Permissions…에서 허용하세요.

**업데이트할 때마다 권한을 다시 줘야 하나요?**

보통은 그렇습니다. sniplite는 애드혹 서명이라 macOS가 버전마다 다른 앱으로 봅니다. sniplite가 예전 항목을 알아서 지우고 권한 화면을 열어 주니, 다시 목록으로 끌어다 놓으세요.

**캡처의 글자는 어떻게 읽나요?**

Settings › General에서 Text recognition을 켠 뒤, 도구 막대의 글자 버튼, ⌘O, 또는 F4 / ⇧F4를 쓰세요. Apple의 Vision으로 이 Mac에서 동작하며 아무것도 보내지 않습니다.

**메모리는 얼마나 쓰나요?**

대기 중에는 약 15–25 MB입니다. 캡처하는 동안에만 화면 이미지를 들고 있다가 끝나면 놓습니다.

**설정과 로그는 어디에 있나요?**

설정은 앱의 환경설정에 있습니다(`defaults read io.github.codeime.sniplite`). 단축키, 권한, 인식 시간에 대한 짧은 로그는 `~/Library/Logs/sniplite.log`에 있습니다.

**어떻게 제거하나요?**

메뉴 막대에서 종료하고 "응용 프로그램"에서 `sniplite.app`을 지우세요. 설정까지 지우려면 `defaults delete io.github.codeime.sniplite`를 실행하고, 시스템 설정의 "개인정보 보호 및 보안"에 남아 있으면 거기서도 지우세요.

**Windows 버전이 있나요?**

네, 원래 버전입니다: [MrTangLuyao/sniplite](https://github.com/MrTangLuyao/sniplite/releases/latest).

## 설정 화면

<img src="../pics/macos/settings.png" alt="Mac용 sniplite 설정">

## 직접 빌드하기

Xcode 명령줄 도구만 있으면 됩니다(`xcode-select --install`). Xcode 자체는 필요 없습니다.

```bash
cd macos
./build.sh          # build/sniplite.app 생성 (Apple 실리콘 + Intel)
./build.sh --zip    # build/sniplite_<버전>_macos.zip도 생성
./test.sh           # 단위 테스트
```

소스는 `macos/Sources`에 있으며 Swift와 AppKit으로 작성되었습니다. 서명 방법과 코드 구성은 [`macos`](../macos/README.md)를 참고하세요. `macos-v<버전>` 태그를 푸시하면 GitHub Actions가 빌드해 Releases에 게시합니다. `src`의 Windows 버전 소스는 원래 저장소의 것으로, 여기서는 빌드하지 않습니다.

## 라이선스

[MIT](../LICENSE)

## 서드파티 오픈 소스

sniplite for Mac은 macOS에 들어 있는 기능만 씁니다. 캡처는 ScreenCaptureKit, 창과 그 안의 요소 찾기는 손쉬운 사용 API, 글자 인식은 Vision을 사용합니다. 서드파티 코드나 모델은 포함되어 있지 않습니다.

드래그로 허용하는 패널은 jaywcjlove의 [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow)(MIT 라이선스) 방식을 참고해 AppKit으로 다시 작성했습니다.
