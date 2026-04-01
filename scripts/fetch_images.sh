#!/usr/bin/env bash
# ==============================================================================
# アイキャッチ・本文画像 自動取得スクリプト（Pexels API使用）
#
# 事前準備:
#   1. https://www.pexels.com/api/ で無料APIキーを取得（1分で完了）
#   2. export PEXELS_API_KEY="your_api_key_here"
#
# 使い方:
#   bash scripts/fetch_images.sh articles/2026-04-01_gan-charger-comparison_note.md
#   bash scripts/fetch_images.sh articles/2026-04-01_xxx.md --count 5
#   bash scripts/fetch_images.sh --keywords "GaN充電器 USB" --slug gan-charger --count 3
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="$REPO_ROOT/assets/images"

# ── カラー出力 ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }

# ── 引数パース ───────────────────────────────────────────────────────────────
ARTICLE_FILE=""
MANUAL_KEYWORDS=""
MANUAL_SLUG=""
IMAGE_COUNT=4

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keywords) MANUAL_KEYWORDS="$2"; shift 2 ;;
    --slug)     MANUAL_SLUG="$2";     shift 2 ;;
    --count)    IMAGE_COUNT="$2";     shift 2 ;;
    -*)         log_error "不明なオプション: $1"; exit 1 ;;
    *)          ARTICLE_FILE="$1";    shift ;;
  esac
done

# ── API キー確認 ──────────────────────────────────────────────────────────────
if [[ -z "${PEXELS_API_KEY:-}" ]]; then
  log_error "PEXELS_API_KEY が設定されていません。"
  echo ""
  echo "  1. https://www.pexels.com/api/ で無料APIキーを取得（1分）"
  echo "  2. 以下を実行してから再度試してください:"
  echo "     export PEXELS_API_KEY=\"your_key_here\""
  echo ""
  echo "  永続化する場合は ~/.bashrc または ~/.zshrc に追記:"
  echo "     echo 'export PEXELS_API_KEY=\"your_key_here\"' >> ~/.zshrc"
  exit 1
fi

# ── 依存コマンド確認 ────────────────────────────────────────────────────────
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    log_error "$cmd がインストールされていません。"
    echo "  インストール: brew install $cmd  または  sudo apt-get install $cmd"
    exit 1
  fi
done

# ── 記事ファイルからメタデータ抽出 ──────────────────────────────────────────
extract_from_article() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log_error "ファイルが見つかりません: $file"
    exit 1
  fi

  # フロントマター (---..---) からキーワードとカテゴリを抽出
  ARTICLE_SLUG=$(basename "$file" .md | sed 's/_note$//' | sed 's/^[0-9-]*_//')
  ARTICLE_KEYWORDS=$(awk '/^---/{n++; if(n==2) exit} n==1 && /^  - /{print $2}' "$file" \
    | head -3 | tr '\n' ' ')
  ARTICLE_CATEGORY=$(awk '/^---/{n++; if(n==2) exit} n==1 && /^category:/{gsub(/"/, ""); print $2}' "$file")
}

# ── キーワード決定 ──────────────────────────────────────────────────────────
if [[ -n "$MANUAL_KEYWORDS" ]]; then
  SEARCH_QUERY="$MANUAL_KEYWORDS"
  SLUG="${MANUAL_SLUG:-$(echo "$MANUAL_KEYWORDS" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')}"
elif [[ -n "$ARTICLE_FILE" ]]; then
  extract_from_article "$ARTICLE_FILE"
  SEARCH_QUERY="${ARTICLE_KEYWORDS:-gadget technology}"
  SLUG="${MANUAL_SLUG:-$ARTICLE_SLUG}"
else
  log_error "記事ファイルまたは --keywords を指定してください。"
  exit 1
fi

# 日本語キーワードを英語に変換（カテゴリ別マッピング）
translate_keywords() {
  local kw="$1"
  local cat="${ARTICLE_CATEGORY:-}"

  case "$cat" in
    charger-battery)   echo "USB charger GaN power adapter gadget technology" ;;
    earphone-headphone) echo "wireless earbuds headphones audio technology" ;;
    smartwatch)         echo "smartwatch fitness tracker wearable technology" ;;
    pc-accessories)     echo "keyboard mouse desk setup computer accessories" ;;
    smart-home)         echo "smart home device speaker technology interior" ;;
    camera)             echo "camera photography equipment gadget" ;;
    *)
      # 日本語→英語の簡易変換
      echo "$kw" \
        | sed 's/GaN充電器/GaN charger/g' \
        | sed 's/充電器/charger/g' \
        | sed 's/イヤホン/earbuds/g' \
        | sed 's/スマートウォッチ/smartwatch/g' \
        | sed 's/ガジェット/gadget/g' \
        | sed 's/おすすめ/recommended/g' \
        | sed 's/比較/comparison/g'
      ;;
  esac
}

