# Keycloak 설정 가이드 (Korean)

## 개요

이 가이드는 AKS에 배포된 Keycloak을 구성하고 Azure API Management와 통합하는 방법을 설명합니다.

## 1. Keycloak 접속

배포 후 Keycloak 관리 콘솔에 접속합니다:

```bash
# Keycloak 외부 IP 확인
kubectl get svc keycloak -n keycloak

# 또는 스크립트 사용
./scripts/get-keycloak-urls.sh
```

브라우저에서 `http://<EXTERNAL-IP>:8080` 접속
- 사용자명: `admin`
- 비밀번호: `admin`

## 2. Realm 생성

1. 왼쪽 상단 "Master" 드롭다운 클릭
2. "Create Realm" 선택
3. Realm name: `apim` 입력
4. "Create" 클릭

## 3. Client 생성 (APIM용)

### 3.1 Client 기본 설정

1. 좌측 메뉴에서 "Clients" 선택
2. "Create client" 클릭
3. 다음 정보 입력:
   - **Client type**: OpenID Connect
   - **Client ID**: `apim-client`
   - "Next" 클릭

### 3.2 Client 인증 설정

1. **Client authentication**: ON으로 설정
2. **Authorization**: OFF
3. **Authentication flow**:
   - ✓ Standard flow
   - ✓ Direct access grants
4. "Next" 클릭

### 3.3 Redirect URIs 설정

1. **Valid redirect URIs**:
   ```
   https://oauth.pstmn.io/v1/callback
   http://localhost:*
   https://your-apim-gateway-url/*
   ```
2. "Save" 클릭

### 3.4 Client Secret 확인

1. "Clients" → `apim-client` 선택
2. "Credentials" 탭 선택
3. "Client secret" 값 복사 (나중에 사용)

## 4. 테스트 사용자 생성

### 4.1 사용자 추가

1. 좌측 메뉴에서 "Users" 선택
2. "Add user" 클릭
3. 다음 정보 입력:
   - **Username**: `testuser`
   - **Email**: `testuser@example.com`
   - **First name**: `Test`
   - **Last name**: `User`
   - **Email verified**: ON
4. "Create" 클릭

### 4.2 비밀번호 설정

1. 생성된 사용자 선택
2. "Credentials" 탭 선택
3. "Set password" 클릭
4. 다음 정보 입력:
   - **Password**: `Test123!`
   - **Password confirmation**: `Test123!`
   - **Temporary**: OFF (중요!)
5. "Save" 클릭

## 5. Realm Role 설정 (선택사항)

### 5.1 Role 생성

1. 좌측 메뉴에서 "Realm roles" 선택
2. "Create role" 클릭
3. **Role name**: `api-user` 입력
4. "Save" 클릭

### 5.2 사용자에게 Role 할당

1. "Users" → `testuser` 선택
2. "Role mapping" 탭 선택
3. "Assign role" 클릭
4. `api-user` 선택 후 "Assign" 클릭

## 6. Client Scope 설정 (선택사항)

### 6.1 Audience Mapper 추가

1. "Clients" → `apim-client` → "Client scopes" 탭
2. `apim-client-dedicated` 선택
3. "Add mapper" → "By configuration" → "Audience"
4. 다음 정보 입력:
   - **Name**: `audience-mapper`
   - **Included Client Audience**: `apim-client`
   - **Add to access token**: ON
5. "Save" 클릭

## 7. 토큰 수명 설정 (선택사항)

1. Realm 설정에서 "Realm settings" 선택
2. "Tokens" 탭 선택
3. 다음 값 조정:
   - **Access Token Lifespan**: 5분 (기본값) 또는 원하는 값
   - **Refresh Token Max Reuse**: 0 (보안을 위해)
   - **Access Token Lifespan For Implicit Flow**: 15분

## 8. 테스트: 토큰 발급

### cURL 사용

```bash
# 환경 변수 설정
export KEYCLOAK_URL="http://<KEYCLOAK-IP>:8080"
export CLIENT_SECRET="<your-client-secret>"

# 토큰 발급
curl -X POST "${KEYCLOAK_URL}/realms/apim/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=apim-client" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "grant_type=password" \
  -d "username=testuser" \
  -d "password=Test123!" \
  | jq '.'
```

### Postman 사용

1. 새 Request 생성
2. Authorization 탭:
   - Type: OAuth 2.0
   - Grant Type: Password Credentials
   - Access Token URL: `http://<KEYCLOAK-IP>:8080/realms/apim/protocol/openid-connect/token`
   - Client ID: `apim-client`
   - Client Secret: `<your-client-secret>`
   - Username: `testuser`
   - Password: `Test123!`
3. "Get New Access Token" 클릭

## 9. 토큰 검증

발급받은 토큰을 [jwt.io](https://jwt.io)에서 디코딩하여 확인:

```json
{
  "exp": 1234567890,
  "iat": 1234567890,
  "iss": "http://<KEYCLOAK-IP>:8080/realms/apim",
  "aud": "apim-client",
  "sub": "user-id",
  "typ": "Bearer",
  "azp": "apim-client",
  "realm_access": {
    "roles": ["api-user"]
  }
}
```

중요한 필드:
- **iss** (issuer): Keycloak realm URL
- **aud** (audience): Client ID
- **sub** (subject): 사용자 ID
- **realm_access**: 사용자 role

## 10. APIM 연동 확인사항

APIM 정책에서 다음 값들이 일치하는지 확인:

1. **Issuer URL**: `http://<KEYCLOAK-IP>:8080/realms/apim`
2. **Audience**: `apim-client`
3. **JWKS URL**: `http://<KEYCLOAK-IP>:8080/realms/apim/protocol/openid-connect/certs`

## 문제 해결

### 토큰 발급 실패

**증상**: "Invalid user credentials" 오류

**해결방법**:
1. 사용자명과 비밀번호 확인
2. Keycloak에서 사용자가 활성화되어 있는지 확인
3. "Temporary password"가 OFF인지 확인

### APIM에서 토큰 검증 실패

**증상**: 401 Unauthorized

**해결방법**:
1. APIM의 Keycloak issuer URL이 정확한지 확인
2. Audience가 `apim-client`로 설정되어 있는지 확인
3. APIM에서 Keycloak JWKS URL에 접근 가능한지 확인
4. 토큰이 만료되지 않았는지 확인

### Keycloak에 접속 불가

**증상**: Keycloak URL 접속 시 타임아웃

**해결방법**:
```bash
# Pod 상태 확인
kubectl get pods -n keycloak

# Service 상태 확인
kubectl get svc keycloak -n keycloak

# Logs 확인
kubectl logs -f deployment/keycloak -n keycloak
```

## 보안 권장사항

1. **프로덕션 환경에서는 반드시 HTTPS 사용**
2. **관리자 비밀번호 변경** (`admin` 사용 금지)
3. **데이터베이스 비밀번호 변경**
4. **토큰 수명을 적절히 설정** (너무 길면 보안 위험)
5. **Realm export 백업 정기적으로 수행**
6. **Session 모니터링 활성화**

## 다음 단계

1. SETUP.md의 "Part 4: Configure Azure API Management" 진행
2. 통합 테스트 수행
3. 프로덕션 환경을 위한 TLS 인증서 설정

## 참고 자료

- [Keycloak 공식 문서](https://www.keycloak.org/documentation)
- [OpenID Connect 스펙](https://openid.net/connect/)
- [JWT 토큰 구조](https://jwt.io/introduction)
