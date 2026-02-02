# AI Foundry + OIDC (Keycloak) Integration via Azure API Management

이 저장소는 Keycloak과 같은 OIDC 제공자를 사용하여 AI Foundry에 대한 인증을 통합하고, Azure API Management(APIM)를 통해 사용자별 로그인 이력 및 프롬프트 사용량을 모니터링하는 방법을 보여주는 예제입니다.

## 🎯 목적

- OIDC (OpenID Connect) 기반 인증을 AI Foundry API와 통합
- 사용자별 로그인 이력 추적
- AI 프롬프트 사용량 모니터링 및 감사
- APIM을 통한 중앙 집중식 API 관리

## 📁 프로젝트 구조

```
.
├── keycloak/                    # Keycloak 설정
│   ├── docker-compose.yml       # Keycloak 로컬 실행 구성
│   └── realm-export.json        # AI Foundry realm 설정
├── apim-policies/               # APIM 정책 파일
│   ├── validate-oidc-token.xml  # OIDC 토큰 검증 정책
│   ├── log-ai-prompts.xml       # AI 프롬프트 로깅 정책
│   └── combined-policy.xml      # 통합 정책
├── sample-app/                  # 샘플 애플리케이션
│   ├── main.py                  # Python 클라이언트 예제
│   ├── requirements.txt         # Python 의존성
│   └── .env.example             # 환경 변수 템플릿
└── docs/                        # 문서
    └── architecture.md          # 아키텍처 문서
```

## 🚀 빠른 시작

### 1. Keycloak 실행

```bash
cd keycloak
docker-compose up -d
```

Keycloak 관리 콘솔: http://localhost:8080
- 관리자 계정: admin / admin

### 2. 샘플 애플리케이션 실행

```bash
cd sample-app
pip install -r requirements.txt
cp .env.example .env
# .env 파일을 환경에 맞게 수정
python main.py
```

## 🔧 구성 요소

### Keycloak (OIDC Provider)

- **Realm**: `ai-foundry`
- **Client**: `ai-foundry-client`
- **사용자 역할**: `ai-user`, `ai-admin`
- **기본 테스트 사용자**: `testuser` / `testpassword`

### Azure API Management 정책

1. **validate-oidc-token.xml**: JWT 토큰 검증 및 사용자 정보 추출
2. **log-ai-prompts.xml**: AI 프롬프트 요청/응답 로깅
3. **combined-policy.xml**: 인증 + 로깅 통합 정책

### 모니터링 데이터

APIM 정책을 통해 다음 정보가 기록됩니다:

#### 사용자 인증 이벤트
- 사용자 ID 및 이메일
- 인증 시간
- API 경로 및 메서드

#### 프롬프트 사용량
- 사용자별 프롬프트 내용 (일부)
- 토큰 사용량 (입력/출력)
- 응답 시간
- 사용된 모델

## 📋 APIM 설정 가이드

### 1. Named Values 설정

APIM에서 다음 Named Values를 설정하세요:

| 이름 | 값 예시 |
|------|---------|
| `keycloak-openid-config-url` | `https://your-keycloak/realms/ai-foundry/.well-known/openid-configuration` |
| `keycloak-issuer-url` | `https://your-keycloak/realms/ai-foundry` |

### 2. Event Hub Logger 설정

AI 프롬프트 로깅을 위해 Event Hub Logger를 설정하세요:

1. Azure Event Hub 생성
2. APIM에서 Logger 생성 (`ai-foundry-logger`)
3. Event Hub 연결 문자열 구성

### 3. Application Insights 연동

상세한 모니터링을 위해 Application Insights를 연동하세요.

## 🔐 보안 고려사항

1. **비밀 관리**: 클라이언트 시크릿은 Azure Key Vault에 저장
2. **토큰 검증**: 발급자, 대상, 만료 시간 검증
3. **프롬프트 로깅**: 민감한 데이터 마스킹 고려
4. **접근 제어**: 역할 기반 접근 제어(RBAC) 적용

## 📊 모니터링 대시보드

Event Hub 또는 Application Insights 데이터를 기반으로:

- Azure Monitor Workbook
- Power BI 대시보드
- 사용자 정의 분석 도구

를 통해 다음을 시각화할 수 있습니다:

- 사용자별 API 호출 횟수
- 토큰 사용량 트렌드
- 응답 시간 분석
- 오류율 모니터링

## 🤝 기여

이슈 및 풀 리퀘스트를 환영합니다.

## 📄 라이선스

MIT License
