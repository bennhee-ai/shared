#!/bin/bash
# ============================================================
# Docs Hub 범용 설치 스크립트
# 용도: 누구든 자신의 프로젝트 문서를 시각적으로 볼 수 있는
#       웹 문서 허브를 EC2에 구성합니다.
# 사용법: bash setup-generic.sh
# ============================================================
set -e

# ── 색상 ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[OK]${RESET}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
step()    { echo -e "\n${BOLD}$1${RESET}"; }

# ── 배너 ────────────────────────────────────────────────────
echo -e "${BOLD}"
echo "╔══════════════════════════════════════╗"
echo "║       Docs Hub 설치 마법사           ║"
echo "╚══════════════════════════════════════╝"
echo -e "${RESET}"

# ============================================================
# STEP 1. 기본 정보 입력
# ============================================================
step "[1/7] 기본 정보 입력"

read -p "  허브 이름 (예: 팀명 × Sophie): " HUB_TITLE
HUB_TITLE="${HUB_TITLE:-My Docs Hub}"

read -p "  GitHub repo URL (예: https://github.com/yourname/docs-hub.git): " REPO_URL
if [ -z "$REPO_URL" ]; then
  echo -e "${RED}오류: GitHub repo URL은 필수입니다.${RESET}"
  exit 1
fi

read -p "  설치 경로 (기본값: /home/ubuntu/docs-hub): " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR:-/home/ubuntu/docs-hub}"

# ============================================================
# STEP 2. 수집할 프로젝트 폴더 설정
# ============================================================
step "[2/7] 문서 수집 설정"
echo "  수집할 프로젝트 폴더를 입력하세요."
echo "  형식: 폴더경로 사이드바라벨 (스페이스로 구분)"
echo "  예시: /home/ubuntu/my-project '내 프로젝트'"
echo "  입력 완료 후 빈 줄에서 Enter"
echo ""

declare -a SOURCES=()
declare -a LABELS=()

while true; do
  read -p "  폴더 경로 (완료하려면 Enter): " SRC_PATH
  [ -z "$SRC_PATH" ] && break
  read -p "  사이드바 라벨: " SRC_LABEL
  SRC_LABEL="${SRC_LABEL:-$(basename $SRC_PATH)}"
  SOURCES+=("$SRC_PATH")
  LABELS+=("$SRC_LABEL")
  success "추가됨: $SRC_PATH → '$SRC_LABEL'"
done

