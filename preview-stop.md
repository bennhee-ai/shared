# /preview-stop — Docs Hub Preview 종료

실행 중인 dev 서버를 종료하고 운영 서버에 반영합니다.

## 실행 절차

1. 실행 중인 dev 서버를 확인하고 종료합니다:
```bash
kill $(lsof -t -i:4321) 2>/dev/null && echo "종료 완료"
```
실행 중이 아니면 "Preview가 실행 중이지 않습니다." 안내 후 종료합니다.

2. 운영 서버에 반영할지 사용자에게 확인합니다:
"운영 서버(포트 80)에 반영할까요?"

3. 확인 시 빌드 및 배포를 실행합니다:
```bash
cd /home/ubuntu/claude-docs-hub && npm run build && sudo nginx -s reload
```

4. 완료 후 안내합니다:
- 운영 서버 반영 완료: `http://[서버IP]`
