#!/usr/bin/env bash
# ==============================================================================
# 画像パスを Note用記事に挿入するスクリプト
#
# 使い方:
#   bash scripts/insert_images.sh articles/2026-04-01_gan-charger-comparison_note.md
#
# 動作:
#   - assets/images/{slug}/ の画像一覧を表示
#   - 記事内の挿入ポイント（見出し直後）を提案
#   - Note投稿用のコピペブロックを生成して出力
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

ARTICLE_FILE="${1:-}"

if [[ -z "$ARTICLE_FILE" || ! -f "$REPO_ROOT/$ARTICLE_FILE" && ! -f "$ARTICLE_FILE" ]]; then
  echo "使い方: bash scripts/insert_images.sh <記事ファイルパス>"
  exit 1
fi

# 絶対パスに正規化
[[ "$ARTICLE_FILE" != /* ]] && ARTICLE_FILE="$REPO_ROOT/$ARTICLE_FILE"

# スラッグを記事ファイル名から抽出
SLUG=$(basename "$ARTICLE_FILE" .md | sed 's/_note$//' | sed 's/^[0-9-]*_//')
IMAGES_DIR="$REPO_ROOT/assets/images/$SLUG"

echo -e "\n${CYAN}══════════════════════════════════════${NC}"
echo -e "${CYAN} 画像挿入アシスタント: $SLUG${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}\n"

# ── 画像ファイル確認 ─────────────────────────────────────────────────────────
if [[ ! -d "$IMAGES_DIR" ]] || [[ -z "$(ls -A "$IMAGES_DIR"/*.jpg 2>/dev/null)" ]]; then
  echo -e "${YELLOW}[WARN]${NC} 画像が見つかりません: $IMAGES_DIR"
  echo ""
  echo "先に画像を取得してください:"
  echo "  bash scripts/fetch_images.sh $ARTICLE_FILE"
  exit 0
fi

# ── 画像一覧 ─────────────────────────────────────────────────────────────────
echo -e "${BLUE}取得済み画像:${NC}"
IMAGES=()
while IFS= read -r f; do
  IMAGES+=("$f")
  BASENAME=$(basename "$f")
  SIZE=$(du -sh "$f" | cut -f1)
  echo "  [$((${#IMAGES[@]}))]: $BASENAME ($SIZE)"
done < <(ls "$IMAGES_DIR"/*.jpg 2>/dev/null | sort)

echo ""

# ── クレジット表示 ────────────────────────────────────────────────────────────
CREDITS_FILE="$IMAGES_DIR/credits.json"
if [[ -f "$CREDITS_FILE" ]]; then
  echo -e "${BLUE}撮影者クレジット:${NC}"
  jq -r '.[] | "  [\(.file)]\n  撮影: \(.photographer) — \(.pexels_url)"' "$CREDITS_FILE"
  echo ""
fi

# ── Note用挿入ブロック生成 ────────────────────────────────────────────────────
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN} Note投稿用 — 画像挿入箇所の提案${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""

# 記事内のH2見出しを抽出し、各見出し後の挿入ポイントを提案
echo -e "${CYAN}記事内のH2見出し（画像挿入ポイント候補）:${NC}"
grep -n "^## " "$ARTICLE_FILE" | head -10 | while IFS=: read -r linenum heading; do
  echo "  行 $linenum: $heading"
done

echo ""
echo -e "${CYAN}推奨配置:${NC}"
echo "  [1枚目]: アイキャッチ（Noteの「カバー画像」に設定）"

H2_COUNT=$(grep -c "^## " "$ARTICLE_FILE" 2>/dev/null || echo 0)
IMG_IDX=2
grep -n "^## " "$ARTICLE_FILE" | head -3 | tail -2 | while IFS=: read -r linenum heading; do
  IMGNAME=$(basename "${IMAGES[$((IMG_IDX-1))]-}" 2>/dev/null || echo "画像${IMG_IDX}.jpg")
  echo "  [${IMG_IDX}枚目]: 行$linenum の $heading 直下 → $IMGNAME"
  IMG_IDX=$((IMG_IDX+1))
done

echo ""
echo -e "${CYAN}Note Markdownでの記述方法:${NC}"
echo "  Noteはローカルファイルの直接埋め込みには非対応です。"
echo "  以下のいずれかの方法で画像をアップロードしてください:"
echo ""
echo "  方法A（推奨）: Noteエディタの「画像追加」ボタンでアップロード"
echo "  方法B: Google Drive / Dropbox に上げてURLを取得し、以下の形式で記事に挿入:"
echo '    !["説明テキスト"](https://your-image-url.jpg)'
echo ""

# ── ファイルパス一覧コピー用 ──────────────────────────────────────────────────
echo -e "${CYAN}画像ファイルの絶対パス（Finderで開く用）:${NC}"
for f in "${IMAGES[@]}"; do
  echo "  $f"
done

echo ""
echo -e "${YELLOW}Finderで開く（Mac）:${NC}"
echo "  open $IMAGES_DIR"
echo ""
echo -e "${YELLOW}エクスプローラーで開く（Windows/WSL）:${NC}"
echo "  explorer.exe \$(wslpath -w '$IMAGES_DIR')"
