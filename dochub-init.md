# /dochub-init — 문서 허브 초기 구성

프로젝트 문서를 웹에서 시각적으로 볼 수 있는 Docs Hub를 현재 EC2에 구성합니다.  
Astro + Starlight 기반으로 마크다운 파일을 자동 수집하여 정적 사이트로 빌드합니다.

---

## 실행 흐름

아래 순서로 사용자에게 질문하고 직접 구성합니다.

### 1단계: 기본 정보 수집

사용자에게 다음을 질문합니다:
- 허브 이름 (예: "팀명 × Claude", 브라우저 타이틀로 사용됨)
- GitHub repo URL (docs-hub를 저장할 곳)
- 설치 경로 (기본값: `/home/ubuntu/docs-hub`)

### 2단계: 문서 수집 대상 확인

사용자에게 질문합니다:
- 수집할 프로젝트 폴더 경로 목록 (여러 개 가능)
- 각 폴더의 사이드바 라벨

실제로 해당 경로가 존재하는지 확인합니다:
```bash
ls [입력된 경로]
```

### 3단계: 시스템 패키지 설치

```bash
sudo apt-get update -qq
sudo apt-get install -y nginx apache2-utils curl
```

Node.js가 없으면 설치합니다:
```bash
node --version 2>/dev/null || (curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs)
```

### 4단계: GitHub repo 클론 및 의존성 설치

```bash
git clone [REPO_URL] [INSTALL_DIR]
cd [INSTALL_DIR]
npm install
```

이미 존재하면 `git pull`로 업데이트합니다.

### 5단계: collect-docs.mjs 생성

`scripts/collect-docs.mjs`를 사용자 입력 기반으로 작성합니다.

파일 구조:
```js
import { cp, mkdir, readFile, writeFile, readdir, stat } from 'fs/promises';
import { join, dirname, basename } from 'path';
import { fileURLToPath } from 'url';

const projectRoot = dirname(fileURLToPath(import.meta.url));
const docsBase = join(projectRoot, '..', 'src', 'content', 'docs');

// ensureTitle 함수 (frontmatter title 보장)
async function ensureTitle(filePath) { ... }
async function ensureTitlesInDir(dir) { ... }

const sources = [
  // 사용자가 입력한 폴더마다 항목 추가
  { src: '[경로]', dest: join(docsBase, '[폴더명]'), label: '[라벨]' },
];

// 수집 실행 코드
```

### 6단계: astro.config.mjs 생성

`astro.config.mjs`를 사용자 입력 기반으로 작성합니다.

사이드바에 각 프로젝트 폴더를 `autogenerate`로 등록하고, **기본 접힘** 설정을 적용합니다:
```js
sidebar: [
  {
    label: '[라벨]',
    collapsed: true,
    autogenerate: { directory: '[폴더명]', collapsed: true },
  },
  // 입력한 폴더마다 항목 추가
]
```

### 7단계: 빌드

```bash
cd [INSTALL_DIR]
npm run collect
npm run build
```

오류가 발생하면 원인을 분석하고 수정 후 재실행합니다.

### 8단계: nginx 설정 + Basic Auth

`/etc/nginx/sites-available/docs-hub`를 작성합니다:
```nginx
server {
    listen 80;
    server_name _;
    auth_basic "Docs Hub";
    auth_basic_user_file /etc/nginx/.htpasswd;
    root [INSTALL_DIR]/dist;
    index index.html;
    location / {
        try_files $uri $uri/ $uri.html =404;
    }
}
```

사용자에게 Basic Auth 사용자명을 물어본 뒤 설정합니다:
```bash
sudo htpasswd -c /etc/nginx/.htpasswd [사용자명]
sudo ln -sf /etc/nginx/sites-available/docs-hub /etc/nginx/sites-enabled/docs-hub
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
```

### 9단계: Claude Code 스킬 파일 생성 및 등록

`[INSTALL_DIR]/.claude/commands/` 폴더를 만들고 아래 3개 스킬 파일을 작성합니다.

**dochub-init.md** — 이 파일 자체 (이미 존재)

**preview-start.md**
```markdown
# /preview-start — Docs Hub Preview 실행

문서 수정 내용을 빌드 없이 브라우저에서 즉시 확인할 수 있는 dev 서버를 실행합니다.

## 실행 절차

1. 이미 실행 중인지 확인합니다:
lsof -ti:4321
이미 실행 중이면 "이미 Preview가 실행 중입니다." 안내 후 종료합니다.

2. 문서를 수집하고 dev 서버를 실행합니다:
cd [INSTALL_DIR] && npm run collect && npx astro dev --host

3. 서버가 뜨면 안내합니다:
- 접속 주소: http://[서버IP]:4321
- 종료 방법: /preview-stop 입력
- 파일 수정 시 브라우저 자동 새로고침
```

**preview-stop.md**
```markdown
# /preview-stop — Docs Hub Preview 종료

실행 중인 dev 서버를 종료하고 운영 서버에 반영합니다.

## 실행 절차

1. dev 서버를 종료합니다:
kill $(lsof -t -i:4321) 2>/dev/null && echo "종료 완료"
실행 중이 아니면 "Preview가 실행 중이지 않습니다." 안내 후 종료합니다.

2. 운영 서버에 반영할지 확인합니다.

3. 확인 시 빌드 및 배포합니다:
cd [INSTALL_DIR] && npm run build && sudo nginx -s reload
```

파일 생성 후 글로벌 경로에 복사합니다:
```bash
mkdir -p ~/.claude/commands
cp [INSTALL_DIR]/.claude/commands/*.md ~/.claude/commands/
```

복사 후 Claude Code를 재시작하면 `/dochub-init`, `/preview-start`, `/preview-stop` 스킬이 목록에 표시됩니다.

### 10단계: 완료 보고

다음 정보를 사용자에게 알립니다:
- 접속 URL: `http://$(curl -s ifconfig.me)`
- 설치 경로
- 문서 업데이트 명령: `cd [INSTALL_DIR] && npm run collect && npm run build && sudo nginx -s reload`
- 동료 공유용 가이드 파일 위치: `setup/DOCHUB-GUIDE.md`
- Preview(dev 서버) 사용법 안내
- 등록된 스킬: `/dochub-init`, `/preview-start`, `/preview-stop`

---

## Preview (dev 서버) 사용법

문서 변경 내용을 빌드 없이 즉석에서 확인할 수 있는 개발 모드입니다.

### 사전 준비 (최초 1회)
EC2 보안 그룹에서 포트 4321 인바운드 허용:
```
AWS 콘솔 → EC2 → 보안 그룹 → 인바운드 규칙 추가 → 포트 4321
```

### 실행
```bash
cd [INSTALL_DIR]
npm run collect && npx astro dev --host
```

### 접속
```
http://[서버IP]:4321
```
파일을 수정하면 브라우저가 자동으로 새로고침됩니다.

### 종료 후 운영 배포
```bash
# Ctrl+C 로 dev 서버 종료 후
npm run build && sudo nginx -s reload
```

> dev 서버는 작업 중 확인용입니다. 작업이 끝나면 반드시 빌드·배포를 실행하세요.

---

## 주의사항

- 각 단계 실행 전 사용자에게 확인을 받고 진행합니다
- nginx 설정 변경 전 기존 설정을 백업합니다: `sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak 2>/dev/null || true`
- 빌드 실패 시 `npm run collect` 출력을 확인하여 수집 오류를 먼저 해결합니다
- EC2 보안 그룹에서 포트 80 인바운드가 열려 있어야 외부 접속 가능합니다
