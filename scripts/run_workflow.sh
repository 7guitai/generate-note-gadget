#!/usr/bin/env bash
# ==============================================================================
# Noteガジェットブログ 記事生成ワークフロー
# Usage:
#   bash scripts/run_workflow.sh              # フルワークフロー
#   bash scripts/run_workflow.sh research     # リサーチのみ
#   bash scripts/run_workflow.sh topic        # テーマ選定のみ
#   bash scripts/run_workflow.sh article      # 推奨テーマで記事生成
#   bash scripts/run_workflow.sh article "テーマ名"  # 指定テーマで記事生成
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE=$(date +%Y-%m-%d)
PHASE="${1:-all}"
TOPIC="${2:-}"

# ── カラー出力 ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_phase()   { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; echo -e "${CYAN} $*${NC}"; echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ── ディレクトリ確認 ────────────────────────────────────────────────────────
ensure_dirs() {
  mkdir -p "$REPO_ROOT/research" "$REPO_ROOT/articles"
}

# ── 最新ファイルを取得 ───────────────────────────────────────────────────────
latest_file() {
  local dir="$1"
  local pattern="$2"
  ls -t "$REPO_ROOT/$dir/"$pattern 2>/dev/null | head -1
}

# ── Phase 1: リサーチ ────────────────────────────────────────────────────────
run_research() {
  log_phase "Phase 1: リサーチ開始"
  log_info "プロンプト読み込み: prompts/01_research.md"

  local prompt_file="$REPO_ROOT/prompts/01_research.md"
  local output_file="$REPO_ROOT/research/${DATE}_research.md"

  if [[ ! -f "$prompt_file" ]]; then
    echo -e "${RED}[ERROR]${NC} プロンプトファイルが見つかりません: $prompt_file"
    exit 1
  fi

  echo ""
  echo -e "${YELLOW}━━━ Claude Codeへの指示 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "以下のプロンプトに従い、リサーチを実行して結果を保存してください:"
  echo ""
  cat "$prompt_file"
  echo ""
  echo -e "${YELLOW}出力先: ${output_file}${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── Phase 2: テーマ選定 ──────────────────────────────────────────────────────
run_topic_select() {
  log_phase "Phase 2: テーマ選定開始"

  local research_file
  research_file=$(latest_file "research" "*_research.md")

  if [[ -z "$research_file" ]]; then
    log_warn "リサーチファイルが見つかりません。先にPhase 1を実行してください。"
    log_info "実行: bash scripts/run_workflow.sh research"
    exit 1
  fi

  local prompt_file="$REPO_ROOT/prompts/02_topic_select.md"
  local output_file="$REPO_ROOT/research/${DATE}_topics.md"

  log_info "リサーチファイル: $research_file"

  echo ""
  echo -e "${YELLOW}━━━ Claude Codeへの指示 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "以下のプロンプトに従い、テーマ選定を実行してください:"
  echo "入力ファイル: $research_file"
  echo ""
  cat "$prompt_file"
  echo ""
  echo -e "${YELLOW}出力先: ${output_file}${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── Phase 3: 記事生成 ────────────────────────────────────────────────────────
run_article_gen() {
  log_phase "Phase 3: 記事生成開始"

  local topic_file
  topic_file=$(latest_file "research" "*_topics.md")

  if [[ -z "$TOPIC" ]]; then
    if [[ -z "$topic_file" ]]; then
      log_warn "テーマファイルも引数テーマも見つかりません。"
      log_info "実行例: bash scripts/run_workflow.sh article \"ワイヤレスイヤホンおすすめ5選\""
      exit 1
    fi
    log_info "テーマファイルから推奨テーマを使用: $topic_file"
  else
    log_info "指定テーマ: $TOPIC"
  fi

  local prompt_file="$REPO_ROOT/prompts/03_article_gen.md"

  # スラッグ生成（日本語テーマをファイル名に使いやすい形に）
  local slug
  if [[ -n "$TOPIC" ]]; then
    slug=$(echo "$TOPIC" | tr ' ' '-' | tr '　' '-' | head -c 30)
  else
    slug="auto-selected"
  fi

  local output_file="$REPO_ROOT/articles/${DATE}_${slug}.md"

  echo ""
  echo -e "${YELLOW}━━━ Claude Codeへの指示 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "以下のプロンプトに従い、記事を生成して保存してください:"

  if [[ -n "$TOPIC" ]]; then
    echo "テーマ: $TOPIC"
  else
    echo "テーマ: $topic_file に記載の推奨テーマを使用"
  fi

  echo ""
  cat "$prompt_file"
  echo ""
  echo -e "${YELLOW}出力先: ${output_file}${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── 使い方ヘルプ ─────────────────────────────────────────────────────────────
show_help() {
  echo ""
  echo "Noteガジェットブログ 記事生成ワークフロー"
  echo ""
  echo "使い方:"
  echo "  bash scripts/run_workflow.sh              フルワークフロー（全フェーズ）"
  echo "  bash scripts/run_workflow.sh research     Phase 1: リサーチのみ"
  echo "  bash scripts/run_workflow.sh topic        Phase 2: テーマ選定のみ"
  echo "  bash scripts/run_workflow.sh article      Phase 3: 推奨テーマで記事生成"
  echo "  bash scripts/run_workflow.sh article \"テーマ\"  指定テーマで記事生成"
  echo "  bash scripts/run_workflow.sh help         このヘルプを表示"
  echo ""
  echo "フォルダ構成:"
  echo "  research/   - リサーチ結果・テーマ選定結果"
  echo "  articles/   - 生成された記事"
  echo ""
  echo "目標: 月3,000円のアフィリエイト収益"
}

# ── メイン ──────────────────────────────────────────────────────────────────
main() {
  ensure_dirs

  case "$PHASE" in
    all)
      run_research
      echo ""
      echo -e "${GREEN}※ Phase 1完了後、Phase 2を実行してください:${NC}"
      echo "  bash scripts/run_workflow.sh topic"
      ;;
    research)
      run_research
      ;;
    topic)
      run_topic_select
      ;;
    article)
      run_article_gen
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}[ERROR]${NC} 不明なフェーズ: $PHASE"
      show_help
      exit 1
      ;;
  esac
}

main
