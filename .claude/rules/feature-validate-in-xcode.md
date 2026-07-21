# Feature Validate in Xcode

기능을 구현할 때 테스트 작성 → 빌드 검증 → 테스트 실행까지 빠짐없이 거치기 위한 규칙이다. Xcode/Swift 프로젝트에서 기능을 구현하는 모든 작업에 적용한다.

## 기능 구현 이전

### Test Code 작성하기

- **Swift Testing**(`import Testing`)으로 기능 구현 전에 테스트 코드부터 작성한다.
- 정상 케이스뿐 아니라 **엣지 케이스**를 반드시 포함한다. (빈 입력, 경계값, 동시성, 백그라운드 전이 등)
- `@Test`, `#expect`, `#require`를 사용하고, 유사한 케이스가 여러 개면 `@Test(arguments:)`로 파라미터화한다.

```swift
import Testing
@testable import <ModuleName>

@Test("빈 입력이면 생성이 실패한다")
func emptyInputFails() throws {
    let result = Generator.generate(from: [])
    #expect(result == nil)
}

@Test("경계값 처리", arguments: [minValue, maxValue, 0.0])
func boundaryValues(value: Double) throws {
    #expect(Generator.isValid(value))
}
```

## 기능 구현 이후

### 빌드하기

- 기능 구현이 끝나면 **반드시 빌드가 성공**해야 작업이 끝난 것으로 간주한다.
- 커맨드라인에서 직접 빌드하고 결과를 확인한다. scheme 이름을 모르면 먼저 확인한다.

```bash
xcodebuild -list

xcodebuild build \
  -scheme <SchemeName> \
  -destination 'generic/platform=iOS Simulator'
```

#### 에러 처리 기준

| 구분 | 예시 | 처리 |
|---|---|---|
| 간단한 에러 | 타입 불일치, import 누락, 오타, 프로토콜 미준수 stub 누락 | **자동으로 수정 시도 후 재빌드**. 반복해도 안 풀리면 복잡한 에러로 전환 |
| 복잡한 에러 (Xcode 설정) | 서명/Team ID 불일치, Provisioning Profile, Target Membership, Info.plist 권한 키 누락(예: `NSLocationWhenInUseUsageDescription`), SPM 의존성 해결 실패 | **코드를 고치지 않고 즉시 중단**, 원인과 해야 할 행동을 구체적으로 안내 |

- 복잡한 에러는 "에러 발생"으로 끝내지 않고, **Xcode의 어느 탭에서 무엇을 바꿔야 하는지**까지 명시한다.
  - 예: "Signing & Capabilities 탭에서 Team을 조직 계정으로 변경해주세요. 현재 프로젝트 Team ID(`7KL6...`)와 기기에 설치된 앱의 Team ID(`2QJX...`)가 다릅니다."

### Test Code 실행하기

- **Unit/Logic 테스트**는 커맨드라인에서 실행한다.

```bash
xcodebuild test \
  -scheme <SchemeName> \
  -destination 'generic/platform=iOS Simulator'
```

- **UI 테스트**는 반드시 **시뮬레이터**를 통해 검증받는다.
  - 특정 기기명을 하드코딩하지 않고, **프로젝트 scheme에 설정된 기본 설정을 그대로 사용**한다.
  - 실행 가능한 destination을 먼저 확인한 뒤, 확인된 값으로 실행한다.

    ```bash
    xcodebuild -showdestinations -scheme <SchemeName>

    xcodebuild test \
      -scheme <SchemeName> \
      -destination 'platform=iOS Simulator,id=<확인된 UDID>'
    ```

  - watchOS 등 다중 타겟이 얽힌 프로젝트라면 iOS + watchOS 시뮬레이터가 페어링된 상태인지 함께 확인한다.

---

## 체크리스트

- [ ] 구현 전: Swift Testing으로 엣지 케이스 포함 테스트 작성
- [ ] 구현 후: `xcodebuild build` 성공 확인
- [ ] 빌드 에러: 간단하면 자동 수정 → 재빌드 / 복잡하면 중단 후 구체적 행동 안내
- [ ] Unit 테스트 + UI 테스트(시뮬레이터, scheme 기본값) 통과 확인