# Docs Hub Starter

프로젝트 문서를 웹에서 시각적으로 볼 수 있는 문서 허브를 구성하는 도구 모음입니다.

## 파일 구성

| 파일 | 대상 | 설명 |
|------|------|------|
| `setup-generic.sh` | ChatGPT 사용자 | EC2에 문서 허브를 자동 설치하는 bash 스크립트 |
| `dochub-init.md` | Claude Code 사용자 | `/dochub-init` 슬래시 커맨드 스킬 |
| `DOCHUB-GUIDE.md` | 전체 | 사전 준비부터 운영까지 상세 가이드 |

---

## ChatGPT 사용자

```bash
curl -fsSL https://raw.githubusercontent.com/bennhee4sds-sudo/shared/main/setup-generic.sh -o setup.sh
bash setup.sh
```

자세한 흐름은 `DOCHUB-GUIDE.md` 참고.

---

## Claude Code 사용자

```bash
mkdir -p ~/.claude/commands
curl -fsSL https://raw.githubusercontent.com/bennhee4sds-sudo/shared/main/dochub-init.md \
  -o ~/.claude/commands/dochub-init.md
```

설치 후 Claude Code에서 `/dochub-init` 입력.
