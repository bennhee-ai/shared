# /preview-start — Docs Hub Preview 실행

문서 수정 내용을 빌드 없이 브라우저에서 즉시 확인할 수 있는 dev 서버를 실행합니다.

## 실행 절차

1. 이미 실행 중인지 확인합니다:
```bash
lsof -ti:4321
```
이미 실행 중이면 "이미 Preview가 실행 중입니다. http://[서버IP]:4321 로 접속하세요." 안내 후 종료합니다.

2. 문서를 수집하고 dev 서버를 백그라운드로 실행합니다:
```bash
cd /home/ubuntu/claude-docs-hub && npm run collect && npx astro dev --host
```

3. 서버가 뜨면 아래 정보를 사용자에게 알립니다:
- 접속 주소: `http://[서버IP]:4321`
- 종료 방법: `/preview-stop` 입력
- 파일 수정 시 브라우저가 자동으로 새로고침됨
