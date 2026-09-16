# 말랑 고양이 메모

아이폰·Mac용 Flutter 메모 앱. 기본 화면은 `assets/malang1.png` 원본의 RGB 색상을 보존한 `assets/malang_reference_rgb.png`를 표시하고 좌표에 맞춘 터치 영역으로 실제 메모 작성과 체크리스트를 연결합니다. 모든 화면 크기에서 선택한 메모장 하나만 표시합니다. 위쪽 선택 버튼으로 여섯 메모장을 전환합니다.

카드를 누르면 편집창이 열리며 입력 내용은 자동 저장됩니다. 체크박스는 홈 화면에서도 바로 누를 수 있습니다. 홈에는 메모 세 줄을 미리 보여주며 전체 내용은 편집창에서 확인합니다. 아이폰의 ‘꾸미기 · 백업’ 버튼 또는 큰 화면의 제목을 길게 누르면 기존 편집 화면을 엽니다. 원본 화면의 제목·색·그림은 고정이며 꾸미기는 기존 편집 화면에 적용됩니다.

- 아이폰 너비에서는 선택한 메모장 하나만 표시합니다. 위쪽 선택 버튼으로 전환합니다.
- iOS의 `UIApplicationSupportsMultipleScenes`는 `false`로 설정되어 앱 창을 하나만 사용합니다.
- 기본 홈은 원본 PNG를 그대로 표시합니다. 메모를 누르면 열리는 편집창과 꾸미기 화면의 메모장에 불투명도 68%와 배경 흐림 효과를 적용합니다.
- 입력은 즉시 메모리에서 반영하고 로컬 파일에 자동 저장합니다.
- 체크리스트, 카드 꾸미기, 배경 선택, 백업 내보내기를 지원합니다.

## 실행

```sh
flutter pub get
flutter run -d <아이폰 또는 시뮬레이터 ID>
```

실제 아이폰 설치에는 Xcode에서 `ios/Runner.xcworkspace`를 열고 Signing & Capabilities에 개발 팀을 설정해야 합니다.

## 검증

```sh
flutter analyze
flutter test
flutter build ios --simulator --debug
```

화면을 변경한 뒤 기준 이미지를 갱신하려면 `flutter test --update-goldens`를 실행합니다.

## 원본 이미지 사용

`assets/malang1.png`를 수정하지 않고 사용합니다. 생성형 이미지 편집 시안은 최종 앱에 포함하지 않습니다. 꾸미기 화면도 `lib/widgets/original_artwork.dart`에서 원본 그림과 손글씨 영역을 표시합니다.

고양이와 제목 구름은 `assets/cutouts/*.png`로 보여줍니다. `tool/cutout_artwork.py`가 원본에서 외곽선 바깥만 투명하게 오려 둔 것으로, 색은 원본 픽셀 그대로고 알파만 깎여 있습니다. 카드 색 위에 올려도 테두리 바깥에 원본 메모지 배경이 남지 않습니다. 좌표나 원본을 손보면 `python3 tool/cutout_artwork.py --check`로 다시 만들고 `build/cutout_check`에서 잘린 모양을 확인합니다 (ImageMagick 필요). 원본 홈은 1536×1024 테스트에서 실제 원본 이미지와 직접 비교합니다. 아이폰은 화면 비율 때문에 한 카드씩 표시하며, 편집 내용과 선택 버튼은 별도 UI입니다.
