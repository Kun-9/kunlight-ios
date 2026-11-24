# 개인 빌드 변경 목록

PC판(`~/codes/moonlight-qt`)과 같은 디자인을 아이폰·아이패드에 옮긴 개인 빌드. 스토어에 올리지 않는다.

- 새 파일: `Limelight/MoonHome.h/.m` (PC 칩, 가운데 표지 캐러셀, 흐린 배경, 꾹 눌러 끌어 순서 바꾸기), `Limelight/Font/Pretendard/*`
- 원본 수정: `MainFrameViewController.m`(연결 몇 줄, `_moon` 이 있을 때만 동작), `project.pbxproj`(파일 추가), `Limelight-Info.plist`(UIAppFonts)
- 실행 중인 게임이 있으면 고른 게임 대신 그 게임으로 이어 하기
- 설정 화면 어두운 테마·한국어(`styleSettingsView`, 통계 모양 줄 추가), 접속 중 화면(`streamStartViewWithFrame`), 통계 카드·한 줄 띠(`MoonStats`, `statsStyle`), 알림 창 한국어(`presentViewController` 바꿔치기)
- 순서 저장: NSUserDefaults `pcOrder`, `appOrder.<PC uuid>`

맥과 맞추기: `tools/kunseed.py` 가 맥 KUNLIGHT 의 PC 목록·서버 인증서·내 인증서와 키·순서를 `~/.kunlight/ios-seed/kunseed.json` 으로 뽑고(저장소 밖, 개인 키 포함), 빌드 단계 "Bundle KUNLIGHT seed" 가 앱에 넣는다. 앱은 켤 때 `MoonSeed` 로 들여온다(묶음이 바뀐 판일 때만). 맥에서 바뀐 것은 다음 설치 때 들어간다.

한 번에: `tools/build-iphone.sh` (팀 id·번들 id·기기 id 는 `tools/local.env` 에 `KUNLIGHT_TEAM`·`KUNLIGHT_BUNDLE_ID`·`KUNLIGHT_DEVICE` 로, 저장소에 넣지 않음)

빌드·설치(무료 계정, 7일마다 다시 서명):

    xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build DEVELOPMENT_TEAM=<팀 id> PRODUCT_BUNDLE_IDENTIFIER=<번들 id> CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build
    xcrun devicectl device install app --device <기기 id> build/Build/Products/Release-iphoneos/Moonlight.app

원본 업데이트: `git fetch origin && git merge origin/master && git submodule update --init --recursive`