if [ ${#SOURCES[@]} -eq 0 ]; then
  warn "수집할 폴더가 없습니다. 나중에 스크립트/collect-docs.mjs를 직접 수정하세요."
fi

# ============================================================
# STEP 3. 시스템 패키지 설치
# ============================================================
step "[3/7] 시스템 패키지 설치 (nginx, node.js)"

sudo apt-get update -qq
sudo apt-get install -y nginx apache2-utils curl

if ! command -v node &> /dev/null; then
  info "Node.js 설치 중..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
success "패키지 준비 완료 (node $(node -v), nginx)"

# ============================================================
# STEP 4. 프로젝트 클론 + 의존성 설치
# ============================================================
step "[4/7] 프로젝트 클론"

if [ -d "$INSTALL_DIR" ]; then
  warn "이미 존재합니다. git pull로 업데이트합니다."
  git -C "$INSTALL_DIR" pull
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi
success "클론 완료: $INSTALL_DIR"

cd "$INSTALL_DIR"
npm install
success "npm 의존성 설치 완료"

# ============================================================
# STEP 5. collect-docs.mjs 자동 생성
# ============================================================
step "[5/7] 문서 수집 스크립트 생성"

COLLECT_FILE="$INSTALL_DIR/scripts/collect-docs.mjs"
mkdir -p "$INSTALL_DIR/scripts"

cat > "$COLLECT_FILE" << 'COLLECT_EOF'
import { cp, mkdir, readFile, writeFile, readdir, stat } from 'fs/promises';
import { join, dirname, basename } from 'path';
import { fileURLToPath } from 'url';

const projectRoot = dirname(fileURLToPath(import.meta.url));
const docsBase = join(projectRoot, '..', 'src', 'content', 'docs');

async function ensureTitle(filePath) {
  const content = await readFile(filePath, 'utf-8');
  const filename = basename(filePath, '.md');
  if (content.startsWith('---')) {
    const end = content.indexOf('---', 3);
    if (end === -1) return;
    if (content.slice(3, end).includes('title:')) return;
    const nameMatch = content.slice(3, end).match(/^name:\s*(.+)$/m);
    const title = nameMatch ? nameMatch[1].trim() : filename;
    await writeFile(filePath, `---\ntitle: "${title}"\n${content.slice(3)}`, 'utf-8');
  } else {
    const h1Match = content.match(/^#\s+(.+)$/m);
    const title = h1Match ? h1Match[1].trim().replace(/"/g, "'") : filename;
    await writeFile(filePath, `---\ntitle: "${title}"\n---\n\n${content}`, 'utf-8');
  }
}

async function ensureTitlesInDir(dir) {
  let entries;
  try { entries = await readdir(dir, { withFileTypes: true }); } catch { return; }
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) await ensureTitlesInDir(full);
    else if (entry.name.endsWith('.md')) await ensureTitle(full);
  }
}

COLLECT_EOF

# 사용자가 입력한 소스 목록을 스크립트에 추가
echo "" >> "$COLLECT_FILE"
echo "const sources = [" >> "$COLLECT_FILE"

for i in "${!SOURCES[@]}"; do
  DIR_NAME=$(basename "${SOURCES[$i]}")
  cat >> "$COLLECT_FILE" << EOF
  { src: '${SOURCES[$i]}', dest: join(docsBase, '$DIR_NAME'), label: '${LABELS[$i]}' },
EOF
done

cat >> "$COLLECT_FILE" << 'COLLECT_EOF2'
];

let ok = 0, skip = 0;
for (const { src, dest, label } of sources) {
  try {
    await stat(src);
    await mkdir(dirname(dest), { recursive: true });
    await cp(src, dest, { recursive: true, force: true });
    console.log(`✓ ${label}`);
    ok++;
  } catch (e) {
    console.warn(`⚠ ${label} 스킵 (${e.message})`);
    skip++;
  }
}
await ensureTitlesInDir(docsBase);
console.log(`\n문서 수집 완료 — 성공: ${ok}, 스킵: ${skip}`);
COLLECT_EOF2

success "collect-docs.mjs 생성 완료"

# ============================================================
# STEP 6. astro.config.mjs 자동 생성
# ============================================================
step "[6/7] Astro 사이드바 설정 생성"

ASTRO_CONFIG="$INSTALL_DIR/astro.config.mjs"

# 사이드바 항목 생성
SIDEBAR_ITEMS=""
for i in "${!SOURCES[@]}"; do
  DIR_NAME=$(basename "${SOURCES[$i]}")
  SIDEBAR_ITEMS="${SIDEBAR_ITEMS}
        {
          label: '${LABELS[$i]}',
          autogenerate: { directory: '${DIR_NAME}' },
        },"
done

cat > "$ASTRO_CONFIG" << ASTRO_EOF
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  integrations: [
    starlight({
      title: '${HUB_TITLE}',
      description: '작업 문서 허브',
      defaultLocale: 'root',
      locales: {
        root: { label: '한국어', lang: 'ko' },
      },
      sidebar: [${SIDEBAR_ITEMS}
      ],
    }),
  ],
});
ASTRO_EOF

success "astro.config.mjs 생성 완료"

# ============================================================
# STEP 7. 빌드 + nginx + Basic Auth
# ============================================================
step "[7/7] 빌드 및 배포"

npm run collect
npm run build
success "Astro 빌드 완료"

# nginx 설정
NGINX_CONF="/etc/nginx/sites-available/docs-hub"
DIST_PATH="$INSTALL_DIR/dist"

sudo tee "$NGINX_CONF" > /dev/null << NGINX_EOF
server {
    listen 80;
    server_name _;

    auth_basic "Docs Hub";
    auth_basic_user_file /etc/nginx/.htpasswd;

    root $DIST_PATH;
    index index.html;

    location / {
        try_files \$uri \$uri/ \$uri.html =404;
    }
}
NGINX_EOF

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/docs-hub
sudo rm -f /etc/nginx/sites-enabled/default

# Basic Auth 설정
echo ""
echo -e "  ${YELLOW}접속 비밀번호를 설정합니다.${RESET}"
read -p "  사용자명: " AUTH_USER
sudo htpasswd -c /etc/nginx/.htpasswd "$AUTH_USER"

sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# ── 완료 ────────────────────────────────────────────────────
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")

echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║           설치 완료!                 ║"
echo "╚══════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  접속 주소: ${CYAN}http://${PUBLIC_IP}${RESET}"
echo -e "  설치 경로: ${INSTALL_DIR}"
echo ""
echo "  문서 업데이트 시:"
echo -e "  ${YELLOW}cd ${INSTALL_DIR} && npm run collect && npm run build && sudo nginx -s reload${RESET}"
echo ""
