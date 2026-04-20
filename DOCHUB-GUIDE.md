---
title: "Docs Hub 설치 가이드"
---

# Docs Hub 설치 가이드

프로젝트 문서(마크다운 파일, CLAUDE.md, docs 폴더 등)를 웹에서 시각적으로 볼 수 있는 문서 허브를 EC2에 구성하는 가이드입니다.

---

## 전체 흐름

```
[사전 준비] EC2 생성 + GitHub repo 준비
     ↓
[설치] SSH 접속 → 스크립트 실행 → 대화형 입력
     ↓
[확인] 브라우저에서 http://서버IP 접속
     ↓
[운영] 문서 변경 시 업데이트 명령 실행
```

---

## 사전 준비

### 1. EC2 인스턴스 생성

| 항목 | 권장 사양 |
|------|---------|
| OS | Ubuntu 22.04 LTS |
| 인스턴스 타입 | t3.small 이상 |
| 스토리지 | 20GB 이상 |
| 보안 그룹 인바운드 | 22(SSH), 80(HTTP) 허용 |

> AWS 콘솔 → EC2 → 인스턴스 시작 → Ubuntu 22.04 선택 → 보안 그룹에서 포트 22, 80 인바운드 추가

### 2. GitHub repo 준비

자신만의 docs-hub GitHub repo가 필요합니다.

**옵션 A: 이 repo를 Fork**
1. [github.com/bennhee-ai/claude-docs-hub](https://github.com/bennhee-ai/claude-docs-hub) 에서 Fork 클릭
2. 본인 GitHub 계정으로 Fork 생성
3. Fork된 repo URL 복사 (예: `https://github.com/yourname/docs-hub.git`)

**옵션 B: 새로 만들기**
1. GitHub에서 새 repo 생성 (Public or Private)
2. 빈 repo URL 복사

---

## 설치

### 1. EC2 SSH 접속

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2. 설치 스크립트 다운로드 및 실행

```bash
curl -fsSL https://raw.githubusercontent.com/bennhee-ai/claude-docs-hub/main/setup/setup-generic.sh -o setup.sh
bash setup.sh
```

### 3. 대화형 입력 진행

스크립트가 실행되면 아래 항목을 순서대로 입력합니다.

---

#### ① 허브 이름

```
허브 이름 (예: 팀명 × Sophie): 내 팀 문서 허브
```

브라우저 상단에 표시되는 타이틀입니다.

---

#### ② GitHub repo URL

```
GitHub repo URL: https://github.com/yourname/docs-hub.git
```

---

#### ③ 설치 경로

```
설치 경로 (기본값: /home/ubuntu/docs-hub): [Enter로 기본값 사용]
```

---

#### ④ 수집할 문서 폴더 입력

허브에 표시할 프로젝트 폴더를 하나씩 추가합니다.

```
폴더 경로 (완료하려면 Enter): /home/ubuntu/my-project
사이드바 라벨: 내 프로젝트

폴더 경로 (완료하려면 Enter): /home/ubuntu/another-project
사이드바 라벨: 또 다른 프로젝트

폴더 경로 (완료하려면 Enter): [Enter — 입력 완료]
```

> **폴더 안의 .md 파일이 자동으로 수집됩니다.**  
> docs/, CLAUDE.md, README.md 등 마크다운이 있는 폴더라면 모두 가능합니다.

---

#### ⑤ 접속 비밀번호 설정

```
사용자명: myname
New password: ****
Re-type new password: ****
```

허브는 Basic Auth로 보호됩니다. 공유할 동료에게 이 사용자명/비밀번호를 알려주세요.

---

#### 설치 완료 화면

```
╔══════════════════════════════════════╗
║           설치 완료!                 ║
╚══════════════════════════════════════╝

  접속 주소: http://43.200.xxx.xxx
  설치 경로: /home/ubuntu/docs-hub
```

---

## 접속 확인

브라우저에서 `http://서버IP` 로 접속합니다.

- 사용자명/비밀번호 입력 → 문서 허브 화면 표시
- 왼쪽 사이드바에 입력한 프로젝트 폴더들이 메뉴로 표시됨
- 마크다운 파일이 자동으로 페이지로 변환됨

---

## 문서 업데이트

문서 내용이 변경되면 아래 명령으로 허브를 갱신합니다.

```bash
cd /home/ubuntu/docs-hub
npm run collect && npm run build && sudo nginx -s reload
```

GitHub에 변경사항을 커밋하고 싶다면:

```bash
cd /home/ubuntu/docs-hub
git add src/content/docs
git commit -m "docs: 업데이트 $(date +%Y-%m-%d)"
git push
```

---

## 자주 묻는 질문

**Q. 새 프로젝트 폴더를 추가하고 싶어요**

`scripts/collect-docs.mjs` 파일을 열어 `sources` 배열에 항목을 추가하고, `astro.config.mjs`의 `sidebar` 배열에도 같은 디렉토리명으로 항목을 추가한 뒤 업데이트 명령을 실행하세요.

**Q. 허브가 안 열려요**

```bash
sudo systemctl status nginx      # nginx 상태 확인
sudo nginx -t                    # 설정 문법 확인
sudo systemctl restart nginx     # 재시작
```

**Q. EC2를 새로 만들어야 해요**

위 설치 절차를 새 EC2에서 동일하게 반복하면 됩니다. GitHub repo에 문서가 저장되어 있으면 클론 후 자동 복원됩니다.

---

## ChatGPT와 함께 사용하기

이 가이드를 ChatGPT에 붙여넣고 막히는 부분을 질문하면 됩니다.

```
[ChatGPT에게 질문 예시]
"setup.sh 실행 중 에러가 났어. 이 메시지가 뭔 뜻이야: [에러 메시지]"
"EC2 보안 그룹에서 포트 80 여는 방법 알려줘"
"collect-docs.mjs에 새 폴더 추가하는 방법 알려줘"
```