ENGLISH_QUERY=$(translate_keywords "$SEARCH_QUERY")
OUTPUT_DIR="$IMAGES_DIR/$SLUG"
mkdir -p "$OUTPUT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════${NC}"
echo -e "${CYAN} 画像取得: $SLUG${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
log_info "検索クエリ: $ENGLISH_QUERY"
log_info "取得枚数: $IMAGE_COUNT"
log_info "保存先: $OUTPUT_DIR"

# ── Pexels API で画像検索 ──────────────────────────────────────────────────
log_info "Pexels APIで検索中..."

SEARCH_RESPONSE=$(curl -s \
  -H "Authorization: $PEXELS_API_KEY" \
  "https://api.pexels.com/v1/search?query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ENGLISH_QUERY'))")&per_page=$((IMAGE_COUNT + 2))&orientation=landscape&size=large")

TOTAL=$(echo "$SEARCH_RESPONSE" | jq -r '.total_results // 0')

if [[ "$TOTAL" -eq 0 ]]; then
  log_warn "「$ENGLISH_QUERY」に一致する画像が見つかりませんでした。"
  log_info "フォールバック検索: technology gadget"
  SEARCH_RESPONSE=$(curl -s \
    -H "Authorization: $PEXELS_API_KEY" \
    "https://api.pexels.com/v1/search?query=technology+gadget&per_page=$IMAGE_COUNT&orientation=landscape&size=large")
fi

# ── 画像ダウンロード ─────────────────────────────────────────────────────────
CREDITS_FILE="$OUTPUT_DIR/credits.json"
echo "[]" > "$CREDITS_FILE"

DOWNLOADED=0
IDX=0

while IFS= read -r photo_json; do
  [[ $DOWNLOADED -ge $IMAGE_COUNT ]] && break

  PHOTO_ID=$(echo "$photo_json" | jq -r '.id')
  PHOTOGRAPHER=$(echo "$photo_json" | jq -r '.photographer')
  PHOTOGRAPHER_URL=$(echo "$photo_json" | jq -r '.photographer_url')
  PEXELS_URL=$(echo "$photo_json" | jq -r '.url')
  IMG_URL=$(echo "$photo_json" | jq -r '.src.large2x // .src.large')
  ALT=$(echo "$photo_json" | jq -r '.alt // "gadget photo"')

  IDX=$((IDX + 1))
  FILENAME="${SLUG}_$(printf '%02d' $IDX)_${PHOTO_ID}.jpg"
  FILEPATH="$OUTPUT_DIR/$FILENAME"

  log_info "[$IDX/$IMAGE_COUNT] ダウンロード: $FILENAME"
  log_info "  撮影者: $PHOTOGRAPHER"

  if curl -sL -o "$FILEPATH" "$IMG_URL"; then
    FILESIZE=$(du -sh "$FILEPATH" | cut -f1)
    log_success "保存完了: $FILENAME ($FILESIZE)"
    DOWNLOADED=$((DOWNLOADED + 1))

    # credits.json に追記
    TEMP=$(mktemp)
    jq --arg file "$FILENAME" \
       --arg id "$PHOTO_ID" \
       --arg photographer "$PHOTOGRAPHER" \
       --arg photographer_url "$PHOTOGRAPHER_URL" \
       --arg pexels_url "$PEXELS_URL" \
       --arg alt "$ALT" \
       --arg usage "note_eyecatch_or_body" \
       '. += [{
         "file": $file,
         "pexels_id": $id,
         "photographer": $photographer,
         "photographer_url": $photographer_url,
         "pexels_url": $pexels_url,
         "alt": $alt,
         "usage": $usage,
         "license": "Pexels License (free for commercial use)"
       }]' "$CREDITS_FILE" > "$TEMP" && mv "$TEMP" "$CREDITS_FILE"
  else
    log_warn "ダウンロード失敗: $IMG_URL"
  fi

done < <(echo "$SEARCH_RESPONSE" | jq -c '.photos[]')

# ── 結果サマリー ────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN} 完了: $DOWNLOADED 枚の画像を取得しました${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}保存先:${NC} $OUTPUT_DIR"
echo ""

if [[ $DOWNLOADED -gt 0 ]]; then
  echo -e "${CYAN}ファイル一覧:${NC}"
  ls -lh "$OUTPUT_DIR"/*.jpg 2>/dev/null | awk '{print "  ", $NF, "("$5")"}'
  echo ""
  echo -e "${CYAN}Note投稿時の使い方:${NC}"
  echo "  1. アイキャッチ: $(ls "$OUTPUT_DIR"/*.jpg 2>/dev/null | head -1 | xargs basename) を使用"
  echo "  2. 本文中: 各画像を適切な見出しの下に挿入"
  echo "  3. クレジット: credits.json の photographer を記事末尾に記載（任意）"
  echo ""
  echo -e "${YELLOW}クレジット表記例（任意・推奨）:${NC}"
  jq -r '.[] | "  Photo by \(.photographer) via Pexels (\(.pexels_url))"' "$CREDITS_FILE"
fi

echo ""
log_info "クレジット詳細: $CREDITS_FILE"
